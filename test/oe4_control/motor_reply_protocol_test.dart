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
  int idOf(List<int> data) =>
      (jsonDecode(utf8.decode(data)) as Map)['id'] as int;
  void reply(int id, String text) =>
      protocol.addBytes(utf8.encode('@$id $text\n'));

  test(
    'SET_POSITION needs matching firmware acknowledgement, not just a successful write',
    () async {
      var completed = false;
      late int id;
      final pending = protocol.send({'cmd': 'SET_POSITION'}, (data) async {
        id = idOf(data);
      });
      unawaited(pending.then((_) => completed = true));
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      reply(id + 1, 'SET_POSITION OK -> alt=45 az=120');
      reply(id, '{"msg":"PONG"}');
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      reply(id, 'SET_POSITION OK -> alt=45 az=120');
      await pending;
      expect(completed, isTrue);
    },
  );

  test(
    'fragmented responses reconstruct UTF8 without losing accented error text',
    () async {
      final pending = protocol.send({'cmd': 'SET_POSITION'}, (data) async {
        for (final byte in utf8.encode(
          '@${idOf(data)} ERROR: posición no aceptada\n',
        )) {
          protocol.addBytes([byte]);
        }
      });
      await expectLater(pending, throwsA(isA<StateError>()));
      expect(messages.single, 'ERROR: posición no aceptada');
    },
  );

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
      late int movementId;
      var done = false;
      final movement = protocol.send({'cmd': 'NUDGE'}, (data) async {
        movementId = idOf(data);
      });
      unawaited(movement.then((_) => done = true));
      reply(movementId, 'Comando: NUDGE dAlt=1 dAz=0');
      await protocol.send({'cmd': 'PING'}, (data) async {
        reply(idOf(data), '{"msg":"PONG"}');
      });
      expect(done, isFalse);
      reply(
        movementId,
        'STATUS -> posicion interna actual: alt=11 pasos (0.97 deg), az=0 pasos (0.00 deg)',
      );
      reply(movementId, 'NUDGE Completado');
      await movement;
    },
  );

  test(
    'STOP can cancel a pending move and still completes successfully',
    () async {
      late int movementId;
      final movement = protocol.send({'cmd': 'GOTO'}, (data) async {
        movementId = idOf(data);
      });
      final failed = expectLater(movement, throwsA(isA<StateError>()));
      await protocol.send({'cmd': 'STOP'}, (data) async {
        reply(movementId, 'ERROR: movimiento cancelado por STOP');
        reply(idOf(data), 'STOP Completado -> movimiento detenido');
      });
      await failed;
    },
  );

  test(
    'disconnect rejects pending commands and old replies cannot complete a new command',
    () async {
      late int previousId;
      final old = protocol.send({'cmd': 'SET_POSITION'}, (data) async {
        previousId = idOf(data);
      });
      final failed = expectLater(old, throwsA(isA<StateError>()));
      protocol.disconnect();
      await failed;
      var completed = false;
      late int newId;
      final next = protocol.send({'cmd': 'SET_POSITION'}, (data) async {
        newId = idOf(data);
      });
      unawaited(next.then((_) => completed = true));
      reply(previousId, 'SET_POSITION OK');
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      reply(newId, 'SET_POSITION OK');
      await next;
    },
  );

  test(
    'legacy unframed firmware cannot accidentally confirm calibration',
    () async {
      await expectLater(
        protocol.send({'cmd': 'SET_POSITION'}, (_) async {
          protocol.addBytes(utf8.encode('SET_POSITION OK\n'));
        }),
        throwsA(isA<TimeoutException>()),
      );
    },
  );
}
