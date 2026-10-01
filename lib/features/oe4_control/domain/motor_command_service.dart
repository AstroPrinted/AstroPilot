import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../calibration/domain/services/alignment_session.dart';
import 'motor_reply_protocol.dart';
import 'telescope_position.dart';

class MotorCommandService {
  static final Guid serviceUuid = Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e');
  static final Guid rxWriteUuid = Guid('6e400002-b5a3-f393-e0a9-e50e24dcca9e');
  static final Guid txNotifyUuid = Guid('6e400003-b5a3-f393-e0a9-e50e24dcca9e');

  static const _movementCommands = {'GOTO', 'NUDGE', 'HOME'};

  /// Cada cuánto se pide STATUS mientras el telescopio se mueve.
  final Duration movementPollInterval;

  /// Tiempo sin acercarse al objetivo para considerar trabado el movimiento.
  final Duration stallWindow;

  /// Tiempo que se le da al motor para empezar a moverse.
  final Duration startGrace;

  /// Un movimiento falla si el ESP32 deja de responder STATUS este tiempo.
  /// Mientras responda, un movimiento largo puede durar lo que necesite.
  final Duration statusSilenceLimit;

  final _responseController = StreamController<String>.broadcast();

  BluetoothCharacteristic? _rxCharacteristic;
  StreamSubscription<List<int>>? _notifySubscription;
  String? _cachedDeviceId;
  Future<void>? _discovery;
  late final MotorReplyProtocol _replies;

  /// Posición que informó el encoder en el último STATUS.
  MotorAngles? motorPosition;

  /// Último objetivo absoluto enviado al firmware (lo que el PID intenta
  /// alcanzar). Es la referencia única para todos los movimientos de la app.
  MotorAngles? targetPosition;

  /// Cómo terminó el último movimiento (completado, llegó o se trabó).
  MoveOutcome? lastMoveOutcome;

  static const _movementLogLength = 8;
  final List<MoveRecord> _movementLog = [];

  /// Últimos movimientos, el más reciente primero.
  List<MoveRecord> get movementLog => List.unmodifiable(_movementLog);

  bool? firmwareMoving;
  int _movementSequence = 0;
  bool _movementInFlight = false;

  /// False while the firmware may still consider itself moving: the app
  /// settles a move at its own tolerance, but the firmware only stops after
  /// `Completado`, STOP or a STATUS with `moving=false`.
  bool _firmwareIdle = true;

  MotorCommandService({
    this.movementPollInterval = const Duration(milliseconds: 400),
    this.stallWindow = ArrivalDetector.defaultStallWindow,
    this.startGrace = ArrivalDetector.defaultStartGrace,
    this.statusSilenceLimit = const Duration(seconds: 10),
    Duration responseTimeout = const Duration(seconds: 5),
    // Backstop only: progress and stalls are judged from STATUS polls.
    Duration movementTimeout = const Duration(minutes: 10),
  }) {
    _replies = MotorReplyProtocol(
      onMessage: _onResponse,
      responseTimeout: responseTimeout,
      movementTimeout: movementTimeout,
    );
    AlignmentSession.changes.addListener(_onSessionChanged);
  }

  bool get movementInFlight => _movementInFlight;

  /// Posición física conocida: el encoder si hay STATUS, si no el objetivo.
  MotorAngles? get telescopePosition => motorPosition ?? targetPosition;

  /// Origen para los movimientos relativos (flechas / ajuste fino).
  ///
  /// Normalmente es el objetivo, para que cada paso sume exactamente lo pedido
  /// aunque el PID tenga un pequeño error estacionario. Si el telescopio quedó
  /// trabado lejos del objetivo, se parte de la posición real del encoder para
  /// que "abajo" nunca termine moviendo hacia arriba.
  MotorAngles? get motionBase {
    final target = targetPosition;
    final reported = motorPosition;
    if (target == null) return reported;
    if (reported != null &&
        !_movementInFlight &&
        axisError(target, reported) > ArrivalDetector.defaultToleranceDeg) {
      return reported;
    }
    return target;
  }

