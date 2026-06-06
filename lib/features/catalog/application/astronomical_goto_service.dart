import 'package:flutter/foundation.dart';

import '../../calibration/data/calibration_repository.dart';
import '../../calibration/domain/models/calibration_method.dart';
import '../../calibration/domain/models/calibration_result.dart';
import '../../calibration/domain/services/astronomy_position_service.dart';
import '../../calibration/domain/services/pointing_correction_service.dart';
import '../../observation/domain/models/alt_az_result.dart';
import '../../observation/domain/models/observer_data.dart';
import '../../observation/domain/services/observer_data_provider.dart';
import '../../observation/domain/utils/angle_math.dart';
import '../domain/models/celestial_object.dart';

typedef AstronomicalGotoSender =
    Future<void> Function(double altitude, double azimuth);

typedef AstronomicalPositionResolver =
    AltAzResult Function(CelestialObject object, ObserverData observer);

class AstronomicalGotoCommand {
  final CelestialObject object;
  final AltAzResult rawPosition;
  final CalibrationResult? calibration;
  final double finalAltitude;
  final double finalAzimuth;

  const AstronomicalGotoCommand({
    required this.object,
    required this.rawPosition,
    required this.calibration,
    required this.finalAltitude,
    required this.finalAzimuth,
  });

  bool get hasCalibration => calibration != null;
  bool get usedCorrection =>
      calibration != null && calibration!.method != CalibrationMethod.oneStar;
}

class AstronomicalGotoService {
  final ObserverDataProvider observerDataProvider;
  final CalibrationRepository calibrationRepository;
  final AstronomyPositionService astronomyPositionService;
  final PointingCorrectionService correctionService;
  final AstronomicalPositionResolver? positionResolver;

  const AstronomicalGotoService({
    required this.observerDataProvider,
    required this.calibrationRepository,
    this.astronomyPositionService = const AstronomyPositionService(),
    this.correctionService = const PointingCorrectionService(),
    this.positionResolver,
  });

  Future<CalibrationResult?> loadSavedCalibration() {
    return calibrationRepository.loadCurrentResult();
  }

  AltAzResult calculateCurrentPosition(CelestialObject object) {
    if (_isSun(object)) {
      throw StateError('GoTo solar bloqueado por seguridad ocular.');
    }

    final observer = observerDataProvider.current();
    return _calculatePosition(object, observer);
  }

  AstronomicalGotoCommand buildCommand({
    required CelestialObject object,
    required AltAzResult rawPosition,
    required CalibrationResult? calibration,
  }) {
    _ensureGotoAllowed(object, rawPosition);
    _ensureCalibrated(calibration);
    final savedCalibration = calibration!;

    final usesOffset = savedCalibration.method != CalibrationMethod.oneStar;
    final corrected = !usesOffset
        ? (
            altitude: rawPosition.altitudeDeg.clamp(-90.0, 90.0).toDouble(),
            azimuth: normalizeDegrees360(rawPosition.azimuthDeg),
          )
        : correctionService.applyCorrection(
            targetAltitude: rawPosition.altitudeDeg,
            targetAzimuth: rawPosition.azimuthDeg,
            calibration: savedCalibration,
          );

    return AstronomicalGotoCommand(
      object: object,
      rawPosition: rawPosition,
      calibration: savedCalibration,
      finalAltitude: corrected.altitude,
      finalAzimuth: corrected.azimuth,
    );
  }

  Future<AstronomicalGotoCommand> prepareCommand(CelestialObject object) async {
    if (_isSun(object)) {
      throw StateError('GoTo solar bloqueado por seguridad ocular.');
    }

    debugPrint('[AstronomicalGoTo] Object: ${object.name}');
    final rawPosition = calculateCurrentPosition(object);
    debugPrint(
      '[AstronomicalGoTo] Raw Alt/Az: '
      '${rawPosition.altitudeDeg.toStringAsFixed(4)} / '
      '${rawPosition.azimuthDeg.toStringAsFixed(4)}',
    );

    final calibration = await loadSavedCalibration();
    debugPrint('[AstronomicalGoTo] Calibration found: ${calibration != null}');
    if (calibration == null) {
      throw StateError(
        'Telescopio no calibrado. Realiza calibracion con una estrella antes de usar GoTo.',
      );
    }
    debugPrint(
      '[AstronomicalGoTo] Offset Alt/Az: '
      '${calibration.altitudeOffset.toStringAsFixed(4)} / '
      '${calibration.azimuthOffset.toStringAsFixed(4)}',
    );

    final command = buildCommand(
      object: object,
      rawPosition: rawPosition,
      calibration: calibration,
    );
    debugPrint(
      '[AstronomicalGoTo] Corrected Alt/Az: '
      '${command.finalAltitude.toStringAsFixed(4)} / '
      '${command.finalAzimuth.toStringAsFixed(4)}',
    );

    return command;
  }

  Future<AstronomicalGotoCommand> sendGoto({
    required CelestialObject object,
    required AstronomicalGotoSender send,
  }) async {
    final command = await prepareCommand(object);
    debugPrint('[AstronomicalGoTo] Sending GOTO...');
    await send(command.finalAltitude, command.finalAzimuth);
    return command;
  }

  AltAzResult _calculatePosition(
    CelestialObject object,
    ObserverData observer,
  ) {
    final resolver = positionResolver;
    if (resolver != null) {
      return resolver(object, observer);
    }

    return astronomyPositionService.calculateForObject(
      object: object,
      observer: observer,
    );
  }

  void _ensureGotoAllowed(CelestialObject object, AltAzResult rawPosition) {
    if (_isSun(object)) {
      throw StateError('GoTo solar bloqueado por seguridad ocular.');
    }
    if (rawPosition.altitudeDeg < 0.0) {
      throw StateError('Objeto bajo el horizonte. GoTo bloqueado.');
    }
  }

  void _ensureCalibrated(CalibrationResult? calibration) {
    if (calibration == null) {
      throw StateError(
        'Telescopio no calibrado. Realiza calibracion con una estrella antes de usar GoTo.',
      );
    }
  }

  bool _isSun(CelestialObject object) {
    return object is SolarSystemBody && object.isSun;
  }
}
