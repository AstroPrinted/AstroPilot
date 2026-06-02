import 'dart:math';

import '../../../observation/domain/utils/angle_math.dart';
import '../models/calibration_method.dart';
import '../models/calibration_point.dart';
import '../models/calibration_result.dart';

class PointingCorrectionService {
  const PointingCorrectionService();

  // MVP: la correccion es un offset logico estimado. La validacion optica queda para fases futuras.
  CalibrationResult calculateCorrection(
    CalibrationMethod method,
    List<CalibrationPoint> points,
  ) {
    if (points.isEmpty) {
      throw ArgumentError('La correccion estimada requiere al menos un punto.');
    }

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
      points: List.unmodifiable(points),
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
}