  void _onSessionChanged() {
    motorPosition = null;
    targetPosition = null;
    lastMoveOutcome = null;
    firmwareMoving = null;
    _firmwareIdle = true;
    _movementSequence++;
    _movementInFlight = false;
    _replies.disconnect();
    _rxCharacteristic = null;
    _cachedDeviceId = null;
    _discovery = null;
    unawaited(_notifySubscription?.cancel());
    _notifySubscription = null;
  }

  void _onResponse(String message) {
    if (message.startsWith('STATUS ->')) {
      final match = RegExp(
        r'alt=-?[\d.]+ (?:pulsos|pasos) \(([-\d.]+) deg\), '
        r'az=-?[\d.]+ (?:pulsos|pasos) \(([-\d.]+) deg\)',
      ).firstMatch(message);
      if (match != null) {
        motorPosition = (
          altitude: double.parse(match.group(1)!),
          azimuth: double.parse(match.group(2)!),
        );
        // Tras conectar, STOP o una alerta el objetivo del firmware es
        // desconocido; se adopta la posición real como referencia.
        if (targetPosition == null && !_movementInFlight) {
          targetPosition = normalizeMotorAngles(
            motorPosition!.altitude,
            motorPosition!.azimuth,
          );
        }
      }
      final moving = RegExp(r'moving=(\w+)').firstMatch(message)?.group(1);
      if (moving != null) {
        firmwareMoving = moving == 'true' || moving == '1';
        if (!firmwareMoving! && !_movementInFlight) _firmwareIdle = true;
      }
    } else if (message.startsWith('SET_POSITION OK')) {
      final match = RegExp(
        r'alt=(-?[\d.]+) deg, az=(-?[\d.]+) deg',
      ).firstMatch(message);
      if (match != null) {
        _adoptPosition(
          double.parse(match.group(1)!),
          double.parse(match.group(2)!),
        );
      }
    } else if (message.startsWith('GOTO Completado') ||
        message.startsWith('NUDGE Completado') ||
        message.startsWith('HOME Completado')) {
      if (!_movementInFlight) _firmwareIdle = true;
    } else if (message.startsWith('STOP Completado') ||
        message.startsWith('ALERTA:')) {
      _firmwareIdle = true;
      // No sabemos dónde quedó el objetivo del firmware: se toma del STATUS.
      _movementSequence++;
      _movementInFlight = false;
      targetPosition = null;
      _requestStatusQuietly();
    }
    if (!_responseController.isClosed) _responseController.add(message);
  }

  void _adoptPosition(double altitude, double azimuth) {
    final position = normalizeMotorAngles(altitude, azimuth);
    motorPosition = position;
    targetPosition = position;
    lastMoveOutcome = null;
  }

  void _requestStatusQuietly() {
    unawaited(
      _writeCommand({'cmd': 'STATUS'}).then<void>((_) {}, onError: (_) {}),
    );
  }

  Stream<String> get responseStream => _responseController.stream;

  Future<String> sendGotoCommand(
    String deviceId, {
    required double alt,
    required double az,
  }) {
    return _sendCommand(deviceId, {
      'cmd': 'GOTO',
      'alt': _jsonNumber(alt),
      'az': _jsonNumber(az),
    });
  }

  /// The app moves relatively with GOTO from the shared position (see
  /// `Oe4ControlController.moveBy`); NUDGE is kept for protocol completeness.
  Future<String> sendNudgeCommand(
    String deviceId, {
    required double deltaAlt,
    required double deltaAz,
  }) {
    return _sendCommand(deviceId, {
      'cmd': 'NUDGE',
      'dAlt': _jsonNumber(deltaAlt),
      'dAz': _jsonNumber(deltaAz),
    });
  }

  Future<String> sendSetPositionCommand(
    String deviceId, {
    required double alt,
    required double az,
  }) async {
    final session = AlignmentSession.token;
    final command = <String, Object>{
      'cmd': 'SET_POSITION',
      'alt': _jsonNumber(alt),
      'az': _jsonNumber(az),
    };
    // The firmware rejects SET_POSITION while its PID is still active, which
    // happens after a move the app settled before `Completado`.
    if (_movementInFlight || !_firmwareIdle) {
      await _stopBeforeSetPosition(deviceId);
    }
    String sent;
    try {
      sent = await _sendCommand(deviceId, command);
    } on StateError catch (error) {
      if (!_requiresStoppedMotors(error)) rethrow;
      await _stopBeforeSetPosition(deviceId);
      sent = await _sendCommand(deviceId, command);
    }
    if (session != AlignmentSession.token) return sent;
    // The firmware confirmed that its logical position is now (alt, az).
    _adoptPosition(alt, az);
    // SET_POSITION rewrites the encoder but may leave the PID target in the
    // old coordinates, so the motor would drive back toward it. A GOTO to
    // the new position makes target and position equal; it is a no-op when
    // the firmware already did so.
    await _sendCommand(deviceId, {
      'cmd': 'GOTO',
      'alt': _jsonNumber(alt),
      'az': _jsonNumber(az),
    });
    return sent;
  }

