import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../../../core/widgets/ap_widgets.dart';
import '../../../../calibration/presentation/controllers/calibration_controller.dart';
import '../../../../settings/application/settings_service.dart';
import '../../../application/app_flow_state.dart';

/// Qué pasos del tutorial de Observación están completos, calculado desde
/// el estado real (conexión, configuración, 0/0, alineación y ajuste fino).
class ObservationProgress {
  final bool connected;
  final bool locationOk;
  final bool timeOk;
  final bool zeroFixed;
  final bool aligned;
  final bool fineDone;

  const ObservationProgress({
    required this.connected,
    required this.locationOk,
    required this.timeOk,
    required this.zeroFixed,
    required this.aligned,
    required this.fineDone,
  });

  factory ObservationProgress.watch(BuildContext context) {
    final flow = context.watch<AppFlowState>();
    final settings = context.watch<SettingsService>().state;
    final calibration = context.watch<CalibrationController>();
    return ObservationProgress(
      connected: flow.isConnected,
      locationOk: settings.isWithinChileBounds,
      timeOk: !settings.isCustomTime,
      zeroFixed: flow.isZeroFixed,
      aligned: calibration.isInitialAligned,
      fineDone: calibration.hasCorrectionCalibration || flow.fineAdjustSkipped,
    );
  }

  bool get checksOk => locationOk && timeOk;

  bool isDone(ObservationStep step) => switch (step) {
    ObservationStep.connection => connected && checksOk,
    ObservationStep.leveling => zeroFixed,
    ObservationStep.alignment => aligned,
    ObservationStep.fineAdjust => fineDone,
    ObservationStep.catalog => false,
  };

  /// El primer paso que falta (o Catálogo si todo está listo).
  ObservationStep get firstIncomplete => ObservationStep.values.firstWhere(
    (s) => !isDone(s),
    orElse: () => ObservationStep.catalog,
  );

  /// Un paso se puede abrir si los anteriores están completos.
  bool canOpen(ObservationStep step) =>
      step.index <= firstIncomplete.index || isDone(step);

  List<ApStepState> stepStates(ObservationStep current) => [
    for (final step in ObservationStep.values)
      if (step == current)
        ApStepState.now
      else if (isDone(step))
        ApStepState.done
      else
        ApStepState.todo,
  ];
}
