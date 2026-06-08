import 'dart:math';

import '../../../observation/domain/utils/angle_math.dart';
import '../models/calibration_method.dart';
import '../models/calibration_point.dart';
import '../models/calibration_result.dart';
import '../models/calibration_stage.dart';
import '../models/calibration_status.dart';
import '../models/correction_model.dart';

class PointingCorrectionService {
  const PointingCorrectionService();

  // MVP: la corrección es un offset lógico estimado. La validación óptica queda para fases futuras.
  CalibrationResult calculateCorrection(
    CalibrationMethod method,
    List<CalibrationPoint> points, {
    required CalibrationStage stage,
    List<String> warnings = const [],
  }) {
    if (points.isEmpty) {
      throw ArgumentError('La corrección requiere al menos un punto.');
    }

    // MVP: se promedian offsets registrados. En una fase futura esto puede
    // reemplazarse por un modelo geométrico multipunto más avanzado.
    final altitudeOffset =
        points.map((point) => point.altitudeError).reduce((a, b) => a + b) /
        points.length;
    final azimuthOffset =
        points.map((point) => point.azimuthError).reduce((a, b) => a + b) /
        points.length;
    final estimatedError = sqrt(
      points
              .map(
                (point) =>
                    point.altitudeError * point.altitudeError +
                    point.azimuthError * point.azimuthError,
              )
              .reduce((a, b) => a + b) /
          points.length,
    );

    return CalibrationResult(
      altitudeOffset: altitudeOffset,
      azimuthOffset: azimuthOffset,
      estimatedError: estimatedError,
      stage: stage,
      correctionModel: correctionModelFor(stage: stage, method: method),
      method: method,
      status: _statusFor(stage, method),
      points: List.unmodifiable(points),
      warnings: List.unmodifiable(warnings),
      createdAt: DateTime.now().toUtc(),
    );
  }

  ({double altitude, double azimuth}) applyCorrection({
    required double targetAltitude,
    required double targetAzimuth,
    required CalibrationResult calibration,
  }) {
    final correctedAltitude = (targetAltitude + calibration.altitudeOffset)
        .clamp(-90.0, 90.0)
        .toDouble();
    final correctedAzimuth = normalizeDegrees360(
      targetAzimuth + calibration.azimuthOffset,
    );

    return (altitude: correctedAltitude, azimuth: correctedAzimuth);
  }

  double altitudeError({
    required double calculatedAltitude,
    required double adjustedAltitude,
  }) {
    return adjustedAltitude - calculatedAltitude;
  }

  double azimuthError({
    required double calculatedAzimuth,
    required double adjustedAzimuth,
  }) {
    final diff =
        normalizeDegrees360(adjustedAzimuth) -
        normalizeDegrees360(calculatedAzimuth);
    if (diff > 180.0) return diff - 360.0;
    if (diff < -180.0) return diff + 360.0;
    return diff;
  }

  CalibrationStatus _statusFor(
    CalibrationStage stage,
    CalibrationMethod method,
  ) {
    if (stage == CalibrationStage.initialAlignment) {
      return CalibrationStatus.calibrated;
    }

    return switch (method) {
      CalibrationMethod.oneStar => CalibrationStatus.calibratedOneStar,
      CalibrationMethod.twoStars => CalibrationStatus.calibratedTwoStars,
      CalibrationMethod.threeStars => CalibrationStatus.calibratedThreeStars,
      CalibrationMethod.fixedObjectSync => CalibrationStatus.localSyncActive,
    };
  }
}
