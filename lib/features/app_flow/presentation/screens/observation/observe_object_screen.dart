import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/ap_widgets.dart';
import '../../../../calibration/data/calibration_repository.dart';
import '../../../../calibration/data/calibration_storage.dart';
import '../../../../calibration/domain/services/astronomy_position_service.dart';
import '../../../../calibration/domain/services/pointing_correction_service.dart';
import '../../../../calibration/presentation/controllers/calibration_controller.dart';
import '../../../../catalog/application/astronomical_goto_service.dart';
import '../../../../catalog/domain/models/celestial_object.dart';
import '../../../../catalog/presentation/controllers/celestial_control_controller.dart';
import '../../../../observation/domain/services/sun_guard.dart';
import '../../../../oe4_control/domain/telescope_position.dart';
import '../../../../oe4_control/presentation/controllers/oe4_control_controller.dart';
import '../../../../settings/application/settings_service.dart';
import '../../../application/app_flow_state.dart';
import '../../widgets/mode_scaffold.dart';
import '../../widgets/object_display.dart';
import '../../widgets/object_image.dart';
import '../../widgets/telescope_commands.dart';
import '../education/object_sheet_screen.dart';
import 'observation_shell.dart';

/// Observar un objeto: GOTO, tracking, STOP y centrado manual.
class ObserveObjectScreen extends StatefulWidget {
  final CelestialObject object;

  const ObserveObjectScreen({super.key, required this.object});

  @override
  State<ObserveObjectScreen> createState() => _ObserveObjectScreenState();
}

class _ObserveObjectScreenState extends State<ObserveObjectScreen> {
  late final CelestialControlController _controller;
  late final AppFlowState _flow;
  Timer? _clock;
  bool _saveCorrection = true;
  bool _stopped = false;
  bool _savingCorrection = false;
  String? _centeredMessage;
  String? _centerError;

