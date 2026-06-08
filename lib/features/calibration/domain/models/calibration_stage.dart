enum CalibrationStage { initialAlignment, correctionCalibration }

extension CalibrationStageLabel on CalibrationStage {
  String get label {
    return switch (this) {
      CalibrationStage.initialAlignment => 'Alineación inicial',
      CalibrationStage.correctionCalibration => 'Corrección de precisión',
    };
  }
}

CalibrationStage calibrationStageFromName(
  String? name, {
  required CalibrationStage fallback,
}) {
  return CalibrationStage.values.firstWhere(
    (stage) => stage.name == name,
    orElse: () => fallback,
  );
}
