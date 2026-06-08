import 'calibration_method.dart';
import 'calibration_stage.dart';

enum CorrectionModel {
  none,
  singleOffset,
  twoStarCorrection,
  threeStarCorrection,
  fixedObjectCorrection,
}

extension CorrectionModelLabel on CorrectionModel {
  String get label {
    return switch (this) {
      CorrectionModel.none => 'Sin corrección',
      CorrectionModel.singleOffset => 'Offset simple',
      CorrectionModel.twoStarCorrection => 'Corrección de 2 estrellas',
      CorrectionModel.threeStarCorrection => 'Corrección de 3 estrellas',
      CorrectionModel.fixedObjectCorrection => 'Corrección con objeto fijo',
    };
  }
}

CorrectionModel correctionModelFor({
  required CalibrationStage stage,
  required CalibrationMethod method,
}) {
  if (stage == CalibrationStage.initialAlignment) {
    return CorrectionModel.none;
  }

  return switch (method) {
    CalibrationMethod.oneStar => CorrectionModel.singleOffset,
    CalibrationMethod.twoStars => CorrectionModel.twoStarCorrection,
    CalibrationMethod.threeStars => CorrectionModel.threeStarCorrection,
    CalibrationMethod.fixedObjectSync => CorrectionModel.fixedObjectCorrection,
  };
}

CorrectionModel correctionModelFromName(
  String? name, {
  required CorrectionModel fallback,
}) {
  return CorrectionModel.values.firstWhere(
    (model) => model.name == name,
    orElse: () => fallback,
  );
}
