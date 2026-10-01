import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/widgets/ap_widgets.dart';
import '../../../../../calibration/domain/models/calibration_flow_step.dart';
import '../../../../../calibration/presentation/controllers/calibration_controller.dart';
import '../../../../../oe4_control/presentation/controllers/oe4_control_controller.dart';
import '../../../../application/app_flow_state.dart';
import '../../../widgets/mode_scaffold.dart';
import '../../../widgets/object_display.dart';
import '../../../widgets/telescope_commands.dart';
import '../observation_progress.dart';
import 'star_picker.dart';
import 'step_widgets.dart';

/// Paso 3: alinear con una estrella. El telescopio hace un GOTO aproximado
/// desde el 0 / 0 y el usuario termina de centrarla.
class StarAlignmentStep extends StatefulWidget {
  final ObservationProgress progress;
  final VoidCallback onNext;
  final VoidCallback onGoToLeveling;

  const StarAlignmentStep({
    super.key,
    required this.progress,
    required this.onNext,
    required this.onGoToLeveling,
  });

  @override
  State<StarAlignmentStep> createState() => _StarAlignmentStepState();
}

class _StarAlignmentStepState extends State<StarAlignmentStep> {
  bool _starting = false;

  bool _isActive(CalibrationController c) =>
      c.session != null && c.isInitialAlignmentFlow;

