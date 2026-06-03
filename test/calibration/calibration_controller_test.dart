import 'package:astroprintedlogicincludedgeoengine/features/calibration/data/calibration_repository.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/data/calibration_storage.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/calibration_flow_step.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/calibration_method.dart';
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

  test('detects when there are not enough visible stars', () async {
    final controller = _controller(_position(10, 120));
    addTearDown(controller.dispose);

    await controller.loadSavedCalibration();
    controller.startMethod(CalibrationMethod.threeStars);
    controller.continueAfterHome();

    expect(controller.flowStep, CalibrationFlowStep.selectingObject);
    expect(controller.errorMessage, contains('No hay suficientes'));
    expect(controller.errorMessage, contains('3 estrellas'));
    expect(controller.errorMessage, contains('3 estrellas sobre 15'));
  });
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
