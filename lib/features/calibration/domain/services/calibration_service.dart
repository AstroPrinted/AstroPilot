import '../models/calibration_method.dart';
import '../models/calibration_point.dart';
import '../models/calibration_result.dart';
import '../models/calibration_session.dart';
import '../models/calibration_stage.dart';
import '../models/calibration_status.dart';
import 'pointing_correction_service.dart';

class CalibrationService {
  final PointingCorrectionService correctionService;

  const CalibrationService({required this.correctionService});

  CalibrationSession startSession({
    required CalibrationStage stage,
    required CalibrationMethod method,
  }) {
    return CalibrationSession(
      stage: stage,
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
        '${point.objectName} ya fue registrada como referencia en esta sesión.',
      );
    }

    final points = [...session.points, point];
    return session.copyWith(
      points: List.unmodifiable(points),
      status: _statusFor(session.stage, session.method, points.length),
      completedAt: points.length >= session.method.requiredPointCount
          ? DateTime.now().toUtc()
          : null,
    );
  }

  CalibrationResult completeSession(CalibrationSession session) {
    if (session.points.length < session.method.requiredPointCount) {
      throw StateError(
        'El flujo requiere ${session.method.requiredPointCount} referencias.',
      );
    }

    return correctionService.calculateCorrection(
      session.method,
      session.points,
      stage: session.stage,
      warnings: session.warnings,
    );
  }

  ({double altitude, double azimuth}) applyCorrection({
    required double targetAltitude,
    required double targetAzimuth,
    required CalibrationResult correction,
  }) {
    return correctionService.applyCorrection(
      targetAltitude: targetAltitude,
      targetAzimuth: targetAzimuth,
      calibration: correction,
    );
  }

  CalibrationStatus _statusFor(
    CalibrationStage stage,
    CalibrationMethod method,
    int pointCount,
  ) {
    if (pointCount <= 0) return CalibrationStatus.inProgress;
    if (pointCount < method.requiredPointCount) {
      return CalibrationStatus.partiallyCalibrated;
    }

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
