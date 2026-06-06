enum CalibrationStatus {
  notCalibrated,
  selectingReferenceStar,
  waitingForManualCentering,
  calibrated,
  calibrationFailed,
  inProgress,
  partiallyCalibrated,
  calibratedOneStar,
  calibratedTwoStars,
  calibratedThreeStars,
  localSyncActive,
  failed,
}

extension CalibrationStatusLabel on CalibrationStatus {
  String get label {
    return switch (this) {
      CalibrationStatus.notCalibrated => 'Sin calibracion',
      CalibrationStatus.selectingReferenceStar =>
        'Seleccionando estrella de referencia',
      CalibrationStatus.waitingForManualCentering =>
        'Esperando centrado manual',
      CalibrationStatus.calibrated => 'Calibrado',
      CalibrationStatus.calibrationFailed => 'Calibracion fallida',
      CalibrationStatus.inProgress => 'Calibracion en curso',
      CalibrationStatus.partiallyCalibrated => 'Calibracion parcial',
      CalibrationStatus.calibratedOneStar => 'Calibrado: 1 estrella',
      CalibrationStatus.calibratedTwoStars => 'Calibrado: 2 estrellas',
      CalibrationStatus.calibratedThreeStars => 'Calibrado: 3 estrellas',
      CalibrationStatus.localSyncActive => 'Sync local activo',
      CalibrationStatus.failed => 'Calibracion fallida',
    };
  }
}

CalibrationStatus calibrationStatusFromName(String? name) {
  return CalibrationStatus.values.firstWhere(
    (status) => status.name == name,
    orElse: () => CalibrationStatus.notCalibrated,
  );
}
