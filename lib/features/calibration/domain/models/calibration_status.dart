enum CalibrationStatus {
  notCalibrated,
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
      CalibrationStatus.notCalibrated => 'Sin correccion estimada',
      CalibrationStatus.inProgress => 'Ajuste logico en curso',
      CalibrationStatus.partiallyCalibrated => 'Correccion estimada parcial',
      CalibrationStatus.calibratedOneStar => 'Correccion estimada: 1 estrella',
      CalibrationStatus.calibratedTwoStars =>
        'Correccion estimada: 2 estrellas',
      CalibrationStatus.calibratedThreeStars =>
        'Correccion estimada: 3 estrellas',
      CalibrationStatus.localSyncActive => 'Sync local activo',
      CalibrationStatus.failed => 'Correccion estimada fallida',
    };
  }
}

CalibrationStatus calibrationStatusFromName(String? name) {
  return CalibrationStatus.values.firstWhere(
    (status) => status.name == name,
    orElse: () => CalibrationStatus.notCalibrated,
  );
}
