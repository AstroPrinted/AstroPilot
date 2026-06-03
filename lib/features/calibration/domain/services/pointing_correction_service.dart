import 'dart:math';

import '../../../observation/domain/utils/angle_math.dart';
import '../models/calibration_method.dart';
import '../models/calibration_point.dart';
import '../models/calibration_result.dart';
import '../models/calibration_status.dart';

class PointingCorrectionService {
  const PointingCorrectionService();

  // MVP: la correccion es un offset logico estimado. La validacion optica queda para fases futuras.
  CalibrationResult calculateCorrection(
    CalibrationMethod method,
    List<CalibrationPoint> points, {
    List<String> warnings = const [],
  }) {
    if (points.isEmpty) {
      throw ArgumentError('La correccion estimada requiere al menos un punto.');
    }

    // MVP: se promedian offsets registrados. En una fase futura esto puede
    // reemplazarse por un modelo geometrico multipunto mas avanzado.
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
      method: method,
      status: _statusFor(method),
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
    return calculatedAltitude - adjustedAltitude;
  }

  double azimuthError({
    required double calculatedAzimuth,
    required double adjustedAzimuth,
  }) {
    final diff =
        normalizeDegrees360(calculatedAzimuth) -
        normalizeDegrees360(adjustedAzimuth);
    if (diff > 180.0) return diff - 360.0;
    if (diff < -180.0) return diff + 360.0;
    return diff;
  }

  CalibrationStatus _statusFor(CalibrationMethod method) {
    return switch (method) {
      CalibrationMethod.oneStar => CalibrationStatus.calibratedOneStar,
      CalibrationMethod.twoStars => CalibrationStatus.calibratedTwoStars,
      CalibrationMethod.threeStars => CalibrationStatus.calibratedThreeStars,
      CalibrationMethod.fixedObjectSync => CalibrationStatus.localSyncActive,
    };
  }
}
