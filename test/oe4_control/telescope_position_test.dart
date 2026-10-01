import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:astroprintedlogicincludedgeoengine/features/oe4_control/domain/motor_command_service.dart';
import 'package:astroprintedlogicincludedgeoengine/features/oe4_control/domain/telescope_position.dart';
import 'package:astroprintedlogicincludedgeoengine/features/oe4_control/presentation/controllers/oe4_control_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ArrivalDetector', () {
    MoveOutcomeKind? sample(
      ArrivalDetector detector,
      int seconds,
      double altitude,
      double azimuth,
    ) {
      return detector.addSample(Duration(seconds: seconds), (
        altitude: altitude,
        azimuth: azimuth,
      ));
    }

    test('arrives after two readings inside the tolerance', () {
      final detector = ArrivalDetector(target: (altitude: 21, azimuth: 243));
      expect(sample(detector, 0, 10, 200), isNull);
      expect(sample(detector, 1, 20.97, 243), isNull);
      expect(sample(detector, 2, 21.02, 242.98), MoveOutcomeKind.arrived);
    });

    test('0.1° away is still outside the tolerance', () {
      final detector = ArrivalDetector(target: (altitude: 21, azimuth: 243));
      expect(sample(detector, 0, 20.9, 243), isNull);
      expect(sample(detector, 1, 20.9, 243), isNull);
    });

    test('tolerance wraps across north', () {
      final detector = ArrivalDetector(target: (altitude: 0, azimuth: 0));
      expect(sample(detector, 0, 0, 359.98), isNull);
      expect(sample(detector, 1, 0, 0.02), MoveOutcomeKind.arrived);
    });

    test('an encoder that stops advancing far from the target stalls', () {
      final detector = ArrivalDetector(target: (altitude: 21, azimuth: 243));
      MoveOutcomeKind? outcome;
      for (var i = 0; i <= 12; i++) {
        final altitude = min(15.0, i * 5.0);
        outcome = detector.addSample(Duration(milliseconds: 500 * i), (
          altitude: altitude,
          azimuth: 243,
        ));
        if (outcome != null) break;
      }
      expect(outcome, MoveOutcomeKind.stalled);
    });

    test('a slow start is not a stall', () {
      // A heavy telescope may need a few seconds before the PID overcomes
      // static friction. Before, this was reported as stalled at 2 s.
      final detector = ArrivalDetector(target: (altitude: 0, azimuth: 200));
      for (var i = 0; i <= 12; i++) {
        final azimuth = i < 6 ? 0.0 : (i - 5) * 1.0;
        expect(
          detector.addSample(Duration(milliseconds: 500 * i), (
            altitude: 0,
            azimuth: azimuth,
          )),
          isNull,
          reason: 'sample $i',
        );
      }
    });

    test('a motor that never starts stalls after the start grace', () {
      final detector = ArrivalDetector(target: (altitude: 0, azimuth: 200));
      for (var i = 0; i < 10; i++) {
        expect(
          detector.addSample(Duration(milliseconds: 500 * i), (
            altitude: 0,
            azimuth: 0,
          )),
          isNull,
        );
      }
      expect(
        detector.addSample(const Duration(seconds: 5), (
          altitude: 0,
          azimuth: 0,
        )),
        MoveOutcomeKind.stalled,
      );
    });

    test('slow but steady movement is not a stall', () {
      final detector = ArrivalDetector(target: (altitude: 21, azimuth: 243));
      for (var i = 0; i <= 12; i++) {
        expect(
          detector.addSample(Duration(milliseconds: 500 * i), (
            altitude: i * 0.1,
            azimuth: 243,
          )),
          isNull,
        );
      }
    });
  });

  group('shared telescope position', () {
    late _FakeFirmware firmware;
    late Oe4ControlController controller;

    void start({double maxAltitude = 90}) {
      firmware = _FakeFirmware(maxAltitude: maxAltitude);
      controller = Oe4ControlController(firmware);
      addTearDown(controller.dispose);
    }

    test(
      'a GOTO finishes when the encoder arrives, without Completado',
      () async {
        start();
        await controller.moveTo('oe4', alt: 21, az: 243, throwOnError: true);

        expect(controller.lastMoveOutcome?.kind, MoveOutcomeKind.arrived);
        expect(controller.targetPosition, (altitude: 21.0, azimuth: 243.0));
        expect(controller.motorPosition, (altitude: 21.0, azimuth: 243.0));
        expect(controller.isMoving, isFalse);
        expect(controller.isSending, isFalse);
      },
    );

    test('relative moves start from where another screen left it', () async {
      start();
      // Control OE4: GOTO 21 / 243.
      await controller.moveTo('oe4', alt: 21, az: 243, throwOnError: true);
      // Alignment: one step up.
      await controller.moveBy(
        'oe4',
        deltaAlt: 1,
        deltaAz: 0,
        throwOnError: true,
      );

      final moves = firmware.commands.where((c) => c['cmd'] != 'STATUS');
      expect(moves.map((c) => [c['cmd'], c['alt'], c['az']]).toList(), [
        ['GOTO', 21, 243],
        ['GOTO', 22, 243],
      ]);
      expect(firmware.commands.any((c) => c['cmd'] == 'NUDGE'), isFalse);
      expect(controller.motorPosition, (altitude: 22.0, azimuth: 243.0));
    });

    test(
      'a heavy telescope that stalls ends the move with a warning',
      () async {
        start(maxAltitude: 15);
        await controller.moveTo('oe4', alt: 21, az: 100, throwOnError: true);

        final outcome = controller.lastMoveOutcome!;
        expect(outcome.kind, MoveOutcomeKind.stalled);
        expect(outcome.errorDeg, closeTo(6, 0.01));
        expect(controller.movementWarning, contains('6.00°'));
        expect(controller.errorMessage, isNull);

        // "Down" moves down from where the telescope really is (15°), not from
        // the unreached 21° target.
        await controller.moveBy(
          'oe4',
          deltaAlt: -1,
          deltaAz: 0,
          throwOnError: true,
        );
        final lastGoto = firmware.commands.lastWhere((c) => c['cmd'] == 'GOTO');
        expect(lastGoto['alt'], 14);
        expect(controller.lastMoveOutcome?.kind, MoveOutcomeKind.arrived);
        expect(controller.movementWarning, isNull);
      },
    );

    test('a long move that starts late still reaches the target', () async {
      start();
      firmware.startDelay = const Duration(milliseconds: 90);
      await controller.moveTo('oe4', alt: 0, az: 200, throwOnError: true);
      expect(controller.lastMoveOutcome?.kind, MoveOutcomeKind.arrived);
      expect(controller.motorPosition, (altitude: 0.0, azimuth: 200.0));
    });

    test('a move fails if the ESP32 stops answering STATUS', () async {
      start();
      firmware.muteStatus = true;
      await expectLater(
        controller.moveTo('oe4', alt: 0, az: 200, throwOnError: true),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('dejó de responder'),
          ),
        ),
      );
    });

    test('the movement history records origin, target and result', () async {
      start(maxAltitude: 15);
      await controller.moveTo('oe4', alt: 5, az: 40, throwOnError: true);
      await controller.moveTo('oe4', alt: 21, az: 40, throwOnError: true);

      final log = controller.movementLog;
      expect(log, hasLength(2));
      expect(log.first.from, (altitude: 5.0, azimuth: 40.0));
      expect(log.first.target, (altitude: 21.0, azimuth: 40.0));
      expect(log.first.reached, (altitude: 15.0, azimuth: 40.0));
      expect(log.first.kind, MoveOutcomeKind.stalled);
      expect(log.last.kind, MoveOutcomeKind.arrived);
    });

    test('Completado from the firmware still finishes the move', () async {
      start();
      firmware.reportsCompletion = true;
      await controller.moveTo('oe4', alt: 5, az: 10, throwOnError: true);
      expect(controller.lastMoveOutcome?.kind, MoveOutcomeKind.completed);
    });

    test('an unknown position is read with STATUS before moving', () async {
      start();
      firmware
        ..alt = 30
        ..az = 90;
      await controller.moveBy(
        'oe4',
        deltaAlt: 0,
        deltaAz: 2,
        throwOnError: true,
      );
      expect(firmware.commands.first['cmd'], 'STATUS');
      final goto = firmware.commands.firstWhere((c) => c['cmd'] == 'GOTO');
      expect([goto['alt'], goto['az']], [30, 92]);
    });

    test('setting a reference after a settled move stops the PID first and '
        'does not drive back to the old target', () async {
      start();
      // The app settles at its tolerance; the firmware never says Completado,
      // so it still rejects SET_POSITION ("requiere motores detenidos").
      await controller.moveTo('oe4', alt: 10, az: 10, throwOnError: true);
      await controller.setManualReference('oe4', alt: 0, az: 0);

      final names = firmware.commands
          .map((c) => c['cmd'])
          .where((c) => c != 'STATUS')
          .toList();
      expect(names, ['GOTO', 'STOP', 'SET_POSITION', 'GOTO']);
      expect(firmware.rejectedSetPositions, 0);
      final hold = firmware.commands.lastWhere((c) => c['cmd'] == 'GOTO');
      expect([hold['alt'], hold['az']], [0, 0]);
      // Without the hold GOTO the simulated PID would return to 10 / 10.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      firmware.tick();
      expect([firmware.alt, firmware.az], [0.0, 0.0]);
      expect(controller.targetPosition, (altitude: 0.0, azimuth: 0.0));
    });

    test(
      'an unreliable moving flag still retries SET_POSITION after STOP',
      () async {
        start();
        firmware.statusHidesMoving = true;
        await controller.moveTo('oe4', alt: 10, az: 10, throwOnError: true);
        await controller.setManualReference('oe4', alt: 0, az: 0);

        expect(firmware.rejectedSetPositions, 1);
        final names = firmware.commands
            .map((c) => c['cmd'])
            .where((c) => c != 'STATUS')
            .toList();
        expect(names, ['GOTO', 'SET_POSITION', 'STOP', 'SET_POSITION', 'GOTO']);
        expect(controller.errorMessage, isNull);
      },
    );

    test('no STOP is sent when the firmware reported Completado', () async {
      start();
      firmware.reportsCompletion = true;
      await controller.moveTo('oe4', alt: 10, az: 10, throwOnError: true);
      await controller.setManualReference('oe4', alt: 0, az: 0);
      expect(firmware.commands.any((c) => c['cmd'] == 'STOP'), isFalse);
    });

    test('STOP forgets the target and adopts the reported position', () async {
      start();
      await controller.moveTo('oe4', alt: 21, az: 243, throwOnError: true);
      firmware
        ..alt = 18
        ..az = 240;
      await controller.sendStop('oe4');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.targetPosition, (altitude: 18.0, azimuth: 240.0));
    });
  });
}