  @override
  void initState() {
    super.initState();
    _controller = CelestialControlController(
      object: widget.object,
      gotoService: AstronomicalGotoService(
        observerDataProvider: context.read<SettingsService>(),
        calibrationRepository: CalibrationRepository(
          storage: CalibrationStorage(),
        ),
        astronomyPositionService: const AstronomyPositionService(),
        correctionService: const PointingCorrectionService(),
        sunGuard: SunGuard(
          observerDataProvider: context.read<SettingsService>(),
        ),
      ),
      positionProvider: () => context.read<Oe4ControlController>().motionBase,
    );
    _controller.startLivePreview();
    _flow = context.read<AppFlowState>()..addListener(_onFlowChanged);
    // Countdown of the next tracking GOTO.
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _controller.isTracking) setState(() {});
    });
  }

  @override
  void dispose() {
    _flow.removeListener(_onFlowChanged);
    _clock?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onFlowChanged() {
    if (!_flow.isConnected && _controller.isTracking) {
      _controller.stopTracking('Tracking detenido: BLE desconectado.');
    }
  }

  TelescopeCommands get _commands => TelescopeCommands.of(context);

  Future<void> _goto() async {
    setState(() {
      _stopped = false;
      _centeredMessage = null;
    });
    await _controller.sendInitialGoto(_commands.goto);
  }

  Future<void> _toggleTracking() async {
    if (_controller.isTracking) {
      _controller.stopTracking();
      return;
    }
    setState(() => _stopped = false);
    await _controller.startTracking(_commands.goto);
  }

  Future<void> _stop() async {
    setState(() {
      _stopped = true;
      _centeredMessage = null;
    });
    await _controller.sendStop(_commands.stop);
  }

  Future<void> _confirmCentered() async {
    final calibration = context.read<CalibrationController>();
    final sky = _controller.currentPosition;
    final motor = context.read<Oe4ControlController>().telescopePosition;
    if (!_saveCorrection) {
      setState(() {
        _centerError = null;
        _centeredMessage = 'Objeto centrado. La corrección no se guardó.';
      });
      return;
    }
    if (sky == null || motor == null) {
      setState(
        () => _centerError =
            'No se conoce la posición del objeto o del telescopio. Lee la '
            'posición e inténtalo de nuevo.',
      );
      return;
    }
    setState(() {
      _savingCorrection = true;
      _centerError = null;
    });
    try {
      await calibration.saveObjectCorrection(
        objectId: widget.object.id,
        objectName: widget.object.name,
        calculatedAltitude: sky.altitudeDeg,
        calculatedAzimuth: sky.azimuthDeg,
        motorAltitude: motor.altitude,
        motorAzimuth: motor.azimuth,
      );
      final result = calibration.correctionCalibrationResult;
      if (!mounted) return;
      setState(() {
        _centeredMessage = result == null
            ? 'Corrección guardada. Los próximos GOTO la usarán.'
            : 'Corrección guardada '
                  '(${formatSignedDeg(result.altitudeOffset)} alt, '
                  '${formatSignedDeg(result.azimuthOffset)} az). Los '
                  'próximos GOTO la usarán.';
      });
    } catch (error) {
      if (mounted) setState(() => _centerError = errorText(error));
    } finally {
      if (mounted) setState(() => _savingCorrection = false);
    }
  }

  ({String label, ApTone tone}) _movePill(Oe4ControlController oe4) {
    if (oe4.isMoving) return (label: 'Moviendo…', tone: ApTone.primary);
    if (_stopped) return (label: 'Detenido', tone: ApTone.error);
    if (_controller.lastSentCommand == null) {
      return (label: 'En espera', tone: ApTone.muted);
    }
    return switch (oe4.lastMoveOutcome?.kind) {
      MoveOutcomeKind.arrived => (label: 'Llegó al objetivo', tone: ApTone.ok),
      MoveOutcomeKind.stalled => (
        label: 'Se detuvo antes de llegar',
        tone: ApTone.warn,
      ),
      MoveOutcomeKind.completed => (
        label: 'Completado (firmware)',
        tone: ApTone.info,
      ),
      null => (label: 'En espera', tone: ApTone.muted),
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final object = widget.object;
    final oe4 = context.watch<Oe4ControlController>();
    final flow = context.watch<AppFlowState>();
    final calibration = context.watch<CalibrationController>();
    final short = ObjectDisplay.shortName(object);
    final sun = ObjectDisplay.isSun(object);
    final sky = _controller.currentPosition;
    final below = !sun && sky != null && sky.altitudeDeg < 0;
    final aligned = calibration.isInitialAligned && !flow.referenceLost;
    final blocked =
        sun || below || !aligned || !flow.isConnected || sky == null;
    final busy = _controller.isSending || oe4.isSending;
    final pill = _movePill(oe4);
    final j2000 = ObjectDisplay.j2000(object);
    final nextAt = _controller.nextTrackingAt;
    final nextIn = nextAt
        ?.difference(DateTime.now().toUtc())
        .inSeconds
        .clamp(0, 15);
    final error = _controller.errorMessage;
    final canFine = !blocked && _controller.canFineTune;
    final fineStep = CelestialControlController.fineStepDegrees.toStringAsFixed(
      2,
    );
    Future<void> Function()? fine(CelestialFineDirection direction) =>
        canFine ? () => _controller.fineTune(direction, _commands.goto) : null;

    return Scaffold(
      appBar: ModeAppBar(title: short, back: true),
      body: ModeBody(
        header: const [ReferenceLostBanner()],
        children: [
          if (sun)
            const ApCard(
              error: true,
              children: [
                ApCardHead(
                  icon: Icons.warning,
                  iconColor: ApColors.error,
                  title: 'Seguridad solar',
                ),
                Text(
                  'Nunca apuntes el telescopio al Sol sin un filtro solar '
                  'certificado. Puede causar daño permanente en los ojos y en '
                  'el equipo.',
                  style: TextStyle(fontSize: 14, color: ApColors.text),
                ),
                ApNotice(
                  icon: Icons.block,
                  tone: ApTone.error,
                  text: 'GOTO bloqueado siempre para el Sol.',
                ),
              ],
            ),
          ApCard(
            children: [
              Row(
                children: [
                  ObjectThumbnail(object),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(object.name, style: ApText.title),
                        const SizedBox(height: 2),
                        Text(
                          ObjectDisplay.subtitle(object),
                          style: ApText.small,
                        ),
                        if (j2000 != null)
                          Text(j2000, style: ApText.small.merge(ApText.number)),
                      ],
                    ),
                  ),
                ],
              ),
              const ApDivider(),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Posición Alt/Az en vivo',
                      style: ApText.strong,
                    ),
                  ),
                  ApPill(pill.label, tone: pill.tone),
                ],
              ),
              ApTiles(
                tiles: [
                  ApTile(
                    label: 'Objeto · altitud',
                    value: formatDeg(sky?.altitudeDeg),
                  ),
                  ApTile(
                    label: 'Objeto · azimut',
                    value: formatDeg(sky?.azimuthDeg),
                  ),
                  ApTile(
                    label: 'Telescopio · altitud',
                    value: formatDeg(oe4.telescopePosition?.altitude),
                  ),
                  ApTile(
                    label: 'Telescopio · azimut',
                    value: formatDeg(oe4.telescopePosition?.azimuth),
                  ),
                ],
              ),
              if (_controller.isTracking)
                ApNotice(
                  icon: Icons.autorenew,
                  tone: ApTone.ok,
                  text:
                      'Tracking activo. Actualiza cada 15 segundos'
                      '${nextIn == null ? '' : ' · próxima en $nextIn s'}.',
                ),
            ],
          ),
          ApCard(
            children: [
              const ApCardHead(icon: Icons.gamepad, title: 'Acciones'),
              if (below)
                ApNotice(
                  icon: Icons.visibility_off,
                  tone: ApTone.muted,
                  text:
                      'GOTO deshabilitado: $short está bajo el horizonte '
                      '(${formatDeg(sky.altitudeDeg)}).',
                )
              else if (!sun && !aligned)
                const ApNotice(
                  icon: Icons.center_focus_strong,
                  tone: ApTone.warn,
                  text: 'Alinea el telescopio para poder hacer GOTO.',
                )
              else if (!sun && !flow.isConnected)
                const ApNotice(
                  icon: Icons.bluetooth_disabled,
                  tone: ApTone.warn,
                  text: 'Conecta el telescopio para hacer GOTO.',
                ),
              if (error != null && !sun)
                ApNotice(
                  icon: Icons.error_outline,
                  tone: ApTone.error,
                  text: error,
                ),
              ApButton(
                label: 'Enviar GOTO',
                icon: Icons.near_me,
                large: true,
                busy: _controller.isSending && !_controller.isTracking,
                onPressed: blocked || busy ? null : _goto,
              ),
              Row(
                children: [
                  Expanded(
                    child: ApButton(
                      label: _controller.isTracking
                          ? 'Pausar tracking'
                          : 'Iniciar tracking',
                      icon: _controller.isTracking
                          ? Icons.pause
                          : Icons.play_arrow,
                      kind: ApButtonKind.outlined,
                      onPressed: blocked && !_controller.isTracking
                          ? null
                          : _toggleTracking,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ApButton(
                      label: 'STOP',
                      icon: Icons.stop,
                      kind: ApButtonKind.danger,
                      onPressed: flow.isConnected ? _stop : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (!sun)
            ApCard(
              children: [
                const ApCardHead(
                  icon: Icons.filter_center_focus,
                  title: 'Ajuste fino',
                ),
                const Text(
                  'Si el objeto no quedó centrado, muévelo con las flechas '
                  'hasta el centro del ocular.',
                  style: ApText.body,
                ),
                ApJoystick(
                  onUp: fine(CelestialFineDirection.up),
                  onDown: fine(CelestialFineDirection.down),
                  onLeft: fine(CelestialFineDirection.left),
                  onRight: fine(CelestialFineDirection.right),
                  caption: canFine
                      ? 'Cada toque mueve $fineStep°. Mantén presionado '
                            'para repetir.'
                      : 'Envía un GOTO para habilitar las flechas.',
                ),
                // Messages go below the arrows: they appear and disappear
                // with every move and must not shift the button under the
                // finger.
                if (_controller.fineTuneError != null)
                  ApNotice(
                    icon: Icons.error_outline,
                    tone: ApTone.error,
                    text: _controller.fineTuneError!,
                  ),
                if (oe4.movementWarning != null && !_stopped)
                  ApNotice(
                    icon: Icons.warning,
                    tone: ApTone.warn,
                    text:
                        '${oe4.movementWarning!} Puedes terminar de apuntar '
                        'con las flechas.',
                  ),
                if (_centerError != null)
                  ApNotice(
                    icon: Icons.error_outline,
                    tone: ApTone.error,
                    text: _centerError!,
                  ),
                if (_centeredMessage != null)
                  ApNotice(
                    icon: Icons.check_circle,
                    tone: ApTone.ok,
                    text: _centeredMessage!,
                  ),
                CheckboxListTile(
                  value: _saveCorrection,
                  onChanged: (v) =>
                      setState(() => _saveCorrection = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Guardar esta corrección para mejorar los próximos GOTO',
                    style: TextStyle(fontSize: 14, color: ApColors.text),
                  ),
                ),
                ApButton(
                  label: 'Confirmar objeto centrado',
                  icon: Icons.check_circle,
                  kind: ApButtonKind.outlined,
                  busy: _savingCorrection,
                  onPressed: canFine && !oe4.isMoving ? _confirmCentered : null,
                ),
              ],
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ApButton(
                label: 'Aprender sobre $short',
                icon: Icons.school,
                kind: ApButtonKind.outlined,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ObjectSheetScreen(
                      object: object,
                      fromObservation: true,
                      trackingActive: _controller.isTracking,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ApButton(
                label: 'Elegir otro objeto',
                icon: Icons.auto_awesome,
                kind: ApButtonKind.text,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
