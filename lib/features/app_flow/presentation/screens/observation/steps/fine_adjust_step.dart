import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/widgets/ap_widgets.dart';
import '../../../../../calibration/domain/models/calibration_flow_step.dart';
import '../../../../../calibration/domain/models/calibration_method.dart';
import '../../../../../calibration/domain/models/calibration_result.dart';
import '../../../../../calibration/presentation/controllers/calibration_controller.dart';
import '../../../../../oe4_control/presentation/controllers/oe4_control_controller.dart';
import '../../../../application/app_flow_state.dart';
import '../../../widgets/mode_scaffold.dart';
import '../../../widgets/object_display.dart';
import '../../../widgets/telescope_commands.dart';
import 'star_picker.dart';
import 'step_widgets.dart';

/// Paso 4 (opcional): ajuste fino con 1, 2 o 3 estrellas.
class FineAdjustStep extends StatefulWidget {
  final VoidCallback onFinish;

  const FineAdjustStep({super.key, required this.onFinish});

  @override
  State<FineAdjustStep> createState() => _FineAdjustStepState();
}

class _FineAdjustStepState extends State<FineAdjustStep> {
  /// Muestra las opciones aunque ya exista una corrección (repetir).
  bool _choosing = false;

  bool _inFlow(CalibrationController c) =>
      c.session != null && c.isCorrectionCalibrationFlow;

  Future<void> _askSkip() async {
    final skip = await showDialog<bool>(
      context: context,
      builder: (context) => const _SkipDialog(),
    );
    if (skip != true || !mounted) return;
    context.read<AppFlowState>().skipFineAdjust();
    widget.onFinish();
  }

  void _start(CalibrationController calibration, CalibrationMethod method) {
    context.read<AppFlowState>().clearFineAdjustSkip();
    setState(() => _choosing = false);
    calibration.startCorrectionMethod(method);
  }

  Future<void> _goToReference(
    CalibrationController calibration,
    CalibrationStarOption option,
  ) async {
    final commands = TelescopeCommands.of(context);
    await calibration.selectStar(option);
    if (calibration.flowStep != CalibrationFlowStep.movingToTarget) return;
    await calibration.sendGotoToReference(commands.goto);
  }