/// Simulated OE4 firmware: it moves a few degrees per STATUS and, like a heavy
/// telescope, can be unable to climb above [maxAltitude].
class _FakeFirmware extends MotorCommandService {
  final double maxAltitude;
  final double stepDeg = 20;
  bool reportsCompletion = false;

  /// Reports moving=false even while the PID still holds a target.
  bool statusHidesMoving = false;

  /// Time a heavy telescope needs before the motor starts moving.
  Duration startDelay = Duration.zero;
  bool muteStatus = false;
  final Stopwatch _sinceGoto = Stopwatch();
  int rejectedSetPositions = 0;
  double alt = 0;
  double az = 0;
  double _targetAlt = 0;
  double _targetAz = 0;
  bool _moving = false;
  final List<Map<String, dynamic>> commands = [];

  _FakeFirmware({required this.maxAltitude})
    : super(
        movementPollInterval: const Duration(milliseconds: 2),
        stallWindow: const Duration(milliseconds: 40),
        startGrace: const Duration(milliseconds: 250),
        statusSilenceLimit: const Duration(milliseconds: 150),
        responseTimeout: const Duration(milliseconds: 60),
        movementTimeout: const Duration(seconds: 5),
      );

  @override
  Future<void> ensureConnected(String deviceId) async {}