  Future<void> _stopBeforeSetPosition(String deviceId) async {
    await _sendCommand(deviceId, {'cmd': 'STOP'});
    await _writeCommand({'cmd': 'STATUS'});
  }

  bool _requiresStoppedMotors(StateError error) => RegExp(
    r'detenid|movimiento|moviendo',
    caseSensitive: false,
  ).hasMatch(error.message);

  /// Registra una posición confirmada por SET_POSITION después de que la
  /// sesión se invalidó (referencia manual).
  void adoptConfirmedPosition(double altitude, double azimuth) {
    _adoptPosition(altitude, azimuth);
  }

  Future<String> sendHomeCommand(String deviceId) {
    return _sendCommand(deviceId, {'cmd': 'HOME'});
  }

  Future<String> sendStatusCommand(String deviceId) {
    return _sendCommand(deviceId, {'cmd': 'STATUS'});
  }

  Future<String> sendStopCommand(String deviceId) {
    // After STOP the firmware reports its final position through the STATUS
    // requested in _onResponse.
    return _sendCommand(deviceId, {'cmd': 'STOP'});
  }

  Future<String> sendTestRoutineCommand(String deviceId) {
    return _sendCommand(deviceId, {'cmd': 'TEST_ROUTINE'});
  }

  Future<String> sendPingCommand(String deviceId) {
    return _sendCommand(deviceId, {'cmd': 'PING'});
  }

  Future<String> sendEnableWatchdogCommand(String deviceId, bool enabled) {
    return _sendCommand(deviceId, {
      'cmd': 'ENABLE_WATCHDOG',
      'enabled': enabled,
    });
  }

  Future<int> readRssi(String deviceId) {
    return BluetoothDevice.fromId(deviceId).readRssi();
  }

  Future<String> _sendCommand(
    String deviceId,
    Map<String, Object> command,
  ) async {
    final session = AlignmentSession.token;
    await ensureConnected(deviceId);
    if (session != AlignmentSession.token) {
      throw StateError('La conexión cambió. Repite el comando.');
    }
    if (!_movementCommands.contains(command['cmd'])) {
      return _writeCommand(command);
    }
    return _sendMovement(command, session);
  }

  Future<String> _sendMovement(
    Map<String, Object> command,
    String session,
  ) async {
    final sequence = ++_movementSequence;
    final from = motorPosition ?? targetPosition;
    final startedAt = DateTime.now();
    final clock = Stopwatch()..start();
    final target = _movementTarget(command);
    targetPosition = target;
    lastMoveOutcome = null;
    motorPosition = null;
    _movementInFlight = true;
    _firmwareIdle = false;

    final detector = ArrivalDetector(
      target: target,
      stallWindow: stallWindow,
      startGrace: startGrace,
    );
    MoveOutcomeKind? settled;
    final movement = _writeCommand(command);
    unawaited(
      _watchMovement(sequence, session, movement, detector, (kind) {
        settled = kind;
        _replies.settleMovements();
      }),
    );

    final String sent;
    try {
      sent = await movement;
      if (session == AlignmentSession.token) {
        // The OE4 firmware does not report STATUS after a move; calibration
        // needs the final motor position.
        await _writeCommand({'cmd': 'STATUS'});
      }
    } catch (error) {
      if (sequence == _movementSequence) _movementInFlight = false;
      _logMove(
        MoveRecord(
          startedAt: startedAt,
          command: jsonEncode(command),
          from: from,
          target: target,
          reached: motorPosition ?? detector.lastPosition,
          kind: null,
          error: error is StateError ? error.message : error.toString(),
          duration: clock.elapsed,
        ),
      );
      rethrow;
    }

    if (sequence == _movementSequence && session == AlignmentSession.token) {
      _movementInFlight = false;
      // HOME has no known target: the firmware ends wherever home is.
      final reached = motorPosition;
      if (targetPosition == null && reached != null) {
        targetPosition = normalizeMotorAngles(
          reached.altitude,
          reached.azimuth,
        );
      }
      // Settled by the app: the firmware PID keeps running until Completado.
      if (settled == null || firmwareMoving == false) _firmwareIdle = true;
      lastMoveOutcome = MoveOutcome(
        kind: settled ?? MoveOutcomeKind.completed,
        command: sent,
        target: target ?? targetPosition,
        reached: motorPosition ?? detector.lastPosition,
      );
    }
    _logMove(
      MoveRecord(
        startedAt: startedAt,
        command: sent,
        from: from,
        target: target,
        reached: motorPosition ?? detector.lastPosition,
        kind: settled ?? MoveOutcomeKind.completed,
        error: null,
        duration: clock.elapsed,
      ),
    );
    return sent;
  }

