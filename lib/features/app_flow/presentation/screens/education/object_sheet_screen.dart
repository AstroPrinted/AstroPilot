import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/ap_widgets.dart';
import '../../../../calibration/presentation/controllers/calibration_controller.dart';
import '../../../../catalog/domain/models/celestial_object.dart';
import '../../../../observation/application/ephemeris_service.dart';
import '../../../../observation/domain/models/alt_az_result.dart';
import '../../../../settings/application/settings_service.dart';
import '../../../application/app_flow_state.dart';
import '../../widgets/mode_scaffold.dart';
import '../../widgets/catalog_object_row.dart';
import '../../widgets/object_display.dart';
import '../../widgets/object_image.dart';
import '../home_screen.dart';

/// Ficha educativa de un objeto. No mueve el telescopio: "Observar este
/// objeto" lleva al modo Observación.
class ObjectSheetScreen extends StatefulWidget {
  final CelestialObject object;

  /// Abierta desde "Aprender sobre…" en Observar.
  final bool fromObservation;
  final bool trackingActive;

  const ObjectSheetScreen({
    super.key,
    required this.object,
    this.fromObservation = false,
    this.trackingActive = false,
  });

  @override
  State<ObjectSheetScreen> createState() => _ObjectSheetScreenState();
}

class _ObjectSheetScreenState extends State<ObjectSheetScreen> {
  late final EphemerisService _ephemeris;
  bool get _isSun => ObjectDisplay.isSun(widget.object);

  @override
  void initState() {
    super.initState();
    _ephemeris = EphemerisService(
      observerDataProvider: context.read<SettingsService>(),
    );
    if (!_isSun) _ephemeris.startTracking(widget.object);
  }

  @override
  void dispose() {
    _ephemeris.dispose();
    super.dispose();
  }

  void _observe(BuildContext context, bool aligned) {
    final flow = context.read<AppFlowState>();
    flow.setPendingObject(widget.object);
    if (aligned) {
      HomeScreen.openObservation(context, tab: ObservationTab.catalog);
      return;
    }
    final connected = flow.isConnected;
    flow.startTutorialAt(
      !connected
          ? ObservationStep.connection
          : flow.isZeroFixed
          ? ObservationStep.alignment
          : ObservationStep.leveling,
    );
    HomeScreen.openObservation(
      context,
      tab: connected ? ObservationTab.alignment : ObservationTab.connection,
    );
  }

