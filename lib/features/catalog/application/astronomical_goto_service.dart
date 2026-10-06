import 'package:flutter/foundation.dart';

import '../../calibration/data/calibration_repository.dart';
import '../../calibration/domain/models/calibration_result.dart';
import '../../calibration/domain/services/astronomy_position_service.dart';
import '../../calibration/domain/services/pointing_correction_service.dart';
import '../../calibration/domain/services/alignment_session.dart';
import '../../observation/domain/models/alt_az_result.dart';
import '../../observation/domain/models/observer_data.dart';
import '../../observation/domain/services/observer_data_provider.dart';
import '../../observation/domain/services/sun_guard.dart';
import '../../observation/domain/utils/angle_math.dart';
import '../domain/models/celestial_object.dart';

typedef AstronomicalGotoSender =
    Future<void> Function(double altitude, double azimuth);

typedef AstronomicalPositionResolver =
    AltAzResult Function(CelestialObject object, ObserverData observer);

class AstronomicalGotoCommand {
  final CelestialObject object;
  final AltAzResult rawPosition;
  final CalibrationResult initialAlignment;
  final CalibrationResult? correctionCalibration;
  final double finalAltitude;
  final double finalAzimuth;

  const AstronomicalGotoCommand({
    required this.object,
    required this.rawPosition,
    required this.initialAlignment,
    required this.correctionCalibration,
    required this.finalAltitude,
    required this.finalAzimuth,
  });

  bool get hasCalibration => true;
  bool get usedCorrection =>
      correctionCalibration?.hasCorrectionCalibration ?? false;
}

class AstronomicalGotoService {
  final ObserverDataProvider observerDataProvider;
  final CalibrationRepository calibrationRepository;
  final AstronomyPositionService astronomyPositionService;
  final PointingCorrectionService correctionService;
  final AstronomicalPositionResolver? positionResolver;

  /// Bloquea el GoTo a un objeto que está delante o detrás del Sol.
  final SunGuard? sunGuard;

  const AstronomicalGotoService({
    required this.observerDataProvider,
    required this.calibrationRepository,
    this.astronomyPositionService = const AstronomyPositionService(),
    this.correctionService = const PointingCorrectionService(),
    this.positionResolver,
    this.sunGuard,
  });

  Future<CalibrationResult?> loadSavedCalibration() {
    return loadInitialAlignment();
  }

  Future<CalibrationResult?> loadInitialAlignment() {
    return calibrationRepository.loadInitialAlignmentResult();
  }

  Future<CalibrationResult?> loadCorrectionCalibration() {
    return calibrationRepository.loadCorrectionCalibrationResult();
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
    required CalibrationResult? initialAlignment,
    required CalibrationResult? correctionCalibration,
  }) {
    _ensureGotoAllowed(object, rawPosition);
    _ensureInitialAligned(initialAlignment);
    final savedInitialAlignment = initialAlignment!;

    final correction = correctionCalibration;
    final usesOffset = correction?.hasCorrectionCalibration ?? false;
    final corrected = !usesOffset
        ? (
            altitude: rawPosition.altitudeDeg.clamp(-90.0, 90.0).toDouble(),
            azimuth: normalizeDegrees360(rawPosition.azimuthDeg),
          )
        : correctionService.applyCorrection(
            targetAltitude: rawPosition.altitudeDeg,
            targetAzimuth: rawPosition.azimuthDeg,
            calibration: correction!,
          );

    return AstronomicalGotoCommand(
      object: object,
      rawPosition: rawPosition,
      initialAlignment: savedInitialAlignment,
      correctionCalibration: correction,
      finalAltitude: corrected.altitude,
      finalAzimuth: corrected.azimuth,
    );
  }

  Future<AstronomicalGotoCommand> prepareCommand(CelestialObject object) async {
    final connectionSession = AlignmentSession.token;
    if (!observerDataProvider.current().isLive) {
      throw StateError(
        'Activa Usar hora actual en Configuración antes de apuntar.',
      );
    }
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

    final initialAlignment = await loadInitialAlignment();
    final correctionCalibration = await loadCorrectionCalibration();
    if (connectionSession != AlignmentSession.token) {
      throw StateError('La conexión cambió. Repite la alineación.');
    }
    debugPrint(
      '[AstronomicalGoTo] Initial alignment found: ${initialAlignment != null}',
    );
    debugPrint(
      '[AstronomicalGoTo] Correction found: ${correctionCalibration != null}',
    );
    if (initialAlignment == null) {
      throw StateError(
        'Antes de usar GOTO debes realizar la alineación inicial del telescopio con una estrella reconocible.',
      );
    }
    debugPrint(
      '[AstronomicalGoTo] Correction Offset Alt/Az: '
      '${(correctionCalibration?.altitudeOffset ?? 0).toStringAsFixed(4)} / '
      '${(correctionCalibration?.azimuthOffset ?? 0).toStringAsFixed(4)}',
    );

    final command = buildCommand(
      object: object,
      rawPosition: rawPosition,
      initialAlignment: initialAlignment,
      correctionCalibration: correctionCalibration,
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
    sunGuard?.ensureSafe(
      rawPosition.altitudeDeg,
      rawPosition.azimuthDeg,
      what: object.name,
      at: rawPosition.computedAt,
    );
  }

  void _ensureInitialAligned(CalibrationResult? initialAlignment) {
    if (initialAlignment == null) {
      throw StateError(
        'Antes de usar GOTO debes realizar la alineación inicial del telescopio con una estrella reconocible.',
      );
    }
  }

  bool _isSun(CelestialObject object) {
    return object is SolarSystemBody && object.isSun;
  }
}