  /// Abre una sesión de alineación al llegar al paso sin alineación previa.
  void _ensureSession(CalibrationController calibration) {
    if (_starting ||
        _isActive(calibration) ||
        calibration.isInitialAligned ||
        calibration.isLoading ||
        !widget.progress.zeroFixed) {
      return;
    }
    _starting = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _starting = false;
      if (!mounted) return;
      final c = context.read<CalibrationController>();
      if (!_isActive(c) && !c.isInitialAligned) c.startInitialAlignment();
    });
  }

  Future<void> _goToStar(
    CalibrationController calibration,
    CalibrationStarOption option,
  ) async {
    final commands = TelescopeCommands.of(context);
    await calibration.selectStar(option);
    if (calibration.flowStep != CalibrationFlowStep.movingToTarget) return;
    await calibration.sendGotoToReference(commands.goto);
  }

  Future<void> _confirm(CalibrationController calibration) async {
    final commands = TelescopeCommands.of(context);
    final flow = context.read<AppFlowState>();
    final target = calibration.targetPosition;
    final position = context.read<Oe4ControlController>().telescopePosition;
    await calibration.confirmCenteredReference(
      setInitialPosition: commands.setPosition,
      refreshPosition: commands.status,
    );
    if (calibration.isInitialAligned &&
        target != null &&
        position != null) {
      flow.setAlignmentCorrection((
        altitude: target.altitudeDeg - position.altitude,
        azimuth: _azimuthDelta(position.azimuth, target.azimuthDeg),
      ));
    }
  }

  static double _azimuthDelta(double from, double to) {
    final delta = ((to - from + 540) % 360) - 180;
    return delta;
  }

  @override
  Widget build(BuildContext context) {
    final calibration = context.watch<CalibrationController>();
    final oe4 = context.watch<Oe4ControlController>();
    final flow = context.watch<AppFlowState>();
    final destination = flow.pendingObject;
    _ensureSession(calibration);

    final header = <Widget>[
      if (destination != null)
        ApPillLeft(
          ApPill(
            'Después de alinear irás a ${ObjectDisplay.shortName(destination)}',
            tone: ApTone.primary,
          ),
        ),
    ];

    if (!widget.progress.zeroFixed &&
        !_isActive(calibration) &&
        !calibration.isInitialAligned) {
      return ModeBody(
        children: [
          ...header,
          ApCard(
            children: [
              const ApStepBadge('Paso 3 de 5'),
              const Text(
                'Primero fija el punto 0 / 0',
                style: ApText.title,
              ),
              const Text(
                'El GOTO a la estrella parte de la referencia del paso 2. '
                'Fíjala antes de alinear.',
                style: ApText.body,
              ),
              ApButton(
                label: 'Ir a Nivelación',
                icon: Icons.arrow_back,
                kind: ApButtonKind.outlined,
                onPressed: widget.onGoToLeveling,
              ),
            ],
          ),
        ],
      );
    }

    if (!_isActive(calibration) && calibration.isInitialAligned) {
      return ModeBody(
        children: [
          ...header,
          _AlignedCard(
            calibration: calibration,
            correction: flow.alignmentCorrection,
            destination: destination == null
                ? null
                : ObjectDisplay.shortName(destination),
            onNext: widget.onNext,
            onGoToDestination: () {
              flow.completeTutorial();
              flow.requestTab(ObservationTab.catalog);
            },
          ),
        ],
      );
    }

    if (!_isActive(calibration) || calibration.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final commands = TelescopeCommands.of(context);
    final error = calibration.errorMessage;
    return ModeBody(
      children: [
        ...header,
        switch (calibration.flowStep) {
          CalibrationFlowStep.selectingObject ||
          CalibrationFlowStep.calculatingTarget => ApCard(
            children: [
              const ApStepBadge('Paso 3 de 5'),
              const Text(
                'Elige una estrella para alinear',
                style: ApText.title,
              ),
              const Text(
                'Al elegirla, el telescopio hará un GOTO aproximado para '
                'dejarla cerca del ocular. Tú solo terminas de centrarla.',
                style: ApText.body,
              ),
              if (error != null) ErrorNotice(error),
              StarPicker(
                options: calibration.calibrationStarOptions,
                guideFor: calibration.guideForStar,
                busy:
                    calibration.isBusy ||
                    calibration.flowStep ==
                        CalibrationFlowStep.calculatingTarget,
                actionLabel: 'Ir a la estrella',
                onGo: (option) => _goToStar(calibration, option),
              ),
            ],
          ),
          CalibrationFlowStep.movingToTarget => _MovingCard(
            starName: calibration.selectedStar?.name ?? 'la estrella',
            position: oe4.telescopePosition,
            targetAltitude: calibration.targetPosition?.altitudeDeg,
            targetAzimuth: calibration.targetPosition?.azimuthDeg,
            note:
                'GOTO aproximado usando la referencia 0 / 0. La estrella '
                'debería quedar cerca del ocular.',
            onStop: () => calibration.abortReferenceGoto(commands.stop),
          ),
          CalibrationFlowStep.waitingUserCentering ||
          CalibrationFlowStep.savingPoint => ApCard(
            children: [
              const ApStepBadge('Paso 3 de 5'),
              Text(
                'Centra ${calibration.selectedStar?.name ?? 'la estrella'} '
                'en el ocular',
                style: ApText.title,
              ),
              const Text(
                'El telescopio quedó cerca. Termina de centrarla con las '
                'flechas y confirma.',
                style: ApText.body,
              ),
              if (calibration.selectedStarGuide.isNotEmpty)
                ApNotice(
                  icon: Icons.lightbulb,
                  color: ApColors.tip,
                  text: calibration.selectedStarGuide,
                ),
              PositionTiles(position: oe4.telescopePosition),
              // Messages go below the arrows: they appear and disappear with
              // every move and must not shift the button under the finger.
              CalibrationJoystick(
                calibration: calibration,
                commands: commands,
                enabled:
                    calibration.flowStep != CalibrationFlowStep.savingPoint,
              ),
              if (error != null) ErrorNotice(error),
              if (oe4.movementWarning != null)
                ApNotice(
                  icon: Icons.warning,
                  tone: ApTone.warn,
                  text:
                      '${oe4.movementWarning!} Puedes seguir centrando con '
                      'las flechas.',
                ),
              DirectMoveCard(
                position: oe4.telescopePosition,
                enabled: !calibration.isBusy,
                onMove: (alt, az) => calibration.moveToAdjustedPosition(
                  altitude: alt,
                  azimuth: az,
                  sendAbsoluteMove: commands.moveTo,
                ),
              ),
              ApButton(
                label: 'Confirmar estrella centrada',
                icon: Icons.check_circle,
                large: true,
                busy:
                    calibration.flowStep == CalibrationFlowStep.savingPoint,
                onPressed: calibration.isBusy
                    ? null
                    : () => _confirm(calibration),
              ),
              ApButton(
                label: 'Elegir otra estrella',
                kind: ApButtonKind.text,
                onPressed: calibration.isBusy
                    ? null
                    : calibration.returnToStarSelection,
              ),
            ],
          ),
          _ => _FailedCard(
            message: error ?? 'La alineación no pudo completarse.',
            onRetry: calibration.returnToStarSelection,
          ),
        },
      ],
    );
  }
}