  @override
  Future<void> writeBytes(List<int> data) async {
    final command = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
    commands.add(command);
    scheduleMicrotask(() => _handle(command));
  }

  void _reply(String message) => receiveBytes(utf8.encode(message));

  void _handle(Map<String, dynamic> command) {
    switch (command['cmd']) {
      case 'GOTO':
        _targetAlt = (command['alt'] as num).toDouble();
        _targetAz = (command['az'] as num).toDouble();
        _moving = true;
        _sinceGoto
          ..reset()
          ..start();
        _reply('Comando: GOTO alt=$_targetAlt deg, az=$_targetAz deg');
      case 'STATUS':
        if (muteStatus) return;
        _advance();
        _reply(
          'STATUS -> posicion interna actual: '
          'alt=0 pulsos (${alt.toStringAsFixed(2)} deg), '
          'az=0.00 pulsos (${az.toStringAsFixed(2)} deg), '
          'moving=${_moving && !statusHidesMoving}, watchdog=false',
        );
        if (_moving &&
            reportsCompletion &&
            alt == _targetAlt &&
            az == _targetAz) {
          _moving = false;
          _reply('GOTO Completado');
        }
      case 'SET_POSITION':
        if (_moving) {
          rejectedSetPositions++;
          _reply('ERROR: SET_POSITION requiere motores detenidos');
          return;
        }
        // Like the suspected firmware bug: the encoder is rewritten but the
        // PID target stays in the old coordinates, so the motor drives back.
        alt = (command['alt'] as num).toDouble();
        az = (command['az'] as num).toDouble();
        _moving = true;
        _reply(
          'SET_POSITION OK -> alt=${alt.toStringAsFixed(4)} deg, '
          'az=${az.toStringAsFixed(4)} deg',
        );
      case 'STOP':
        _moving = false;
        _targetAlt = alt;
        _targetAz = az;
        _reply('STOP Completado -> movimiento detenido');
      case 'PING':
        _reply('{"status":"OK","msg":"PONG"}');
    }
  }

  void tick() => _advance();

  void _advance() {
    if (!_moving || _sinceGoto.elapsed < startDelay) return;
    alt = _toward(alt, min(_targetAlt, maxAltitude));
    az = _toward(az, _targetAz);
  }

  double _toward(double from, double to) {
    final delta = to - from;
    if (delta.abs() <= stepDeg) return to;
    return from + stepDeg * delta.sign;
  }
}
