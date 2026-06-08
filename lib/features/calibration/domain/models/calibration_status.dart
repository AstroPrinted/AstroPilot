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
      CalibrationStatus.notCalibrated => 'Sin alineación',
      CalibrationStatus.selectingReferenceStar =>
        'Seleccionando estrella de referencia',
      CalibrationStatus.waitingForManualCentering =>
        'Esperando centrado manual',
      CalibrationStatus.calibrated => 'Alineado',
      CalibrationStatus.calibrationFailed => 'Flujo fallido',
      CalibrationStatus.inProgress => 'En curso',
      CalibrationStatus.partiallyCalibrated => 'Corrección parcial',
      CalibrationStatus.calibratedOneStar => 'Corrección: 1 estrella',
      CalibrationStatus.calibratedTwoStars => 'Corrección: 2 estrellas',
      CalibrationStatus.calibratedThreeStars => 'Corrección: 3 estrellas',
      CalibrationStatus.localSyncActive => 'Corrección local activa',
      CalibrationStatus.failed => 'Flujo fallido',
    };
  }
}

CalibrationStatus calibrationStatusFromName(String? name) {
  return CalibrationStatus.values.firstWhere(
    (status) => status.name == name,
    orElse: () => CalibrationStatus.notCalibrated,
  );
}