  @override
  Widget build(BuildContext context) {
    final calibration = context.watch<CalibrationController>();
    final flow = context.watch<AppFlowState>();
    final pending = flow.pendingObject;
    final finishLabel = pending == null
        ? 'Ir al catálogo'
        : 'Ir a ${ObjectDisplay.shortName(pending)}';

    if (!calibration.isInitialAligned && !_inFlow(calibration)) {
      return const ModeBody(
        children: [
          ApCard(
            children: [
              ApStepBadge('Paso 4 de 5 · opcional'),
              Text('Primero alinea con una estrella', style: ApText.title),
              Text(
                'El ajuste fino corrige los GOTO a partir de la alineación '
                'del paso 3.',
                style: ApText.body,
              ),
            ],
          ),
        ],
      );
    }

    if (_inFlow(calibration)) {
      if (calibration.flowStep == CalibrationFlowStep.completed) {
        final result = calibration.correctionCalibrationResult;
        return ModeBody(
          children: [
            if (result != null)
              _SummaryCard(
                result: result,
                finishLabel: finishLabel,
                onFinish: () {
                  calibration.cancelFlow();
                  widget.onFinish();
                },
              ),
          ],
        );
      }
      return _ReferenceFlow(
        calibration: calibration,
        onGo: (option) => _goToReference(calibration, option),
      );
    }

    final existing = calibration.correctionCalibrationResult;
    if (existing != null && existing.hasCorrectionCalibration && !_choosing) {
      return ModeBody(
        children: [
          _SummaryCard(
            result: existing,
            finishLabel: finishLabel,
            onFinish: widget.onFinish,
          ),
          ApButton(
            label: 'Repetir ajuste fino',
            kind: ApButtonKind.text,
            onPressed: () => setState(() => _choosing = true),
          ),
        ],
      );
    }

    return ModeBody(
      children: [
        ApCard(
          children: [
            const ApStepBadge('Paso 4 de 5 · opcional'),
            const Text('Ajuste fino', style: ApText.title),
            const Text(
              'Mejora la precisión de los próximos GOTO. Mientras más '
              'referencias, más preciso.',
              style: ApText.body,
            ),
            if (calibration.errorMessage != null)
              ErrorNotice(calibration.errorMessage!),
            ApMethodTile(
              icon: Icons.filter_1,
              title: '1 estrella',
              subtitle: 'Corrige un desplazamiento fijo en altitud y azimut.',
              onTap: () => _start(calibration, CalibrationMethod.oneStar),
            ),
            ApMethodTile(
              icon: Icons.filter_2,
              title: '2 estrellas',
              subtitle: 'Corrige además la inclinación de la base.',
              onTap: () => _start(calibration, CalibrationMethod.twoStars),
            ),
            ApMethodTile(
              icon: Icons.filter_3,
              title: '3 estrellas',
              subtitle: 'Modelo completo, mayor precisión en todo el cielo.',
              onTap: () => _start(calibration, CalibrationMethod.threeStars),
            ),
            const ApMethodTile(
              icon: Icons.cell_tower,
              title: 'Objeto fijo',
              subtitle:
                  'Apunta a una antena u otro objeto fijo e indica su '
                  'posición respecto del telescopio.',
              trailing: ApPill('Próximamente', tone: ApTone.muted, small: true),
            ),
          ],
        ),
        ApButton(
          label: 'Saltar por ahora',
          kind: ApButtonKind.outlined,
          onPressed: _askSkip,
        ),
      ],
    );
  }
}

class _ReferenceFlow extends StatelessWidget {
  final CalibrationController calibration;
  final Future<void> Function(CalibrationStarOption option) onGo;

  const _ReferenceFlow({required this.calibration, required this.onGo});

  @override
  Widget build(BuildContext context) {
    final oe4 = context.watch<Oe4ControlController>();
    final commands = TelescopeCommands.of(context);
    final total = calibration.requiredReferenceCount;
    final starName = calibration.selectedStar?.name ?? 'la estrella';
    final error = calibration.errorMessage;
    final warning = calibration.flowWarningMessage;

    final content = switch (calibration.flowStep) {
      CalibrationFlowStep.selectingObject ||
      CalibrationFlowStep.calculatingTarget => <Widget>[
        const Text('Elige la estrella de referencia', style: ApText.title),
        const Text(
          'Mejor si está lejos de las que ya usaste.',
          style: ApText.body,
        ),
        if (error != null) ErrorNotice(error),
        StarPicker(
          options: calibration.calibrationStarOptions,
          busy:
              calibration.isBusy ||
              calibration.flowStep == CalibrationFlowStep.calculatingTarget,
          actionLabel: 'Enviar GOTO a la referencia',
          onGo: onGo,
        ),
      ],
      CalibrationFlowStep.movingToTarget => <Widget>[
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
          position: oe4.telescopePosition,
          targetAltitude: calibration.targetPosition?.altitudeDeg,
          targetAzimuth: calibration.targetPosition?.azimuthDeg,
        ),
        ApButton(
          label: 'Detener',
          icon: Icons.stop,
          kind: ApButtonKind.danger,
          onPressed: () => calibration.abortReferenceGoto(commands.stop),
        ),
      ],
      CalibrationFlowStep.waitingUserCentering ||
      CalibrationFlowStep.savingPoint => <Widget>[
        Text('Centra $starName', style: ApText.title),
        if (warning != null)
          ApNotice(icon: Icons.warning, tone: ApTone.warn, text: warning),
        PositionTiles(position: oe4.telescopePosition),
        // Below the arrows so they never shift under the finger.
        CalibrationJoystick(
          calibration: calibration,
          commands: commands,
          enabled: calibration.flowStep != CalibrationFlowStep.savingPoint,
        ),
        if (error != null) ErrorNotice(error),
        if (oe4.movementWarning != null)
          ApNotice(
            icon: Icons.warning,
            tone: ApTone.warn,
            text: oe4.movementWarning!,
          ),
        ApButton(
          label: 'Confirmar estrella centrada',
          icon: Icons.check_circle,
          large: true,
          busy: calibration.flowStep == CalibrationFlowStep.savingPoint,
          onPressed: calibration.isBusy
              ? null
              : () => calibration.confirmCenteredReference(
                  refreshPosition: commands.status,
                ),
        ),
      ],
      _ => <Widget>[
        ErrorNotice(error ?? 'El ajuste fino no pudo completarse.'),
        ApButton(
          label: 'Elegir otra referencia',
          icon: Icons.restart_alt,
          kind: ApButtonKind.outlined,
          onPressed: calibration.returnToStarSelection,
        ),
      ],
    };

