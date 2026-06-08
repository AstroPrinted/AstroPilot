enum CorrectionCalibrationStatus {
  notCalibrated,
  selectingCalibrationMode,
  selectingCalibrationTarget,
  gotoTarget,
  waitingForManualCorrection,
  correctionCalculated,
  calibrated,
  calibrationFailed,
}

extension CorrectionCalibrationStatusLabel on CorrectionCalibrationStatus {
  String get label {
    return switch (this) {
      CorrectionCalibrationStatus.notCalibrated => 'Disponible',
      CorrectionCalibrationStatus.selectingCalibrationMode =>
        'Seleccionando modo',
      CorrectionCalibrationStatus.selectingCalibrationTarget =>
        'Seleccionando referencia',
      CorrectionCalibrationStatus.gotoTarget => 'GOTO a referencia',
      CorrectionCalibrationStatus.waitingForManualCorrection =>
        'Esperando corrección manual',
      CorrectionCalibrationStatus.correctionCalculated =>
        'Corrección calculada',
      CorrectionCalibrationStatus.calibrated => 'Corrección activa',
      CorrectionCalibrationStatus.calibrationFailed => 'Corrección fallida',
    };
  }
}
