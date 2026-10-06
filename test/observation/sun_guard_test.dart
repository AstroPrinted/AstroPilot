import 'package:astroprintedlogicincludedgeoengine/features/catalog/application/visible_objects_service.dart';
import 'package:astroprintedlogicincludedgeoengine/features/catalog/data/repository/celestial_catalog_repository.dart';
import 'package:astroprintedlogicincludedgeoengine/features/catalog/domain/models/celestial_object.dart';
import 'package:astroprintedlogicincludedgeoengine/features/observation/domain/models/alt_az_result.dart';
import 'package:astroprintedlogicincludedgeoengine/features/observation/domain/models/observer_data.dart';
import 'package:astroprintedlogicincludedgeoengine/features/observation/domain/services/observer_data_provider.dart';
import 'package:astroprintedlogicincludedgeoengine/features/observation/domain/services/sun_guard.dart';
import 'package:astroprintedlogicincludedgeoengine/features/oe4_control/domain/motor_command_service.dart';
import 'package:astroprintedlogicincludedgeoengine/features/oe4_control/presentation/controllers/oe4_control_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SunGuard', () {
    test('blocks targets inside the exclusion radius around the Sun', () {
      final guard = _guard(altitude: 40, azimuth: 30);

      expect(guard.isNearSun(40, 30), isTrue);
      expect(guard.isNearSun(50, 30), isTrue);
      expect(guard.isNearSun(56, 30), isFalse);
      // 30° of azimuth at 40° of altitude are ~23° on the sky.
      expect(guard.isNearSun(40, 60), isFalse);
      expect(guard.isNearSun(40, 45), isTrue);
    });

    test('measures the separation across north', () {
      final guard = _guard(altitude: 20, azimuth: 355);

      expect(guard.isNearSun(20, 5), isTrue);
      expect(guard.isNearSun(20, 175), isFalse);
    });

    test('allows everything once the Sun is below the horizon', () {
      final guard = _guard(altitude: -5, azimuth: 250);

      expect(guard.isNearSun(1, 250), isFalse);
      expect(() => guard.ensureSafe(1, 250), returnsNormally);
    });

    test('still blocks while the Sun sits on the horizon', () {
      final guard = _guard(altitude: -1, azimuth: 250);

      expect(guard.isNearSun(5, 250), isTrue);
    });

    test('ensureSafe names the target and never shows the Sun position', () {
      final guard = _guard(altitude: 40, azimuth: 30);

      expect(
        () => guard.ensureSafe(41, 31, what: 'Mercurio'),
        throwsA(
          isA<SunSafetyError>().having(
            (error) => error.message,
            'message',
            allOf(contains('Mercurio'), contains('15°'), isNot(contains('40'))),
          ),
        ),
      );
    });

    test('uses the real Sun: Santiago at the December solstice', () {
      // Local solar noon: the Sun culminates in the north at ~80° altitude.
      final noon = SunGuard(
        observerDataProvider: const _Santiago(),
        clock: () => DateTime.utc(2026, 12, 21, 16, 41),
      );
      expect(noon.isNearSun(80, 0), isTrue);
      expect(noon.isNearSun(30, 180), isFalse);

      final midnight = SunGuard(
        observerDataProvider: const _Santiago(),
        clock: () => DateTime.utc(2026, 12, 21, 4, 41),
      );
      expect(midnight.isNearSun(80, 0), isFalse);
      expect(midnight.isNearSun(0, 180), isFalse);
    });

    test('an explicit instant overrides the clock', () {
      final guard = SunGuard(
        observerDataProvider: const _Santiago(),
        clock: () => DateTime.utc(2026, 12, 21, 4, 41),
      );

      expect(
        guard.isNearSun(80, 0, at: DateTime.utc(2026, 12, 21, 16, 41)),
        isTrue,
      );
    });
  });

  group('Oe4ControlController', () {
    test('never sends a GOTO that ends near the Sun', () async {
      final service = _RecordingService();
      final controller = Oe4ControlController(
        service,
        sunGuard: _guard(altitude: 40, azimuth: 30),
      );
      addTearDown(controller.dispose);

      await controller.moveTo('test', alt: 42, az: 28);
      expect(service.sent, isEmpty);
      expect(controller.errorMessage, contains('Sol'));

      await expectLater(
        controller.moveTo('test', alt: 42, az: 28, throwOnError: true),
        throwsA(isA<SunSafetyError>()),
      );
      expect(service.sent, isEmpty);

      await controller.moveTo('test', alt: 10, az: 200);
      expect(service.sent, ['GOTO 10.0 200.0']);
      expect(controller.errorMessage, isNull);
    });

    test('blocks HOME and TEST_ROUTINE when they pass near the Sun', () async {
      final service = _RecordingService();
      // The routine goes through alt 0 / az 45.
      final controller = Oe4ControlController(
        service,
        sunGuard: _guard(altitude: 5, azimuth: 50),
      );
      addTearDown(controller.dispose);

      await controller.sendTestRoutine('test');
      expect(service.sent, isEmpty);
      expect(controller.errorMessage, contains('Sol'));

      await controller.sendHome('test');
      expect(service.sent, ['HOME']);
    });

    test('blocks HOME when the Sun is at the home position', () async {
      final service = _RecordingService();
      final controller = Oe4ControlController(
        service,
        sunGuard: _guard(altitude: 8, azimuth: 355),
      );
      addTearDown(controller.dispose);

      await controller.sendHome('test');

      expect(service.sent, isEmpty);
      expect(controller.errorMessage, contains('Sol'));
    });
  });

  test('catalog marks visible objects that sit near the Sun', () async {
    final service = VisibleObjectsService(
      catalogRepository: CelestialCatalogRepository(),
      observerDataProvider: const _Santiago(),
      objectsProvider: (_) async => [_object('near'), _object('far')],
      positionResolver: (object, _) =>
          object.id == 'near' ? _position(38, 33) : _position(38, 200),
      sunGuard: _guard(altitude: 40, azimuth: 30),
    );

    final results = await service.loadObjects(visibleOnly: true);
    final near = results.singleWhere((item) => item.object.id == 'near');
    final far = results.singleWhere((item) => item.object.id == 'far');

    expect(near.isNearSun, isTrue);
    expect(near.blockedReason, contains('Sol'));
    expect(far.isNearSun, isFalse);
    expect(far.blockedReason, isNull);
  });
}

