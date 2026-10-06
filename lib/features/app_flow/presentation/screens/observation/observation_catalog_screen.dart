import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/ap_widgets.dart';
import '../../../../calibration/domain/services/astronomy_position_service.dart';
import '../../../../calibration/presentation/controllers/calibration_controller.dart';
import '../../../../catalog/application/visible_objects_service.dart';
import '../../../../catalog/data/repository/celestial_catalog_repository.dart';
import '../../../../catalog/domain/models/visible_celestial_object.dart';
import '../../../../observation/domain/services/sun_guard.dart';
import '../../../../settings/application/settings_service.dart';
import '../../../application/app_flow_state.dart';
import '../../widgets/catalog_object_row.dart';
import '../../widgets/mode_scaffold.dart';
import '../../widgets/object_display.dart';
import 'observation_shell.dart';
import 'observe_object_screen.dart';

/// Paso 5 / pestaña Catálogo: objetos visibles ahora para apuntar.
class ObservationCatalogScreen extends StatefulWidget {
  const ObservationCatalogScreen({super.key});

  @override
  State<ObservationCatalogScreen> createState() =>
      _ObservationCatalogScreenState();
}

class _ObservationCatalogScreenState extends State<ObservationCatalogScreen> {
  static const _refreshInterval = Duration(minutes: 1);

  CatalogCategory _category = CatalogCategory.all;
  List<VisibleCelestialObject> _objects = const [];
  DateTime? _computedAt;
  bool _loading = true;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    _timer = Timer.periodic(_refreshInterval, (_) => unawaited(_refresh()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final category = _category;
    try {
      final objects = await VisibleObjectsService(
        catalogRepository: CelestialCatalogRepository(),
        observerDataProvider: context.read<SettingsService>(),
        astronomyPositionService: const AstronomyPositionService(),
        sunGuard: SunGuard(
          observerDataProvider: context.read<SettingsService>(),
        ),
      ).loadObjects(category: category.key, visibleOnly: true);
      if (!mounted || category != _category) return;
      setState(() {
        _objects = objects;
        _computedAt = DateTime.now().toUtc();
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo calcular la visibilidad: $error';
        _loading = false;
      });
    }
  }

  void _setCategory(CatalogCategory category) {
    setState(() {
      _category = category;
      _loading = true;
    });
    unawaited(_refresh());
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>().state;
    final flow = context.watch<AppFlowState>();
    final calibration = context.watch<CalibrationController>();
    final aligned = calibration.isInitialAligned && !flow.referenceLost;
    final correction = calibration.correctionCalibrationResult;
    final fineCount = (correction?.hasCorrectionCalibration ?? false)
        ? correction!.points.length
        : 0;

    void openTutorial(ObservationStep step) {
      flow.startTutorialAt(step);
      flow.requestTab(
        flow.isConnected ? ObservationTab.alignment : ObservationTab.connection,
      );
    }

    return Scaffold(
      appBar: const ModeAppBar(title: 'Catálogo'),
      body: ModeBody(
        header: [
          const ReferenceLostBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ApCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              gap: 8,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    if (aligned)
                      ApPill(
                        'Alineado con '
                        '${calibration.initialAlignmentReferenceName ?? 'una estrella'} ✓',
                        tone: ApTone.ok,
                      )
                    else
                      ApPill(
                        flow.referenceLost
                            ? 'Alineación perdida'
                            : 'Sin alinear',
                        tone: ApTone.error,
                      ),
                    if (fineCount > 0)
                      ApPill(
                        'Ajuste: $fineCount '
                        '${fineCount == 1 ? 'estrella' : 'estrellas'}',
                        tone: ApTone.info,
                      )
                    else
                      const ApPill('Sin ajuste fino', tone: ApTone.warn),
                  ],
                ),
                if (!aligned && !flow.referenceLost)
                  _InlineAction(
                    tone: ApTone.error,
                    text: 'Alinea el telescopio para poder hacer GOTO.',
                    action: 'Alinear',
                    onAction: () => openTutorial(
                      flow.isConnected
                          ? (flow.isZeroFixed
                                ? ObservationStep.alignment
                                : ObservationStep.leveling)
                          : ObservationStep.connection,
                    ),
                  )
                else if (aligned && fineCount == 0)
                  _InlineAction(
                    tone: ApTone.warn,
                    text:
                        'Sin ajuste fino: los objetos podrían no quedar '
                        'centrados.',
                    action: 'Hacer ajuste',
                    onAction: () => openTutorial(ObservationStep.fineAdjust),
                  ),
              ],
            ),
          ),
        ],
        children: [
          CategoryChips(selected: _category, onSelected: _setCategory),
          ApCard(
            gap: 8,
            children: [
              const ApCardHead(
                icon: Icons.visibility,
                title: 'Objetos visibles',
              ),
              const VisibilityLegend(),
              ApMonoBlock(
                text: visibilityContext(
                  settings.latDeg,
                  settings.lonDeg,
                  _computedAt ?? settings.effectiveUtc,
                ),
              ),
            ],
          ),
          if (_error != null)
            ApNotice(
              icon: Icons.error_outline,
              tone: ApTone.error,
              text: _error!,
            )
          else if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_objects.isEmpty)
            const ApCard(
              children: [
                Text(
                  'No hay objetos de esta categoría sobre el horizonte ahora.',
                  textAlign: TextAlign.center,
                  style: ApText.body,
                ),
              ],
            )
          else
            ApCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              gap: 0,
              children: [
                for (var i = 0; i < _objects.length; i++) ...[
                  if (i > 0) const ApDivider(),
                  CatalogObjectRow(
                    item: _objects[i],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ObserveObjectScreen(object: _objects[i].object),
                      ),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _InlineAction extends StatelessWidget {
  final ApTone tone;
  final String text;
  final String action;
  final VoidCallback onAction;

  const _InlineAction({
    required this.tone,
    required this.text,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tone.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, size: 18, color: tone.color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: ApColors.text),
            ),
          ),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: tone.color,
              minimumSize: const Size(0, 36),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(action),
          ),
        ],
      ),
    );
  }
}
