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
      CalibrationFlowStep.selectingMethod => 'Seleccion de metodo',
      CalibrationFlowStep.waitingHome => 'Posicion inicial',
      CalibrationFlowStep.selectingObject => 'Seleccion de estrella',
      CalibrationFlowStep.calculatingTarget => 'Calculo Alt/Az',
      CalibrationFlowStep.movingToTarget => 'Movimiento automatico',
      CalibrationFlowStep.waitingUserCentering => 'Ajuste fino estimado',
      CalibrationFlowStep.savingPoint => 'Guardando punto',
      CalibrationFlowStep.calculatingCorrection => 'Calculando correccion',
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
