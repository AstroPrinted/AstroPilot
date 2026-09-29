import 'dart:async';

import 'package:astroprintedlogicincludedgeoengine/features/calibration/data/calibration_repository.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/data/calibration_storage.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/calibration_method.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/calibration_result.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/calibration_stage.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/calibration_status.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/correction_model.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/services/alignment_session.dart';
import 'package:astroprintedlogicincludedgeoengine/features/catalog/application/astronomical_goto_service.dart';
import 'package:astroprintedlogicincludedgeoengine/features/catalog/domain/models/celestial_object.dart';
import 'package:astroprintedlogicincludedgeoengine/features/catalog/presentation/controllers/celestial_control_controller.dart';
import 'package:astroprintedlogicincludedgeoengine/features/observation/domain/models/alt_az_result.dart';
import 'package:astroprintedlogicincludedgeoengine/features/observation/domain/models/observer_data.dart';
import 'package:astroprintedlogicincludedgeoengine/features/observation/domain/services/observer_data_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CalibrationRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = CalibrationRepository(storage: CalibrationStorage());
  });

  testWidgets('live preview advances without tracking and stops on dispose', (
    tester,
  ) async {
    var position = _position(20, 30);
    var calculations = 0;
    final controller = CelestialControlController(
      object: _object(),
      gotoService: AstronomicalGotoService(
        observerDataProvider: const _FakeObserverDataProvider(),
        calibrationRepository: repository,
        positionResolver: (_, __) {
          calculations++;
          return position;
        },
      ),
    );
    controller.startLivePreview();
    controller.startLivePreview(); // Starting twice must not create two timers.
    await tester.pump();
    expect(controller.currentPosition?.altitudeDeg, 20);
    position = _position(21, 31);
    await tester.pump(const Duration(seconds: 1));
    expect(controller.currentPosition?.altitudeDeg, 21);
    expect(controller.currentPosition?.azimuthDeg, 31);
    expect(calculations, 2);
    expect(controller.isTracking, isFalse);
    expect(controller.lastSentCommand, isNull);
    controller.dispose();
    await tester.pump(const Duration(seconds: 20));
    expect(calculations, 2);
  });

  testWidgets('background preview preserves command errors and STOP history', (
    tester,
  ) async {
    final controller = _controller(repository, _position(20, 30));
    controller.startLivePreview();
    await tester.pump();
    await controller.sendStop(() async => throw StateError('STOP rechazado'));
    await tester.pump(const Duration(seconds: 1));
    expect(controller.errorMessage, 'STOP rechazado');
    expect(controller.statusMessage, 'STOP rechazado');
    await controller.sendStop(() async {});
    final sent = controller.lastSentCommand;
    await tester.pump(const Duration(seconds: 1));
    expect(controller.lastSentCommand, same(sent));
    expect(controller.statusMessage, 'STOP enviado. Tracking detenido.');
    controller.dispose();
  });

  test(
    'reference change invalidates local pointing and stops tracking',
    () async {
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
      final controller = _controller(repository, _position(20, 30));
      addTearDown(controller.dispose);
      await controller.sendInitialGoto((_, __) async {});
      await controller.startTracking((_, __) async {});
      AlignmentSession.invalidate();
      expect(controller.isTracking, isFalse);
      expect(controller.canFineTune, isFalse);
      expect(controller.savedCalibration, isNull);
      expect(controller.previewCommand, isNull);
    },
  );

  test(
    'fine tune moves from one-star calibrated target without applying offset',
    () async {
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
      final controller = _controller(repository, _position(20, 30));
      addTearDown(controller.dispose);
      final sent = <List<double>>[];

      await controller.sendInitialGoto(
        (altitude, azimuth) async => sent.add([altitude, azimuth]),
      );
      await controller.fineTune(
        CelestialFineDirection.right,
        (altitude, azimuth) async => sent.add([altitude, azimuth]),
      );

      expect(sent, hasLength(2));
      expect(sent[0], [20, 30]);
      expect(sent[1][0], 20);
      expect(sent[1][1], 30.25);
      expect(controller.lastSentCommand?.usedCorrection, isFalse);
    },
  );

  testWidgets(
    'live target changes without changing sent coordinates or fine tune origin',
    (tester) async {
      await tester.runAsync(
        () => repository.saveInitialAlignmentResult(
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
        ),
      );
      var position = _position(20, 30);
      final controller = CelestialControlController(
        object: _object(),
        gotoService: AstronomicalGotoService(
          observerDataProvider: const _FakeObserverDataProvider(),
          calibrationRepository: repository,
          positionResolver: (_, __) => position,
        ),
      );
      final sent = <List<double>>[];
      await tester.runAsync(
        () =>
            controller.sendInitialGoto((alt, az) async => sent.add([alt, az])),
      );
      final lastCommand = controller.lastSentCommand;
      controller.startLivePreview();
      await tester.pump();
      position = _position(25, 35);
      await tester.pump(const Duration(seconds: 1));
      expect(controller.currentPosition?.altitudeDeg, 25);
      expect(controller.previewCommand?.finalAltitude, 25);
      expect(controller.previewCommand?.finalAzimuth, 35);
      expect(controller.lastSentCommand, same(lastCommand));
      expect(controller.localAltitude, 20);
      expect(controller.localAzimuth, 30);
      expect(sent, [
        [20, 30],
      ]);
      await controller.fineTune(
        CelestialFineDirection.right,
        (alt, az) async => sent.add([alt, az]),
      );
      expect(sent.last, [20, 30.25]);
      controller.dispose();
    },
  );

  test('does not start tracking for an object below horizon', () async {
    final controller = _controller(repository, _position(-1, 30));
    addTearDown(controller.dispose);
    var sent = false;

    await controller.startTracking((_, __) async => sent = true);

    expect(controller.isTracking, isFalse);
    expect(sent, isFalse);
    expect(controller.errorMessage, contains('horizonte'));
  });

  for (final stopBeforeWrite in [true, false]) {
    test(
      'STOP cancels GoTo ${stopBeforeWrite ? "before write" : "during movement"}',
      () async {
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
        final controller = _controller(repository, _position(30, 45));
        addTearDown(controller.dispose);
        final sent = Completer<void>();
        final completed = Completer<void>();
        final moving = controller.sendInitialGoto((_, __) async {
          sent.complete();
          await completed.future;
        });
        if (!stopBeforeWrite) await sent.future;
        var stopped = false;
        await controller.sendStop(() async {
          stopped = true;
        });
        completed.complete();
        await moving;
        expect(stopped, isTrue);
        expect(sent.isCompleted, !stopBeforeWrite);
        expect(controller.lastSentCommand?.label, 'STOP');
        expect(controller.canFineTune, isFalse);
        expect(controller.isSending, isFalse);
      },
    );
  }

  test('STOP stops active tracking and sends stop command', () async {
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
    final controller = _controller(repository, _position(30, 45));
    addTearDown(controller.dispose);
    var stopSent = false;

    await controller.startTracking((_, __) async {});
    expect(controller.isTracking, isTrue);

    await controller.sendStop(() async => stopSent = true);

    expect(controller.isTracking, isFalse);
    expect(stopSent, isTrue);
    expect(controller.lastSentCommand?.label, 'STOP');
  });
}

CelestialControlController _controller(
  CalibrationRepository repository,
  AltAzResult position,
) {
  return CelestialControlController(
    object: _object(),
    gotoService: AstronomicalGotoService(
      observerDataProvider: const _FakeObserverDataProvider(),
      calibrationRepository: repository,
      positionResolver: (_, __) => position,
    ),
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
