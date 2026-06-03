import 'package:astroprintedlogicincludedgeoengine/features/calibration/data/calibration_repository.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/data/calibration_storage.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/calibration_method.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/calibration_result.dart';
import 'package:astroprintedlogicincludedgeoengine/features/catalog/application/astronomical_goto_service.dart';
import 'package:astroprintedlogicincludedgeoengine/features/catalog/domain/models/celestial_object.dart';
import 'package:astroprintedlogicincludedgeoengine/features/observation/domain/models/alt_az_result.dart';
import 'package:astroprintedlogicincludedgeoengine/features/observation/domain/models/observer_data.dart';
import 'package:astroprintedlogicincludedgeoengine/features/observation/domain/services/observer_data_provider.dart';
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

  test('sends raw Alt/Az when there is no saved correction', () async {
    final service = _service(repository, _position(20, 30));
    double? sentAlt;
    double? sentAz;

    final command = await service.sendGoto(
      object: _object(),
      send: (altitude, azimuth) async {
        sentAlt = altitude;
        sentAz = azimuth;
      },
    );

    expect(command.usedCorrection, isFalse);
    expect(sentAlt, 20);
    expect(sentAz, 30);
  });

  test('applies saved correction and normalizes azimuth', () async {
    await repository.saveCurrentResult(
      CalibrationResult(
        altitudeOffset: 2,
        azimuthOffset: -40,
        method: CalibrationMethod.oneStar,
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
  const _FakeObserverDataProvider();

  @override
  ObserverData current() {
    return ObserverData(
      latDeg: -33.0,
      lonDeg: -70.0,
      heightMeters: 0,
      utc: DateTime.utc(2026),
    );
  }
}
