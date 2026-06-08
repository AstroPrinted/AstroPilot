enum CalibrationFlowStep {
  idle,
  selectingMethod,
  waitingHome,
  selectingObject,
  calculatingTarget,
  movingToTarget,
  waitingUserCentering,
  savingPoint,
  calculatingCorrection,
  completed,
  failed,
  cancelled,
}

extension CalibrationFlowStepLabel on CalibrationFlowStep {
  String get title {
    return switch (this) {
      CalibrationFlowStep.idle => 'Inicio',
      CalibrationFlowStep.selectingMethod => 'Selección de método',
      CalibrationFlowStep.waitingHome => 'Posición inicial',
      CalibrationFlowStep.selectingObject => 'Selección de estrella',
      CalibrationFlowStep.calculatingTarget => 'Calculo Alt/Az',
      CalibrationFlowStep.movingToTarget => 'Movimiento automático',
      CalibrationFlowStep.waitingUserCentering => 'Ajuste fino estimado',
      CalibrationFlowStep.savingPoint => 'Guardando punto',
      CalibrationFlowStep.calculatingCorrection => 'Calculando corrección',
      CalibrationFlowStep.completed => 'Resultado',
      CalibrationFlowStep.failed => 'Error',
      CalibrationFlowStep.cancelled => 'Cancelado',
    };
  }

  int? get oneStarStepNumber {
    return switch (this) {
      CalibrationFlowStep.waitingHome => 1,
      CalibrationFlowStep.selectingObject ||
      CalibrationFlowStep.calculatingTarget => 2,
      CalibrationFlowStep.movingToTarget => 3,
      CalibrationFlowStep.waitingUserCentering => 4,
      CalibrationFlowStep.savingPoint ||
      CalibrationFlowStep.calculatingCorrection ||
      CalibrationFlowStep.completed => 5,
      _ => null,
    };
  }
}
