import '../models/calibration_method.dart';
import '../models/calibration_point.dart';
import '../models/calibration_result.dart';
import '../models/calibration_session.dart';
import '../models/calibration_status.dart';
import 'pointing_correction_service.dart';

class CalibrationService {
  final PointingCorrectionService correctionService;

  const CalibrationService({required this.correctionService});

  // Fase 1 registra una referencia logica de motores; no certifica alineacion optica.
  CalibrationSession startSession(CalibrationMethod method) {
    return CalibrationSession(
      method: method,
      status: CalibrationStatus.inProgress,
      points: const [],
      startedAt: DateTime.now().toUtc(),
    );
  }

  CalibrationPoint createPoint({
    required String objectName,
    required double calculatedAltitude,
    required double calculatedAzimuth,
    required double adjustedAltitude,
    required double adjustedAzimuth,
  }) {
    final altitudeError = correctionService.altitudeError(
      calculatedAltitude: calculatedAltitude,
      adjustedAltitude: adjustedAltitude,
    );
    final azimuthError = correctionService.azimuthError(
      calculatedAzimuth: calculatedAzimuth,
      adjustedAzimuth: adjustedAzimuth,
    );

    return CalibrationPoint(
      objectName: objectName,
      calculatedAltitude: calculatedAltitude,
      calculatedAzimuth: calculatedAzimuth,
      adjustedAltitude: adjustedAltitude,
      adjustedAzimuth: adjustedAzimuth,
      altitudeError: altitudeError,
      azimuthError: azimuthError,
      timestamp: DateTime.now().toUtc(),
    );
  }

  CalibrationSession addPoint(
    CalibrationSession session,
    CalibrationPoint point,
  ) {
    final points = [...session.points, point];
    return session.copyWith(
      points: List.unmodifiable(points),
      status: _statusFor(session.method, points.length),
      completedAt: points.length >= session.method.requiredPointCount
          ? DateTime.now().toUtc()
          : null,
    );
  }

  CalibrationResult completeSession(CalibrationSession session) {
    return correctionService.calculateCorrection(
      session.method,
      session.points,
    );
  }

  CalibrationStatus _statusFor(CalibrationMethod method, int pointCount) {
    if (pointCount <= 0) return CalibrationStatus.inProgress;
    if (pointCount < method.requiredPointCount) {
      return CalibrationStatus.partiallyCalibrated;
    }

    return switch (method) {
      CalibrationMethod.oneStar => CalibrationStatus.calibratedOneStar,
      CalibrationMethod.twoStars => CalibrationStatus.calibratedTwoStars,
      CalibrationMethod.threeStars => CalibrationStatus.calibratedThreeStars,
      CalibrationMethod.fixedObjectSync => CalibrationStatus.localSyncActive,
    };
  }
}
