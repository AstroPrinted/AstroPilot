import 'dart:async';
import 'dart:convert';

typedef _Pending = ({String command, Completer<void> reply});

/// Firmware OE4 (equipo de electrónica): each BLE notification carries one
/// plain UTF-8 message without request id or line terminator. Replies are
/// matched to pending commands by their text.
class MotorReplyProtocol {
  static const _movementCommands = {'GOTO', 'NUDGE', 'HOME'};

  final Duration responseTimeout;
  final Duration movementTimeout;
  final void Function(String message) onMessage;
  final List<_Pending> _pending = [];

  MotorReplyProtocol({
    required this.onMessage,
    this.responseTimeout = const Duration(seconds: 5),
    this.movementTimeout = const Duration(seconds: 60),
  });

  Future<String> send(
    Map<String, Object> command,
    Future<void> Function(List<int> bytes) write,
  ) async {
    final name = command['cmd']! as String;
    final encoded = jsonEncode(command);
    final pending = (command: name, reply: Completer<void>());
    _pending.add(pending);
    final timeout = _movementCommands.contains(name)
        ? movementTimeout
        : responseTimeout;
    try {
      await Future.wait<void>([
        Future.sync(() => write(utf8.encode(encoded))),
        pending.reply.future.timeout(
          timeout,
          onTimeout: () {
            throw TimeoutException(
              'Sin confirmación del ESP32 para $name. Revisa la conexión BLE.',
            );
          },
        ),
      ], eagerError: true);
      return encoded;
    } finally {
      _pending.remove(pending);
      // Release timeout timers when the write failed before any response.
      if (!pending.reply.isCompleted) pending.reply.complete();
    }
  }

  /// One notification is one firmware message (`sendResponse`).
  void addBytes(List<int> bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    for (final line in text.split('\n')) {
      final message = line.trim();
      if (message.isNotEmpty) _acceptMessage(message);
    }
  }

  void _acceptMessage(String message) {
    onMessage(message);

    if (message.startsWith('ERROR:')) {
      // The firmware answers errors synchronously to the command just written.
      // PING and the STATUS polls sent while a move is in progress never fail.
      final target =
          _lastOpen((p) => p.command != 'PING' && p.command != 'STATUS') ??
          _lastOpen((_) => true);
      target?.reply.completeError(StateError(message));
      return;
    }
    if (message.startsWith('TEST_ROUTINE no iniciado')) {
      _firstOpen(
        (p) => p.command == 'TEST_ROUTINE',
      )?.reply.completeError(StateError(message));
      return;
    }
    if (message.startsWith('ALERTA:')) {
      _failMovements(message);
      return;
    }
    if (message.startsWith('STOP Completado')) {
      _failMovements('Movimiento cancelado por STOP');
      _firstOpen((p) => p.command == 'STOP')?.reply.complete();
      return;
    }
    if (_isMovementCompletion(message)) {
      // A new GOTO/NUDGE/HOME retargets the firmware; only the last one
      // reports completion, so every pending movement has finished.
      for (final p in _open((p) => _movementCommands.contains(p.command))) {
        p.reply.complete();
      }
      return;
    }

    _firstOpen((p) => _completes(p.command, message))?.reply.complete();
  }

  /// The app decided that the movement ended (encoder within tolerance or
  /// stalled) even though the firmware has not reported `Completado`.
  void settleMovements() {
    for (final p in _open((p) => _movementCommands.contains(p.command))) {
      p.reply.complete();
    }
  }

  /// Fails every pending movement (for example when STATUS polls stop
  /// arriving during a move).
  void failMovements(String reason) => _failMovements(reason);

  bool _isMovementCompletion(String message) =>
      message.startsWith('GOTO Completado') ||
      message.startsWith('NUDGE Completado') ||
      message.startsWith('HOME Completado');

  bool _completes(String command, String message) => switch (command) {
    'SET_POSITION' => message.startsWith('SET_POSITION OK'),
    'STATUS' => message.startsWith('STATUS ->'),
    'PING' => message.contains('"msg":"PONG"'),
    'ENABLE_WATCHDOG' => message.contains('"watchdog":'),
    'TEST_ROUTINE' => message.startsWith('TEST_ROUTINE iniciado'),
    _ => false,
  };

  void _failMovements(String reason) {
    for (final p in _open((p) => _movementCommands.contains(p.command))) {
      p.reply.completeError(StateError(reason));
    }
  }

  List<_Pending> _open(bool Function(_Pending) test) => [
    for (final p in _pending)
      if (!p.reply.isCompleted && test(p)) p,
  ];

  _Pending? _firstOpen(bool Function(_Pending) test) {
    final open = _open(test);
    return open.isEmpty ? null : open.first;
  }

  _Pending? _lastOpen(bool Function(_Pending) test) {
    final open = _open(test);
    return open.isEmpty ? null : open.last;
  }

  void disconnect() {
    for (final pending in _pending) {
      if (!pending.reply.isCompleted) {
        pending.reply.completeError(
          StateError('Conexión interrumpida. Repite la alineación.'),
        );
      }
    }
    _pending.clear();
  }
}