  void _logMove(MoveRecord record) {
    _movementLog.insert(0, record);
    if (_movementLog.length > _movementLogLength) _movementLog.removeLast();
  }

  MotorAngles? _movementTarget(Map<String, Object> command) {
    switch (command['cmd']) {
      case 'GOTO':
        return normalizeMotorAngles(
          (command['alt']! as num).toDouble(),
          (command['az']! as num).toDouble(),
        );
      case 'NUDGE':
        // The firmware applies NUDGE to its last target.
        final base = targetPosition ?? motorPosition;
        if (base == null) return null;
        return normalizeMotorAngles(
          base.altitude + (command['dAlt']! as num).toDouble(),
          base.azimuth + (command['dAz']! as num).toDouble(),
        );
      default:
        return null;
    }
  }

  /// Polls STATUS while [movement] is pending and settles it as soon as the
  /// encoder is within tolerance or stops advancing. Without this the app
  /// waits for `Completado`, which a heavy telescope may never reach.
  Future<void> _watchMovement(
    int sequence,
    String session,
    Future<String> movement,
    ArrivalDetector detector,
    void Function(MoveOutcomeKind kind) settle,
  ) async {
    var finished = false;
    unawaited(
      movement
          .then<void>((_) {}, onError: (_) {})
          .whenComplete(() => finished = true),
    );
    final clock = Stopwatch()..start();
    var lastReply = Duration.zero;
    bool stale() =>
        finished ||
        sequence != _movementSequence ||
        session != AlignmentSession.token;

    while (true) {
      await Future<void>.delayed(movementPollInterval);
      if (stale()) return;
      try {
        await _writeCommand({'cmd': 'STATUS'});
        lastReply = clock.elapsed;
      } catch (_) {
        if (stale()) return;
        if (clock.elapsed - lastReply >= statusSilenceLimit) {
          _replies.failMovements(
            'El ESP32 dejó de responder durante el movimiento. '
            'Revisa la conexión BLE.',
          );
          return;
        }
        continue;
      }
      if (stale()) return;
      final position = motorPosition;
      if (position == null) continue;
      final outcome = detector.addSample(clock.elapsed, position);
      if (outcome != null) {
        settle(outcome);
        return;
      }
    }
  }

  /// Finds the OE4 GATT characteristics once per connection.
  @visibleForTesting
  Future<void> ensureConnected(String deviceId) async {
    final discovery = _discovery ??= _ensureCharacteristics(deviceId);
    try {
      await discovery;
    } finally {
      if (identical(_discovery, discovery)) _discovery = null;
    }
  }

  @visibleForTesting
  Future<void> writeBytes(List<int> data) async {
    // Retrying a movement after an uncertain write can duplicate that movement.
    await _rxCharacteristic!.write(data, withoutResponse: false);
  }

  /// One TX notification from the firmware.
  @visibleForTesting
  void receiveBytes(List<int> data) => _replies.addBytes(data);

  Future<String> _writeCommand(Map<String, Object> command) {
    return _replies.send(command, writeBytes);
  }

