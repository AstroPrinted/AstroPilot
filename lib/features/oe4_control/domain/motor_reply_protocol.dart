import 'dart:async';
import 'dart:convert';

/// Firmware v3: each UTF-8 response is `@<request id> <message>\n`.
/// IDs prevent a late acknowledgement or a heartbeat from completing a move.
class MotorReplyProtocol {
  final Duration responseTimeout;
  final Duration movementTimeout;
  final void Function(String message) onMessage;
  final Map<int, ({String command, Completer<void> reply})> _pending = {};
  final List<int> _buffer = [];
  int _nextId = 1;

  MotorReplyProtocol({
    required this.onMessage,
    this.responseTimeout = const Duration(seconds: 5),
    this.movementTimeout = const Duration(seconds: 30),
  });

  Future<String> send(
    Map<String, Object> command,
    Future<void> Function(List<int> bytes) write,
  ) async {
    final id = _nextId++;
    final name = command['cmd']! as String;
    final encoded = jsonEncode({...command, 'id': id});
    final reply = Completer<void>();
    _pending[id] = (command: name, reply: reply);
    final timeout = {'GOTO', 'MOVE', 'NUDGE', 'HOME'}.contains(name)
        ? movementTimeout
        : responseTimeout;
    try {
      await Future.wait<void>([
        Future.sync(() => write(utf8.encode(encoded))),
        reply.future.timeout(
          timeout,
          onTimeout: () {
            throw TimeoutException(
              'Sin confirmación del ESP32 para $name. Revisa la conexión y carga el firmware v3 del proyecto.',
            );
          },
        ),
      ], eagerError: true);
      return encoded;
    } finally {
      _pending.remove(id);
      // Release timeout timers when the write failed before any response.
      if (!reply.isCompleted) reply.complete();
    }
  }

  void addBytes(List<int> bytes) {
    for (final byte in bytes) {
      if (byte == 10) {
        final line = utf8.decode(_buffer, allowMalformed: true).trim();
        _buffer.clear();
        _acceptLine(line);
      } else {
        _buffer.add(byte);
        if (_buffer.length > 4096) _buffer.clear();
      }
    }
  }

  void _acceptLine(String line) {
    final match = RegExp(r'^@(\d+) (.*)$').firstMatch(line);
    if (match == null) return;
    final message = match.group(2)!;
    onMessage(message);
    final pending = _pending[int.parse(match.group(1)!)];
    if (pending == null || pending.reply.isCompleted) return;
    if (message.startsWith('ERROR:') || message.startsWith('ALERTA:')) {
      pending.reply.completeError(StateError(message));
      return;
    }
    final complete = switch (pending.command) {
      'GOTO' || 'MOVE' => message.startsWith('GOTO Completado'),
      'NUDGE' => message.startsWith('NUDGE Completado'),
      'HOME' => message.startsWith('HOME Completado'),
      'SET_POSITION' => message.startsWith('SET_POSITION OK'),
      'STATUS' => message.startsWith('STATUS ->'),
      'STOP' => message.startsWith('STOP Completado'),
      'PING' => message.contains('"msg":"PONG"'),
      'ENABLE_WATCHDOG' => message.contains('"watchdog":'),
      'TEST_ROUTINE' => message.startsWith('TEST_ROUTINE iniciado'),
      _ => false,
    };
    if (complete) pending.reply.complete();
  }

  void disconnect() {
    _buffer.clear();
    for (final pending in _pending.values) {
      if (!pending.reply.isCompleted) {
        pending.reply.completeError(
          StateError('Conexión interrumpida. Repite la alineación.'),
        );
      }
    }
    _pending.clear();
  }
}
