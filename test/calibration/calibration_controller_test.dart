import 'dart:async';

import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/services/alignment_session.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/data/calibration_repository.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/data/calibration_storage.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/calibration_flow_step.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/calibration_method.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/calibration_status.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/correction_calibration_status.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/initial_alignment_status.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/services/astronomy_position_service.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/services/calibration_service.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/services/pointing_correction_service.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/presentation/controllers/calibration_controller.dart';
import 'package:astroprintedlogicincludedgeoengine/features/catalog/data/repository/celestial_catalog_repository.dart';
import 'package:astroprintedlogicincludedgeoengine/features/catalog/domain/models/celestial_object.dart';
import 'package:astroprintedlogicincludedgeoengine/features/observation/domain/models/alt_az_result.dart';
import 'package:astroprintedlogicincludedgeoengine/features/observation/domain/models/observer_data.dart';
import 'package:astroprintedlogicincludedgeoengine/features/observation/domain/services/observer_data_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('manual nudge step exceeds nominal motor half-step', () {
    expect(
      CalibrationController.fineStepDegrees,
      greaterThan(CalibrationController.nominalMotorStepDegrees),
    );
  });

  test('detects when there is no visible reference star', () async {
    final controller = _controller(_position(10, 120));
    addTearDown(controller.dispose);

    await controller.loadSavedCalibration();
    controller.startMethod(CalibrationMethod.oneStar);

    expect(controller.flowStep, CalibrationFlowStep.selectingObject);
    expect(controller.errorMessage, contains('No hay estrellas'));
    expect(controller.errorMessage, contains('estrella reconocible sobre 15'));
  });

  test(
    'selecting a star sends an approximate GOTO, then waits for centering',
    () async {
      final controller = _controller(_position(45, 120));
      addTearDown(controller.dispose);
      final gotos = <List<double>>[];

      await controller.loadSavedCalibration();
      controller.startMethod(CalibrationMethod.oneStar);
      await controller.selectStar(controller.calibrationStarOptions.first);

      expect(controller.flowStep, CalibrationFlowStep.movingToTarget);
      expect(controller.targetPosition?.altitudeDeg, 45);

      await controller.sendGotoToReference(
        (altitude, azimuth) async => gotos.add([altitude, azimuth]),
      );

      expect(gotos, [
        [45.0, 120.0],
      ]);
      expect(controller.flowStep, CalibrationFlowStep.waitingUserCentering);
      expect(controller.status, CalibrationStatus.waitingForManualCentering);
      expect(controller.selectedStarGuide, isNotEmpty);
    },
  );

  test('manual nudge sends relative movement without GoTo target', () async {
    final controller = _controller(_position(45, 120));
    addTearDown(controller.dispose);
    final sent = <List<double>>[];

    await _selectInitialStar(controller);
    await controller.nudge(CalibrationNudgeDirection.right, (
      deltaAltitude,
      deltaAzimuth,
    ) async {
      sent.add([deltaAltitude, deltaAzimuth]);
    });

    expect(sent, [
      [0.0, CalibrationController.fineStepDegrees],
    ]);
    expect(controller.adjustedAltitude, 45);
    expect(
      controller.adjustedAzimuth,
      120 + CalibrationController.fineStepDegrees,
    );
  });

  test('manual direct movement sends the absolute position', () async {
    final controller = _controller(_position(45, 120));
    addTearDown(controller.dispose);
    final nudges = <List<double>>[];
    final gotos = <List<double>>[];

    await _selectInitialStar(controller);
    await controller.nudge(CalibrationNudgeDirection.right, (
      deltaAltitude,
      deltaAzimuth,
    ) async {
      nudges.add([deltaAltitude, deltaAzimuth]);
    });
    await controller.moveToAdjustedPosition(
      altitude: 5,
      azimuth: 120,
      sendAbsoluteMove: (altitude, azimuth) async {
        gotos.add([altitude, azimuth]);
      },
    );

    expect(nudges, [
      [0.0, CalibrationController.fineStepDegrees],
    ]);
    expect(gotos, [
      [5.0, 120.0],
    ]);
    expect(controller.adjustedAltitude, 5);
    expect(controller.adjustedAzimuth, 120);
  });

  test(
    'initial alignment centers from where the approximate GOTO stopped',
    () async {
      // The heavy telescope stalled at 21 / 243 on its way to the star.
      final controller = _controller(
        _position(45, 120),
        motorPosition: () => (altitude: 21.0, azimuth: 243.0),
      );
      addTearDown(controller.dispose);
      await _selectInitialStar(controller);

      expect(controller.adjustedAltitude, 21);
      expect(controller.adjustedAzimuth, 243);
      expect(controller.flowStep, CalibrationFlowStep.waitingUserCentering);
    },
  );

  test('a failed approximate GOTO still lets the user center by hand', () async {
    final controller = _controller(_position(45, 120));
    addTearDown(controller.dispose);

    await controller.loadSavedCalibration();
    controller.startInitialAlignment();
    await controller.selectStar(controller.calibrationStarOptions.first);
    await controller.sendGotoToReference(
      (_, __) async => throw StateError('El ESP32 dejó de responder'),
    );

    expect(controller.flowStep, CalibrationFlowStep.waitingUserCentering);
    expect(controller.errorMessage, contains('GOTO'));
  });

  test('stopping the approximate GOTO returns to the star list', () async {
    final controller = _controller(_position(45, 120));
    addTearDown(controller.dispose);

    await controller.loadSavedCalibration();
    controller.startInitialAlignment();
    await controller.selectStar(controller.calibrationStarOptions.first);
    final moving = Completer<void>();
    final goto = controller.sendGotoToReference((_, __) => moving.future);
    await controller.abortReferenceGoto(() async {
      moving.completeError(StateError('Movimiento cancelado por STOP'));
    });
    await goto;

    expect(controller.flowStep, CalibrationFlowStep.selectingObject);
    expect(controller.selectedStar, isNull);
    expect(controller.session, isNotNull);
  });

  test('confirming a correction reads a fresh encoder position', () async {
    var position = (altitude: 45.0, azimuth: 120.0);
    final controller = _controller(
      _position(45, 120),
      motorPosition: () => position,
    );
    addTearDown(controller.dispose);
    await _selectInitialStar(controller);
    await controller.confirmCenteredReference(
      setInitialPosition: (_, __) async {},
    );
    controller.startCorrectionMethod(CalibrationMethod.oneStar);
    await controller.selectStar(controller.calibrationStarOptions.first);
    await controller.sendGotoToReference((_, __) async {});

    var refreshed = 0;
    await controller.confirmCenteredReference(
      refreshPosition: () async {
        refreshed++;
        // The heavy telescope settled a bit after the last move.
        position = (altitude: 45.4, azimuth: 120.0);
      },
    );
    expect(refreshed, 1);
    expect(
      controller.correctionCalibrationResult!.altitudeOffset,
      closeTo(0.4, 0.000001),
    );
  });

  test(
    'confirming centered star sends SET_POSITION and saves calibration',
    () async {
      final controller = _controller(_position(63.1548, 30.4972));
      addTearDown(controller.dispose);
      double? sentAltitude;
      double? sentAzimuth;

      await _selectInitialStar(controller);
      await controller.confirmCenteredReference(
        setInitialPosition: (altitude, azimuth) async {
          sentAltitude = altitude;
          sentAzimuth = azimuth;
        },
      );

      expect(sentAltitude, 63.1548);
      expect(sentAzimuth, 30.4972);
      expect(controller.flowStep, CalibrationFlowStep.idle);
      expect(controller.session, isNull);
      expect(controller.savedResult?.status, CalibrationStatus.calibrated);
      expect(controller.initialAlignmentStatus, InitialAlignmentStatus.aligned);
      expect(controller.isInitialAligned, isTrue);
      expect(controller.initialAlignmentResult, isNotNull);
      expect(
        controller.correctionCalibrationStatus,
        CorrectionCalibrationStatus.notCalibrated,
      );
      expect(controller.savedResult?.points, hasLength(1));
      final point = controller.savedResult!.points.single;
      expect(point.motorAltitudeAtCalibration, 63.1548);
      expect(point.motorAzimuthAtCalibration, 30.4972);
      expect(point.referenceRaJ2000Hours, isNotNull);
    },
  );

  test('blocks correction modes before initial alignment', () async {
    final controller = _controller(_position(45, 120));
    addTearDown(controller.dispose);

    await controller.loadSavedCalibration();
    controller.startCorrectionMethod(CalibrationMethod.twoStars);

    expect(controller.flowStep, CalibrationFlowStep.idle);
    expect(controller.hasCorrectionCalibration, isFalse);
    expect(controller.errorMessage, contains('alineación inicial'));
  });

  test(
    'one-star correction runs after initial alignment and stores offset',
    () async {
      final controller = _controller(_position(45, 120));
      addTearDown(controller.dispose);
      final gotos = <List<double>>[];

      await _selectInitialStar(controller);
      await controller.confirmCenteredReference(
        setInitialPosition: (_, __) async {},
      );

      controller.startCorrectionMethod(CalibrationMethod.oneStar);
      await controller.selectStar(controller.calibrationStarOptions.first);

      expect(controller.flowStep, CalibrationFlowStep.movingToTarget);
      await controller.sendGotoToReference(
        (altitude, azimuth) async => gotos.add([altitude, azimuth]),
      );
      await controller.nudge(
        CalibrationNudgeDirection.right,
        (deltaAltitude, deltaAzimuth) async {},
      );
      await controller.confirmCenteredReference();

      expect(gotos, [
        [45, 120],
      ]);
      expect(controller.flowStep, CalibrationFlowStep.completed);
      expect(controller.hasCorrectionCalibration, isTrue);
      expect(
        controller.correctionCalibrationStatus,
        CorrectionCalibrationStatus.calibrated,
      );
      expect(
        controller.correctionCalibrationResult?.azimuthOffset,
        CalibrationController.fineStepDegrees,
      );
    },
  );
  test('failed SET_POSITION never saves an alignment', () async {
    final controller = _controller(_position(45, 120));
    addTearDown(controller.dispose);
    await _selectInitialStar(controller);
    await controller.confirmCenteredReference(
      setInitialPosition: (_, __) async =>
          throw StateError('ERROR: motores activos'),
    );
    expect(controller.isInitialAligned, isFalse);
    expect(controller.flowStep, CalibrationFlowStep.failed);
    expect(await CalibrationStorage().loadInitialAlignmentResult(), isNull);
  });

  test(
    'disconnect while SET_POSITION is pending invalidates its late reply',
    () async {
      final controller = _controller(_position(45, 120));
      addTearDown(controller.dispose);
      await _selectInitialStar(controller);
      final acknowledgement = Completer<void>();
      final confirming = controller.confirmCenteredReference(
        setInitialPosition: (_, __) => acknowledgement.future,
      );
      AlignmentSession.invalidate();
      acknowledgement.complete();
      await confirming;
      expect(controller.isInitialAligned, isFalse);
      expect(await CalibrationStorage().loadInitialAlignmentResult(), isNull);
    },
  );

  test('reconnection clears an already loaded alignment', () async {
    final controller = _controller(_position(45, 120));
    addTearDown(controller.dispose);
    await _selectInitialStar(controller);
    await controller.confirmCenteredReference(
      setInitialPosition: (_, __) async {},
    );
    expect(controller.isInitialAligned, isTrue);
    AlignmentSession.invalidate();
    expect(controller.isInitialAligned, isFalse);
    expect(await CalibrationStorage().loadInitialAlignmentResult(), isNull);
  });

  test('partial failed nudge cannot be confirmed as a correction', () async {
    final controller = _controller(_position(45, 120));
    addTearDown(controller.dispose);
    await _selectInitialStar(controller);
    await controller.confirmCenteredReference(
      setInitialPosition: (_, __) async {},
    );
    controller.startCorrectionMethod(CalibrationMethod.oneStar);
    await controller.selectStar(controller.calibrationStarOptions.first);
    await controller.sendGotoToReference((_, __) async {});
    await controller.nudge(
      CalibrationNudgeDirection.right,
      (_, __) async => throw StateError('movimiento cancelado por STOP'),
    );
    await controller.confirmCenteredReference();
    expect(controller.hasCorrectionCalibration, isFalse);
    expect(controller.flowStep, CalibrationFlowStep.failed);
  });

  test(
    'correction uses reported motor steps and waits for movement completion',
    () async {
      var position = (altitude: 45.0, azimuth: 120.0);
      final controller = _controller(
        _position(45, 120),
        motorPosition: () => position,
      );
      addTearDown(controller.dispose);
      await _selectInitialStar(controller);
      await controller.confirmCenteredReference(
        setInitialPosition: (_, __) async {},
      );
      controller.startCorrectionMethod(CalibrationMethod.oneStar);
      await controller.selectStar(controller.calibrationStarOptions.first);
      final moving = Completer<void>();
      final goto = controller.sendGotoToReference((_, __) => moving.future);
      await controller.confirmCenteredReference();
      expect(controller.hasCorrectionCalibration, isFalse);
      moving.complete();
      await goto;
      position = (altitude: 45.0, azimuth: 120.966797);
      await controller.nudge(CalibrationNudgeDirection.right, (_, __) async {});
      await controller.confirmCenteredReference();
      expect(
        controller.correctionCalibrationResult!.azimuthOffset,
        closeTo(0.966797, 0.000001),
      );
    },
  );

  test('absolute manual adjustment normalizes the azimuth', () async {
    final controller = _controller(
      _position(45, 120),
      motorPosition: () => (altitude: 0.0, azimuth: 359.0),
    );
    addTearDown(controller.dispose);
    await _selectInitialStar(controller);
    double? sentAzimuth;
    await controller.moveToAdjustedPosition(
      altitude: 0,
      azimuth: 361,
      sendAbsoluteMove: (_, az) async {
        sentAzimuth = az;
      },
    );
    expect(sentAzimuth, 1.0);
  });

  test('planning time cannot establish a physical alignment', () async {
    final controller = _controller(_position(45, 120), isLive: false);
    addTearDown(controller.dispose);
    await _selectInitialStar(controller);
    var sent = false;
    await controller.confirmCenteredReference(
      setInitialPosition: (_, __) async {
        sent = true;
      },
    );
    expect(sent, isFalse);
    expect(controller.isInitialAligned, isFalse);
    expect(controller.errorMessage, contains('hora actual'));
  });
}