  @override
  Widget build(BuildContext context) {
    final object = widget.object;
    final short = ObjectDisplay.shortName(object);
    final notes = object.notes?.trim();
    final constellation = ObjectDisplay.constellation(object);
    final j2000 = ObjectDisplay.j2000Parts(object);

    return Scaffold(
      appBar: ModeAppBar(title: short, back: true, showConnection: false),
      body: StreamBuilder<AltAzResult>(
        stream: _ephemeris.stream,
        builder: (context, snapshot) {
          final position = snapshot.data;
          return ModeBody(
            children: [
              if (widget.fromObservation && widget.trackingActive)
                const ApPillLeft(
                  ApPill('Tracking activo en segundo plano', tone: ApTone.ok),
                ),
              if (_isSun)
                const ApCard(
                  error: true,
                  children: [
                    ApCardHead(
                      icon: Icons.warning,
                      iconColor: ApColors.error,
                      title: 'Seguridad solar',
                    ),
                    Text(
                      'Nunca mires el Sol con un telescopio sin un filtro '
                      'solar certificado. Puede causar daño permanente en los '
                      'ojos.',
                      style: TextStyle(fontSize: 14, color: ApColors.text),
                    ),
                  ],
                ),
              ApCard(
                children: [
                  ApCardHead(icon: ObjectDisplay.icon(object), title: 'Objeto'),
                  ObjectPhoto(object),
                  Text(
                    object.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: ApColors.text,
                    ),
                  ),
                  _KeyValues(
                    rows: [
                      ('Tipo', ObjectDisplay.typeLabel(object)),
                      ('Magnitud', ObjectDisplay.magnitude(object) ?? 'N/A'),
                      if (constellation != null) ('Constelación', constellation),
                    ],
                  ),
                  if (notes != null && notes.isNotEmpty)
                    Text(notes, style: ApText.body),
                ],
              ),
              ApCard(
                children: [
                  const ApCardHead(
                    icon: Icons.public,
                    title: 'Coordenadas J2000',
                  ),
                  if (j2000 != null)
                    ApTiles(
                      tiles: [
                        ApTile(
                          label: 'Ascensión recta (AR)',
                          value: j2000.ra,
                          fontSize: 16,
                        ),
                        ApTile(
                          label: 'Declinación (Dec)',
                          value: j2000.dec,
                          fontSize: 16,
                        ),
                      ],
                    )
                  else
                    const Text(
                      'Los cuerpos del Sistema Solar se calculan '
                      'dinámicamente.',
                      style: ApText.body,
                    ),
                ],
              ),
              ApCard(
                children: [
                  const ApCardHead(
                    icon: Icons.explore,
                    title: 'Alt/Az en vivo',
                    trailing: ApPill('EN VIVO', small: true, dot: false),
                  ),
                  if (_isSun)
                    const Text(
                      'Coordenadas solares bloqueadas por seguridad ocular.',
                      style: ApText.body,
                    )
                  else if (snapshot.hasError)
                    Text(
                      'No se pudo calcular Alt/Az: ${snapshot.error}',
                      style: ApText.body,
                    )
                  else ...[
                    ApTiles(
                      tiles: [
                        ApTile(
                          label: 'Altitud',
                          value: formatDeg(position?.altitudeDeg),
                        ),
                        ApTile(
                          label: 'Azimut',
                          value: formatDeg(position?.azimuthDeg),
                        ),
                      ],
                    ),
                    if (position != null) ApPillLeft(_visibilityPill(position)),
                    if (position != null &&
                        position.altitudeDeg >= 0 &&
                        position.altitudeDeg < 5)
                      const Text(nearHorizonExplanation, style: ApText.small),
                  ],
                ],
              ),
              if (widget.fromObservation)
                ApButton(
                  label: 'Volver a observar',
                  icon: Icons.arrow_back,
                  large: true,
                  onPressed: () => Navigator.of(context).maybePop(),
                )
              else
                _ObserveAction(
                  isSun: _isSun,
                  position: position,
                  onObserve: (aligned) => _observe(context, aligned),
                ),
            ],
          );
        },
      ),
    );
  }

  static ApPill _visibilityPill(AltAzResult position) {
    final alt = position.altitudeDeg;
    if (alt < 0) return const ApPill('Bajo el horizonte', tone: ApTone.muted);
    if (alt < 5) {
      return const ApPill('Visible, cerca del horizonte', tone: ApTone.warn);
    }
    return const ApPill('Visible sobre el horizonte', tone: ApTone.info);
  }
}

class _ObserveAction extends StatelessWidget {
  final bool isSun;
  final AltAzResult? position;
  final ValueChanged<bool> onObserve;

  const _ObserveAction({
    required this.isSun,
    required this.position,
    required this.onObserve,
  });

  @override
  Widget build(BuildContext context) {
    final calibration = context.watch<CalibrationController>();
    final flow = context.watch<AppFlowState>();
    final aligned = calibration.isInitialAligned && !flow.referenceLost;
    final below = position != null && position!.altitudeDeg < 0;
    final canObserve = !isSun && !below && position != null;

    final (String reason, IconData icon, Color color) = isSun
        ? ('Bloqueado siempre por seguridad ocular.', Icons.block, ApColors.error)
        : below
        ? ('Bajo el horizonte ahora.', Icons.schedule, ApColors.muted)
        : aligned
        ? (
            'Alineado con '
                '${calibration.initialAlignmentReferenceName ?? 'una estrella'} '
                '✓ · el telescopio irá directo.',
            Icons.check_circle,
            ApColors.ok,
          )
        : (
            'Primero te guiaremos para alinear el telescopio.',
            Icons.route,
            ApColors.primary,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ApButton(
          label: 'Observar este objeto',
          icon: Icons.visibility,
          large: true,
          onPressed: canObserve ? () => onObserve(aligned) : null,
        ),
        const SizedBox(height: 8),
        ApInfoLine(
          text: reason,
          icon: icon,
          iconColor: color,
          center: true,
        ),
      ],
    );
  }
}

class _KeyValues extends StatelessWidget {
  final List<(String, String)> rows;
  const _KeyValues({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: apSpaced([
        for (final (key, value) in rows)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  key,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: ApColors.muted,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 13.5, color: ApColors.text),
                ),
              ),
            ],
          ),
      ], gap: 8),
    );
  }
}