class _MovingCard extends StatelessWidget {
  final String starName;
  final ({double altitude, double azimuth})? position;
  final double? targetAltitude;
  final double? targetAzimuth;
  final String note;
  final VoidCallback onStop;

  const _MovingCard({
    required this.starName,
    required this.position,
    required this.targetAltitude,
    required this.targetAzimuth,
    required this.note,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return ApCard(
      children: [
        const ApStepBadge('Paso 3 de 5'),
        Row(
          children: [
            Expanded(
              child: Text('Moviendo hacia $starName', style: ApText.title),
            ),
            const ApPill('Moviendo…', tone: ApTone.primary),
          ],
        ),
        const ApProgress(),
        PositionTiles(
          position: position,
          targetAltitude: targetAltitude,
          targetAzimuth: targetAzimuth,
        ),
        Text(note, style: ApText.small),
        ApButton(
          label: 'Detener',
          icon: Icons.stop,
          kind: ApButtonKind.danger,
          onPressed: onStop,
        ),
      ],
    );
  }
}

class _AlignedCard extends StatelessWidget {
  final CalibrationController calibration;
  final ({double altitude, double azimuth})? correction;
  final String? destination;
  final VoidCallback onNext;
  final VoidCallback onGoToDestination;

  const _AlignedCard({
    required this.calibration,
    required this.correction,
    required this.destination,
    required this.onNext,
    required this.onGoToDestination,
  });

  @override
  Widget build(BuildContext context) {
    final star = calibration.initialAlignmentReferenceName ?? 'la estrella';
    final at = calibration.initialAlignmentTimestamp;
    final c = correction;
    return ApCard(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            const ApCardHead(
              icon: Icons.task_alt,
              iconColor: ApColors.ok,
              title: 'Alineación lista',
            ),
            ApPill('Alineado con $star ✓', tone: ApTone.ok),
          ],
        ),
        ApTiles(
          tiles: [
            if (c != null) ...[
              ApTile(
                label: 'Corrección altitud',
                value: formatSignedDeg(c.altitude),
              ),
              ApTile(
                label: 'Corrección azimut',
                value: formatSignedDeg(c.azimuth),
              ),
            ],
            ApTile(label: 'Estrella', value: star, isText: true),
            ApTile(
              label: 'Hora',
              value: at == null ? '—' : formatClock(at),
            ),
          ],
        ),
        if (destination != null) ...[
          ApButton(
            label: 'Ir a $destination',
            icon: Icons.near_me,
            large: true,
            onPressed: onGoToDestination,
          ),
          ApButton(
            label: 'Hacer ajuste fino primero',
            kind: ApButtonKind.outlined,
            onPressed: onNext,
          ),
        ] else
          ApButton(
            label: 'Siguiente',
            icon: Icons.arrow_forward,
            iconAfter: true,
            large: true,
            onPressed: onNext,
          ),
        ApButton(
          label: 'Alinear con otra estrella',
          kind: ApButtonKind.text,
          onPressed: calibration.startInitialAlignment,
        ),
      ],
    );
  }
}

class _FailedCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _FailedCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ApCard(
      children: [
        const ApStepBadge('Paso 3 de 5'),
        ErrorNotice(message),
        ApButton(
          label: 'Elegir una estrella de nuevo',
          icon: Icons.restart_alt,
          kind: ApButtonKind.outlined,
          onPressed: onRetry,
        ),
      ],
    );
  }
}
