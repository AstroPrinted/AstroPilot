import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/calibration_method.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/calibration_result.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/calibration_stage.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/calibration_status.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/correction_model.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/services/pointing_correction_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = PointingCorrectionService();

  test('azimuth error handles 359/0 crossing', () {
    expect(service.azimuthError(calculatedAzimuth: 359, adjustedAzimuth: 1), 2);
    expect(
      service.azimuthError(calculatedAzimuth: 1, adjustedAzimuth: 359),
      -2,
    );
  });

  test('applyCorrection works with future multipoint results', () {
    for (final result in [
      _result(CalibrationMethod.twoStars, CalibrationStatus.calibratedTwoStars),
      _result(
        CalibrationMethod.threeStars,
        CalibrationStatus.calibratedThreeStars,
      ),
    ]) {
      final corrected = service.applyCorrection(
        targetAltitude: 89,
        targetAzimuth: 350,
        calibration: result,
      );

      expect(corrected.altitude, 90);
      expect(corrected.azimuth, 10);
    }
  });
}

CalibrationResult _result(CalibrationMethod method, CalibrationStatus status) {
  return CalibrationResult(
    altitudeOffset: 5,
    azimuthOffset: 20,
    stage: CalibrationStage.correctionCalibration,
    correctionModel: method == CalibrationMethod.twoStars
        ? CorrectionModel.twoStarCorrection
        : CorrectionModel.threeStarCorrection,
    method: method,
    status: status,
    points: const [],
    createdAt: DateTime.utc(2026),
  );
}
