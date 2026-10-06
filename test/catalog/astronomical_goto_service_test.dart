import 'package:astroprintedlogicincludedgeoengine/features/calibration/data/calibration_repository.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/data/calibration_storage.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/calibration_method.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/calibration_result.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/calibration_stage.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/calibration_status.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/correction_model.dart';
import 'package:astroprintedlogicincludedgeoengine/features/catalog/application/astronomical_goto_service.dart';
import 'package:astroprintedlogicincludedgeoengine/features/catalog/domain/models/celestial_object.dart';
import 'package:astroprintedlogicincludedgeoengine/features/observation/domain/models/alt_az_result.dart';
import 'package:astroprintedlogicincludedgeoengine/features/observation/domain/models/observer_data.dart';
import 'package:astroprintedlogicincludedgeoengine/features/observation/domain/services/observer_data_provider.dart';
import 'package:astroprintedlogicincludedgeoengine/features/observation/domain/services/sun_guard.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoengine/geoengine.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CalibrationRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = CalibrationRepository(storage: CalibrationStorage());
  });

  test('blocks GoTo when the telescope is not initially aligned', () async {
    final service = _service(repository, _position(20, 30));
    var sent = false;

    expect(
      () => service.sendGoto(
        object: _object(),
        send: (_, __) async => sent = true,
      ),
      throwsA(isA<StateError>()),
    );
    expect(sent, isFalse);
  });

  test('uses initial alignment without applying correction offset', () async {
    await repository.saveInitialAlignmentResult(
      CalibrationResult(
        altitudeOffset: 0,
        azimuthOffset: 0,
        stage: CalibrationStage.initialAlignment,
        correctionModel: CorrectionModel.none,
        method: CalibrationMethod.oneStar,
        status: CalibrationStatus.calibrated,
        points: const [],
        createdAt: DateTime.utc(2026),
      ),
    );

    final service = _service(repository, _position(20, 10));
    double? sentAlt;
    double? sentAz;

    final command = await service.sendGoto(
      object: _object(),
      send: (altitude, azimuth) async {
        sentAlt = altitude;
        sentAz = azimuth;
      },
    );

    expect(command.hasCalibration, isTrue);
    expect(command.usedCorrection, isFalse);
    expect(sentAlt, 20);
    expect(sentAz, 10);
  });

  test('applies correction calibration and normalizes azimuth', () async {
    await repository.saveInitialAlignmentResult(
      CalibrationResult(
        altitudeOffset: 0,
        azimuthOffset: 0,
        stage: CalibrationStage.initialAlignment,
        correctionModel: CorrectionModel.none,
        method: CalibrationMethod.oneStar,
        status: CalibrationStatus.calibrated,
        points: const [],
        createdAt: DateTime.utc(2026),
      ),
    );
    await repository.saveCorrectionCalibrationResult(
      CalibrationResult(
        altitudeOffset: 2,
        azimuthOffset: -40,
        stage: CalibrationStage.correctionCalibration,
        correctionModel: CorrectionModel.twoStarCorrection,
        method: CalibrationMethod.twoStars,
        status: CalibrationStatus.calibratedTwoStars,
        points: const [],
        createdAt: DateTime.utc(2026),
      ),
    );

    final service = _service(repository, _position(20, 10));
    double? sentAlt;
    double? sentAz;

    final command = await service.sendGoto(
      object: _object(),
      send: (altitude, azimuth) async {
        sentAlt = altitude;
        sentAz = azimuth;
      },
    );

    expect(command.usedCorrection, isTrue);
    expect(sentAlt, 22);
    expect(sentAz, 330);
  });

  test('blocks objects below horizon', () async {
    final service = _service(repository, _position(-0.1, 30));
    var sent = false;

    expect(
      () => service.sendGoto(
        object: _object(),
        send: (_, __) async => sent = true,
      ),
      throwsA(isA<StateError>()),
    );
    expect(sent, isFalse);
  });

  test(
    'planning time permits preview but never sends a physical GoTo',
    () async {
      final service = AstronomicalGotoService(
        observerDataProvider: const _FakeObserverDataProvider(isLive: false),
        calibrationRepository: repository,
        positionResolver: (_, __) => _position(30, 30),
      );
      expect(service.calculateCurrentPosition(_object()).altitudeDeg, 30);
      var sent = false;
      await expectLater(
        service.sendGoto(
          object: _object(),
          send: (_, __) async {
            sent = true;
          },
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('hora actual'),
          ),
        ),
      );
      expect(sent, isFalse);
    },
  );

  test('blocks GoTo to an object in front of or behind the Sun', () {
    final alignment = CalibrationResult(
      altitudeOffset: 0,
      azimuthOffset: 0,
      stage: CalibrationStage.initialAlignment,
      correctionModel: CorrectionModel.none,
      method: CalibrationMethod.oneStar,
      status: CalibrationStatus.calibrated,
      points: const [],
      createdAt: DateTime.utc(2026),
    );
    AstronomicalGotoService near(double sunAzimuth) => AstronomicalGotoService(
      observerDataProvider: const _FakeObserverDataProvider(),
      calibrationRepository: repository,
      sunGuard: SunGuard(
        observerDataProvider: const _FakeObserverDataProvider(),
        sunPositionResolver: (_, __) => (altitude: 32, azimuth: sunAzimuth),
      ),
    );

    expect(
      () => near(33).buildCommand(
        object: _object(),
        rawPosition: _position(30, 30),
        initialAlignment: alignment,
        correctionCalibration: null,
      ),
      throwsA(
        isA<SunSafetyError>().having(
          (error) => error.message,
          'message',
          contains('M42'),
        ),
      ),
    );
    expect(
      near(200)
          .buildCommand(
            object: _object(),
            rawPosition: _position(30, 30),
            initialAlignment: alignment,
            correctionCalibration: null,
          )
          .finalAltitude,
      30,
    );
  });

  test('blocks solar GoTo', () async {
    final service = _service(repository, _position(30, 30));
    var sent = false;

    expect(
      () => service.sendGoto(
        object: const SolarSystemBody(
          id: 'solar_sun',
          name: 'Sol',
          geoengineBody: Body.Sun,
        ),
        send: (_, __) async => sent = true,
      ),
      throwsA(isA<StateError>()),
    );
    expect(sent, isFalse);
  });
}

AstronomicalGotoService _service(
  CalibrationRepository repository,
  AltAzResult position,
) {
  return AstronomicalGotoService(
    observerDataProvider: const _FakeObserverDataProvider(),
    calibrationRepository: repository,
    positionResolver: (_, __) => position,
  );
}

DeepSkyObject _object() {
  return const DeepSkyObject(
    id: 'm42',
    name: 'M42',
    objectType: 'Nebulosa',
    constellations: ['Orion'],
    raJ2000Hours: 5,
    decJ2000Degrees: -5,
    catalogs: ['M42'],
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

class _FakeObserverDataProvider implements ObserverDataProvider {
  final bool isLive;
  const _FakeObserverDataProvider({this.isLive = true});

  @override
  ObserverData current() {
    return ObserverData(
      latDeg: -33.0,
      lonDeg: -70.0,
      heightMeters: 0,
      utc: DateTime.utc(2026),
      isLive: isLive,
    );
  }
}