    return ModeBody(
      children: [
        ApCard(
          children: [
            Row(
              children: [
                ApStepBadge(
                  'Referencia ${calibration.currentReferenceNumber} de $total',
                ),
                const Spacer(),
                Text(
                  'Ajuste de $total ${total == 1 ? 'estrella' : 'estrellas'}',
                  style: ApText.small,
                ),
              ],
            ),
            ...content,
            ApButton(
              label: 'Cancelar ajuste fino',
              kind: ApButtonKind.text,
              onPressed: calibration.isBusy ? null : calibration.cancelFlow,
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final CalibrationResult result;
  final String finishLabel;
  final VoidCallback onFinish;

  const _SummaryCard({
    required this.result,
    required this.finishLabel,
    required this.onFinish,
  });

  /// Error medio de las referencias antes de corregir.
  double get _errorBefore {
    if (result.points.isEmpty) return 0;
    final total = result.points.fold<double>(
      0,
      (sum, p) => sum + math.sqrt(
        p.altitudeError * p.altitudeError + p.azimuthError * p.azimuthError,
      ),
    );
    return total / result.points.length;
  }

  @override
  Widget build(BuildContext context) {
    final after = result.estimatedError;
    final errorText = after == null
        ? formatDeg(_errorBefore)
        : '${formatDeg(_errorBefore)} → ${formatDeg(after)}';
    final used = result.points.map((p) => p.objectName).join(', ');
    return ApCard(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: const [
            ApCardHead(
              icon: Icons.task_alt,
              iconColor: ApColors.ok,
              title: 'Ajuste fino completado',
            ),
            ApPill('Guardado', tone: ApTone.ok),
          ],
        ),
        ApTiles(
          tiles: [
            ApTile(label: 'Referencias', value: '${result.points.length}'),
            ApTile(label: 'Error medio', value: errorText, fontSize: 15),
            ApTile(
              label: 'Offset altitud',
              value: formatSignedDeg(result.altitudeOffset),
            ),
            ApTile(
              label: 'Offset azimut',
              value: formatSignedDeg(result.azimuthOffset),
            ),
          ],
        ),
        if (used.isNotEmpty)
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Estrellas usadas: '),
                TextSpan(text: used, style: ApText.strong),
              ],
            ),
            style: ApText.body,
          ),
        ApButton(
          label: finishLabel,
          icon: Icons.arrow_forward,
          iconAfter: true,
          large: true,
          onPressed: onFinish,
        ),
      ],
    );
  }
}

class _SkipDialog extends StatelessWidget {
  const _SkipDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.warning, color: ApColors.warn),
      title: const Text('¿Saltar el ajuste fino?', textAlign: TextAlign.center),
      content: const Text(
        'Sin ajuste fino, los objetos podrían no quedar centrados al hacer '
        'GOTO. Puedes calibrar más tarde desde Alineación.',
        style: ApText.body,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Saltar igual'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Hacer ajuste fino'),
        ),
      ],
    );
  }
}
