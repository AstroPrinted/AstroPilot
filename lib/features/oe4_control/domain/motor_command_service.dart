import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../calibration/domain/services/alignment_session.dart';
import 'motor_reply_protocol.dart';

class MotorCommandService {
  static final Guid serviceUuid = Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e');
  static final Guid rxWriteUuid = Guid('6e400002-b5a3-f393-e0a9-e50e24dcca9e');
  static final Guid txNotifyUuid = Guid('6e400003-b5a3-f393-e0a9-e50e24dcca9e');

  final _responseController = StreamController<String>.broadcast();

  BluetoothCharacteristic? _rxCharacteristic;
  StreamSubscription<List<int>>? _notifySubscription;
  String? _cachedDeviceId;
  Future<void>? _discovery;
  late final MotorReplyProtocol _replies;
  ({double altitude, double azimuth})? motorPosition;

  MotorCommandService() {
    _replies = MotorReplyProtocol(onMessage: _onResponse);
    AlignmentSession.changes.addListener(_onSessionChanged);
  }

  void _onSessionChanged() {
    motorPosition = null;
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
        r'alt=-?\d+ pasos \(([-\d.]+) deg\), az=-?\d+ pasos \(([-\d.]+) deg\)',
      ).firstMatch(message);
      if (match != null) {
        motorPosition = (
          altitude: double.parse(match.group(1)!),
          azimuth: double.parse(match.group(2)!),
        );
      }
    }
    _responseController.add(message);
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

  /// Bench movement in motor coordinates; it does not establish star alignment.
  Future<String> sendBenchMoveCommand(
    String deviceId, {
    required double alt,
    required double az,
  }) {
    return _sendCommand(deviceId, {
      'cmd': 'MOVE',
      'alt': _jsonNumber(alt),
      'az': _jsonNumber(az),
    });
  }

  Future<String> sendSetPositionCommand(
    String deviceId, {
    required double alt,
    required double az,
  }) {
    return _sendCommand(deviceId, {
      'cmd': 'SET_POSITION',
      'alt': _jsonNumber(alt),
      'az': _jsonNumber(az),
    });
  }

  Future<String> sendHomeCommand(String deviceId) {
    return _sendCommand(deviceId, {'cmd': 'HOME'});
  }

  Future<String> sendStatusCommand(String deviceId) {
    return _sendCommand(deviceId, {'cmd': 'STATUS'});
  }

  Future<String> sendStopCommand(String deviceId) {
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
    final discovery = _discovery ??= _ensureCharacteristics(deviceId);
    try {
      await discovery;
    } finally {
      if (identical(_discovery, discovery)) _discovery = null;
    }
    if (session != AlignmentSession.token) {
      throw StateError('La conexión cambió. Repite el comando.');
    }
    return _replies.send(command, (data) async {
      // Retrying a movement after an uncertain write can duplicate that movement.
      await _rxCharacteristic!.write(data, withoutResponse: false);
    });
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
        _replies.addBytes(value);
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
