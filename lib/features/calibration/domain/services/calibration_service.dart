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
      status: CalibrationStatus.selectingReferenceStar,
      points: const [],
      startedAt: DateTime.now().toUtc(),
    );
  }

  CalibrationPoint createPoint({
    required String objectId,
    required String objectName,
    required double calculatedAltitude,
    required double calculatedAzimuth,
    required double adjustedAltitude,
    required double adjustedAzimuth,
    double? referenceRaJ2000Hours,
    double? referenceDecJ2000Degrees,
    double? motorAltitudeAtCalibration,
    double? motorAzimuthAtCalibration,
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
      objectId: objectId,
      objectName: objectName,
      calculatedAltitude: calculatedAltitude,
      calculatedAzimuth: calculatedAzimuth,
      adjustedAltitude: adjustedAltitude,
      adjustedAzimuth: adjustedAzimuth,
      altitudeError: altitudeError,
      azimuthError: azimuthError,
      referenceRaJ2000Hours: referenceRaJ2000Hours,
      referenceDecJ2000Degrees: referenceDecJ2000Degrees,
      motorAltitudeAtCalibration: motorAltitudeAtCalibration,
      motorAzimuthAtCalibration: motorAzimuthAtCalibration,
      timestamp: DateTime.now().toUtc(),
    );
  }

  CalibrationPoint createPositionReferencePoint({
    required String objectId,
    required String objectName,
    required double referenceRaJ2000Hours,
    required double referenceDecJ2000Degrees,
    required double altitude,
    required double azimuth,
  }) {
    return CalibrationPoint(
      objectId: objectId,
      objectName: objectName,
      calculatedAltitude: altitude,
      calculatedAzimuth: azimuth,
      adjustedAltitude: altitude,
      adjustedAzimuth: azimuth,
      altitudeError: 0.0,
      azimuthError: 0.0,
      referenceRaJ2000Hours: referenceRaJ2000Hours,
      referenceDecJ2000Degrees: referenceDecJ2000Degrees,
      motorAltitudeAtCalibration: altitude,
      motorAzimuthAtCalibration: azimuth,
      timestamp: DateTime.now().toUtc(),
    );
  }

  CalibrationSession addWarning(CalibrationSession session, String warning) {
    if (session.warnings.contains(warning)) return session;

    return session.copyWith(
      warnings: List.unmodifiable([...session.warnings, warning]),
    );
  }

  CalibrationSession addPoint(
    CalibrationSession session,
    CalibrationPoint point,
  ) {
    final alreadyRegistered = session.points.any(
      (existing) =>
          existing.objectId == point.objectId ||
          existing.objectName == point.objectName,
    );
    if (alreadyRegistered) {
      throw StateError(
        '${point.objectName} ya fue registrada como referencia en esta sesion.',
      );
    }

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
    if (session.points.length < session.method.requiredPointCount) {
      throw StateError(
        'La calibracion logica requiere ${session.method.requiredPointCount} referencias.',
      );
    }

    return correctionService.calculateCorrection(
      session.method,
      session.points,
      warnings: session.warnings,
    );
  }

  CalibrationStatus _statusFor(CalibrationMethod method, int pointCount) {
    if (pointCount <= 0) return CalibrationStatus.inProgress;
    if (pointCount < method.requiredPointCount) {
      return CalibrationStatus.partiallyCalibrated;
    }

    return switch (method) {
      CalibrationMethod.oneStar => CalibrationStatus.calibrated,
      CalibrationMethod.twoStars => CalibrationStatus.calibratedTwoStars,
      CalibrationMethod.threeStars => CalibrationStatus.calibratedThreeStars,
      CalibrationMethod.fixedObjectSync => CalibrationStatus.localSyncActive,
    };
  }
}
