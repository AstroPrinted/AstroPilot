import 'package:astroprintedlogicincludedgeoengine/features/calibration/data/calibration_repository.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/data/calibration_storage.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/calibration_flow_step.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/calibration_method.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/calibration_status.dart';
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

  test('detects when there is no visible reference star', () async {
    final controller = _controller(_position(10, 120));
    addTearDown(controller.dispose);

    await controller.loadSavedCalibration();
    controller.startMethod(CalibrationMethod.oneStar);

    expect(controller.flowStep, CalibrationFlowStep.selectingObject);
    expect(controller.errorMessage, contains('No hay estrellas'));
    expect(controller.errorMessage, contains('una estrella sobre 15'));
  });

  test('selects a visible star and waits for manual centering', () async {
    final controller = _controller(_position(45, 120));
    addTearDown(controller.dispose);

    await controller.loadSavedCalibration();
    controller.startMethod(CalibrationMethod.oneStar);
    await controller.selectStar(controller.calibrationStarOptions.first);

    expect(controller.flowStep, CalibrationFlowStep.waitingUserCentering);
    expect(controller.status, CalibrationStatus.waitingForManualCentering);
    expect(controller.targetPosition?.altitudeDeg, 45);
    expect(controller.selectedStarGuide, isNotEmpty);
  });

  test('manual nudge sends relative movement without GoTo target', () async {
    final controller = _controller(_position(45, 120));
    addTearDown(controller.dispose);
    final sent = <List<double>>[];

    await controller.loadSavedCalibration();
    controller.startMethod(CalibrationMethod.oneStar);
    await controller.selectStar(controller.calibrationStarOptions.first);
    await controller.nudge(CalibrationNudgeDirection.right, (
      deltaAltitude,
      deltaAzimuth,
    ) async {
      sent.add([deltaAltitude, deltaAzimuth]);
    });

    expect(sent, [
      [0.0, CalibrationController.fineStepDegrees],
    ]);
    expect(controller.adjustedAltitude, 0);
    expect(controller.adjustedAzimuth, CalibrationController.fineStepDegrees);
  });

  test(
    'manual direct movement sends only the remaining relative movement',
    () async {
      final controller = _controller(_position(45, 120));
      addTearDown(controller.dispose);
      final sent = <List<double>>[];

      await controller.loadSavedCalibration();
      controller.startMethod(CalibrationMethod.oneStar);
      await controller.selectStar(controller.calibrationStarOptions.first);
      await controller.nudge(CalibrationNudgeDirection.right, (
        deltaAltitude,
        deltaAzimuth,
      ) async {
        sent.add([deltaAltitude, deltaAzimuth]);
      });
      await controller.moveToAdjustedPosition(
        altitude: 5,
        azimuth: 120,
        sendManualMove: (deltaAltitude, deltaAzimuth) async {
          sent.add([deltaAltitude, deltaAzimuth]);
        },
      );

      expect(sent, [
        [0.0, CalibrationController.fineStepDegrees],
        [5.0, 120 - CalibrationController.fineStepDegrees],
      ]);
      expect(controller.adjustedAltitude, 5);
      expect(controller.adjustedAzimuth, 120);
    },
  );

  test(
    'confirming centered star sends SET_POSITION and saves calibration',
    () async {
      final controller = _controller(_position(63.1548, 30.4972));
      addTearDown(controller.dispose);
      double? sentAltitude;
      double? sentAzimuth;

      await controller.loadSavedCalibration();
      controller.startMethod(CalibrationMethod.oneStar);
      await controller.selectStar(controller.calibrationStarOptions.first);
      await controller.confirmCenteredReference((altitude, azimuth) async {
        sentAltitude = altitude;
        sentAzimuth = azimuth;
      });

      expect(sentAltitude, 63.1548);
      expect(sentAzimuth, 30.4972);
      expect(controller.flowStep, CalibrationFlowStep.completed);
      expect(controller.savedResult?.status, CalibrationStatus.calibrated);
      expect(controller.savedResult?.points, hasLength(1));
      final point = controller.savedResult!.points.single;
      expect(point.motorAltitudeAtCalibration, 63.1548);
      expect(point.motorAzimuthAtCalibration, 30.4972);
      expect(point.referenceRaJ2000Hours, isNotNull);
    },
  );
}

CalibrationController _controller(AltAzResult position) {
  return CalibrationController(
    catalogRepository: CelestialCatalogRepository(),
    calibrationRepository: CalibrationRepository(storage: CalibrationStorage()),
    astronomyPositionService: _FixedAstronomyPositionService(position),
    calibrationService: const CalibrationService(
      correctionService: PointingCorrectionService(),
    ),
    observerDataProvider: const _FakeObserverDataProvider(),
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
  const _FakeObserverDataProvider();

  @override
  ObserverData current() {
    return ObserverData(
      latDeg: -33,
      lonDeg: -70,
      heightMeters: 0,
      utc: DateTime.utc(2026),
    );
  }
}