SunGuard _guard({required double altitude, required double azimuth}) {
  return SunGuard(
    observerDataProvider: const _Santiago(),
    sunPositionResolver: (_, __) => (altitude: altitude, azimuth: azimuth),
  );
}

DeepSkyObject _object(String id) {
  return DeepSkyObject(
    id: id,
    name: id,
    objectType: 'Test',
    constellations: const ['Test'],
    raJ2000Hours: 0,
    decJ2000Degrees: 0,
    catalogs: const ['TEST'],
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

class _Santiago implements ObserverDataProvider {
  const _Santiago();

  @override
  ObserverData current() {
    return ObserverData(
      latDeg: -33.43,
      lonDeg: -70.68,
      heightMeters: 520,
      utc: DateTime.utc(2026),
    );
  }
}

class _RecordingService extends MotorCommandService {
  final sent = <String>[];

  @override
  Future<String> sendGotoCommand(
    String deviceId, {
    required double alt,
    required double az,
  }) async {
    sent.add('GOTO $alt $az');
    return 'GOTO';
  }

  @override
  Future<String> sendHomeCommand(String deviceId) async {
    sent.add('HOME');
    return 'HOME';
  }

  @override
  Future<String> sendTestRoutineCommand(String deviceId) async {
    sent.add('TEST_ROUTINE');
    return 'TEST_ROUTINE';
  }
}
