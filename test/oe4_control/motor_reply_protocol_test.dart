import 'dart:async';
import 'dart:convert';

import 'package:astroprintedlogicincludedgeoengine/features/oe4_control/domain/motor_reply_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MotorReplyProtocol protocol;
  late List<String> messages;
  setUp(() {
    messages = [];
    protocol = MotorReplyProtocol(
      onMessage: messages.add,
      responseTimeout: const Duration(milliseconds: 30),
      movementTimeout: const Duration(milliseconds: 100),
    );
  });
  tearDown(() => protocol.disconnect());
  // The OE4 firmware notifies each sendResponse() as one plain message.
  void notify(String text) => protocol.addBytes(utf8.encode(text));

  test('commands are sent as the plain JSON the firmware parses', () async {
    late String written;
    await protocol.send({'cmd': 'GOTO', 'alt': 10, 'az': 20}, (data) async {
      written = utf8.decode(data);
      notify('Comando: GOTO alt=10.00 deg, az=20.00 deg -> alt=1239 pulsos');
      notify('GOTO Completado');
    });
    expect(written, '{"cmd":"GOTO","alt":10,"az":20}');
  });

  test(
    'SET_POSITION needs the firmware acknowledgement, not just a successful write',
    () async {
      var completed = false;
      final pending = protocol.send({'cmd': 'SET_POSITION'}, (_) async {});
      unawaited(pending.then((_) => completed = true));
      await Future<void>.delayed(Duration.zero);
      notify('{"status":"OK","msg":"PONG"}');
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      notify('SET_POSITION OK -> alt=45.0000 deg, az=120.0000 deg');
      await pending;
      expect(completed, isTrue);
    },
  );

  test('firmware errors reject the command that was just written', () async {
    await expectLater(
      protocol.send({'cmd': 'GOTO'}, (_) async {
        notify('ERROR: altitud fuera de rango');
      }),
      throwsA(isA<StateError>()),
    );
    expect(messages.single, 'ERROR: altitud fuera de rango');
  });

  test('errors are not attributed to a concurrent heartbeat', () async {
    final ping = protocol.send({'cmd': 'PING'}, (_) async {});
    final failed = expectLater(
      protocol.send({'cmd': 'SET_POSITION'}, (_) async {
        notify('ERROR: SET_POSITION requiere motores detenidos');
      }),
      throwsA(isA<StateError>()),
    );
    notify('{"status":"OK","msg":"PONG"}');
    await ping;
    await failed;
  });

  test('no acknowledgement times out instead of reporting success', () async {
    await expectLater(
      protocol.send({'cmd': 'SET_POSITION'}, (_) async {}),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('BLE write errors propagate immediately', () async {
    await expectLater(
      protocol.send({'cmd': 'SET_POSITION'}, (_) async {
        throw StateError('BLE write failed');
      }),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'motion waits for completion while heartbeat remains independent',
    () async {
      var done = false;
      final movement = protocol.send({'cmd': 'NUDGE'}, (_) async {});
      unawaited(movement.then((_) => done = true));
      notify('Comando: NUDGE dAlt=1.00 deg, dAz=0.00 deg -> alt=1.00 deg');
      await protocol.send({'cmd': 'PING'}, (_) async {
        notify('{"status":"OK","msg":"PONG"}');
      });
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);
      notify('NUDGE Completado');
      await movement;
    },
  );

  test('a retargeted move completes when the final move finishes', () async {
    final first = protocol.send({'cmd': 'GOTO'}, (_) async {});
    final second = protocol.send({'cmd': 'NUDGE'}, (_) async {});
    notify('NUDGE Completado');
    await Future.wait([first, second]);
  });

  test('the app can settle a move the firmware never completes', () async {
    // A heavy telescope may stay outside the 6-pulse tolerance forever.
    final movement = protocol.send({'cmd': 'GOTO'}, (_) async {
      notify('Comando: GOTO alt=21.00 deg, az=243.00 deg -> alt=2600 pulsos');
    });
    await Future<void>.delayed(Duration.zero);
    protocol.settleMovements();
    await movement;
  });

  test('a late GOTO error is not taken by a STATUS poll', () async {
    final movement = protocol.send({'cmd': 'GOTO'}, (_) async {});
    final failed = expectLater(movement, throwsA(isA<StateError>()));
    final status = protocol.send({'cmd': 'STATUS'}, (_) async {});
    notify('ERROR: altitud fuera de rango');
    await failed;
    notify(
      'STATUS -> posicion interna actual: alt=0 pulsos (0.00 deg), '
      'az=0.00 pulsos (0.00 deg), moving=false, watchdog=false',
    );
    await status;
  });

  test('STOP cancels a pending move and still completes', () async {
    final movement = protocol.send({'cmd': 'GOTO'}, (_) async {});
    final failed = expectLater(movement, throwsA(isA<StateError>()));
    await protocol.send({'cmd': 'STOP'}, (_) async {
      notify('STOP Completado -> movimiento detenido');
    });
    await failed;
  });

  test('watchdog alert fails the pending move', () async {
    await expectLater(
      protocol.send({'cmd': 'GOTO'}, (_) async {
        notify('ALERTA: conexión perdida. Motores detenidos en 1200 ms');
      }),
      throwsA(isA<StateError>()),
    );
  });

  test('STATUS and watchdog replies complete their commands', () async {
    await protocol.send({'cmd': 'STATUS'}, (_) async {
      notify(
        'STATUS -> posicion interna actual: alt=0 pulsos (0.00 deg), '
        'az=0.00 pulsos (0.00 deg), moving=false, watchdog=false',
      );
    });
    await protocol.send({'cmd': 'ENABLE_WATCHDOG', 'enabled': true}, (_) async {
      notify('{"status":"OK","watchdog":true}');
    });
  });

  test('disconnect rejects pending commands', () async {
    final old = protocol.send({'cmd': 'SET_POSITION'}, (_) async {});
    final failed = expectLater(old, throwsA(isA<StateError>()));
    protocol.disconnect();
    await failed;
  });
}