/// Elige la primera estrella y completa el GOTO aproximado.
Future<void> _selectInitialStar(CalibrationController controller) async {
  await controller.loadSavedCalibration();
  controller.startInitialAlignment();
  await controller.selectStar(controller.calibrationStarOptions.first);
  await controller.sendGotoToReference((_, __) async {});
}

CalibrationController _controller(
  AltAzResult position, {
  bool isLive = true,
  ({double altitude, double azimuth})? Function()? motorPosition,
}) {
  return CalibrationController(
    catalogRepository: CelestialCatalogRepository(),
    calibrationRepository: CalibrationRepository(storage: CalibrationStorage()),
    astronomyPositionService: _FixedAstronomyPositionService(position),
    calibrationService: const CalibrationService(
      correctionService: PointingCorrectionService(),
    ),
    observerDataProvider: _FakeObserverDataProvider(isLive: isLive),
    motorPositionProvider: motorPosition,
  );
}

AltAzResult _position(double altitude, double azimuth) {
  return AltAzResult(
    altitudeDeg: altitude,
    azimuthDeg: azimuth,
    altitudeRawDeg: altitude,
    azimuthRawDeg: azimuth,
    computedAt: DateTime.utc(2026),
  );
}

class _FixedAstronomyPositionService extends AstronomyPositionService {
  final AltAzResult position;

  const _FixedAstronomyPositionService(this.position);

  @override
  AltAzResult calculateForStar({
    required CalibrationStar star,
    required ObserverData observer,
  }) {
    return position;
  }
}

class _FakeObserverDataProvider implements ObserverDataProvider {
  final bool isLive;
  const _FakeObserverDataProvider({this.isLive = true});

  @override
  ObserverData current() {
    return ObserverData(
      latDeg: -33,
      lonDeg: -70,
      heightMeters: 0,
      utc: DateTime.utc(2026),
      isLive: isLive,
    );
  }
}