  Future<void> _ensureCharacteristics(String deviceId) async {
    if (_cachedDeviceId == deviceId && _rxCharacteristic != null) return;
    final session = AlignmentSession.token;

    final device = BluetoothDevice.fromId(deviceId);
    await _resetCharacteristics(device);

    final services = await _discoverServicesWithRetry(device);
    if (session != AlignmentSession.token) {
      throw StateError('La conexión cambió durante la búsqueda de servicios.');
    }
    final service = _findService(services, serviceUuid);
    if (service == null) {
      throw StateError(
        'Servicio OE4 no encontrado. Esperado: ${serviceUuid.str128}. '
        'Servicios encontrados: ${_describeServices(services)}. '
        'Verifica que el ESP32 esté usando el firmware OE4 BLE y que el dispositivo conectado sea AstroPilot-OE4.',
      );
    }

    final rx = _findCharacteristic(service.characteristics, rxWriteUuid);
    if (rx == null) {
      throw StateError(
        'Caracteristica RX Write OE4 no encontrada. Esperada: ${rxWriteUuid.str128}. '
        'Caracteristicas encontradas: ${_describeCharacteristics(service.characteristics)}.',
      );
    }

    final tx = _findCharacteristic(service.characteristics, txNotifyUuid);
    if (tx == null) {
      throw StateError(
        'Caracteristica TX Notify OE4 no encontrada. Esperada: ${txNotifyUuid.str128}. '
        'Caracteristicas encontradas: ${_describeCharacteristics(service.characteristics)}.',
      );
    }

    if (tx.properties.notify || tx.properties.indicate) {
      await tx.setNotifyValue(true);
      if (session != AlignmentSession.token) {
        throw StateError('La conexión cambió al activar notificaciones.');
      }
      _notifySubscription = tx.onValueReceived.listen((value) {
        if (value.isEmpty || session != AlignmentSession.token) return;
        receiveBytes(value);
      });
    } else {
      throw StateError(
        'El firmware debe permitir notificaciones para confirmar los comandos.',
      );
    }
    _rxCharacteristic = rx;
    _cachedDeviceId = deviceId;
  }

  Future<List<BluetoothService>> _discoverServicesWithRetry(
    BluetoothDevice device,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final firstServices = await device.discoverServices(
      subscribeToServicesChanged: false,
    );
    if (_findService(firstServices, serviceUuid) != null) {
      return firstServices;
    }

    await _tryClearGattCache(device);
    await Future<void>.delayed(const Duration(milliseconds: 650));

    return device.discoverServices(subscribeToServicesChanged: false);
  }

  Future<void> _tryClearGattCache(BluetoothDevice device) async {
    try {
      await device.clearGattCache();
    } catch (_) {
      // Android-only optimization. Other platforms or unsupported states can ignore it.
    }
  }

  Future<void> _resetCharacteristics(BluetoothDevice device) async {
    await _notifySubscription?.cancel();
    _notifySubscription = null;
    _rxCharacteristic = null;
    _cachedDeviceId = null;
    await _tryClearGattCache(device);
  }

  num _jsonNumber(double value) {
    if (value.isFinite && value == value.roundToDouble()) {
      return value.toInt();
    }
    return double.parse(value.toStringAsFixed(4));
  }

  BluetoothService? _findService(List<BluetoothService> services, Guid uuid) {
    for (final service in services) {
      if (service.uuid == uuid) return service;
    }
    return null;
  }

  BluetoothCharacteristic? _findCharacteristic(
    List<BluetoothCharacteristic> characteristics,
    Guid uuid,
  ) {
    for (final characteristic in characteristics) {
      if (characteristic.uuid == uuid) return characteristic;
    }
    return null;
  }

  String _describeServices(List<BluetoothService> services) {
    if (services.isEmpty) return 'ninguno';

    return services
        .map(
          (service) =>
              '${service.uuid.str128} '
              'chars=[${_describeCharacteristics(service.characteristics)}]',
        )
        .join(' | ');
  }

  String _describeCharacteristics(
    List<BluetoothCharacteristic> characteristics,
  ) {
    if (characteristics.isEmpty) return 'ninguna';

    return characteristics
        .map((characteristic) => characteristic.uuid.str128)
        .join(', ');
  }

  Future<void> dispose() async {
    AlignmentSession.changes.removeListener(_onSessionChanged);
    _replies.disconnect();
    await _notifySubscription?.cancel();
    await _responseController.close();
  }
}
