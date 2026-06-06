import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class MotorCommandService {
  static final Guid serviceUuid = Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e');
  static final Guid rxWriteUuid = Guid('6e400002-b5a3-f393-e0a9-e50e24dcca9e');
  static final Guid txNotifyUuid = Guid('6e400003-b5a3-f393-e0a9-e50e24dcca9e');

  final _responseController = StreamController<String>.broadcast();

  BluetoothCharacteristic? _rxCharacteristic;
  StreamSubscription<List<int>>? _notifySubscription;
  String? _cachedDeviceId;

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
    await _ensureCharacteristics(deviceId);
    final json = jsonEncode(command);
    final data = utf8.encode(json);
    try {
      await _rxCharacteristic!.write(data, withoutResponse: false);
    } on PlatformException catch (e) {
      if (!_isStaleGattWriteError(e)) rethrow;

      await _resetCharacteristics(BluetoothDevice.fromId(deviceId));
      await _ensureCharacteristics(deviceId);
      await _rxCharacteristic!.write(data, withoutResponse: false);
    }
    return json;
  }

  Future<void> _ensureCharacteristics(String deviceId) async {
    if (_cachedDeviceId == deviceId && _rxCharacteristic != null) return;

    final device = BluetoothDevice.fromId(deviceId);
    await _resetCharacteristics(device);

    final services = await _discoverServicesWithRetry(device);
    final service = _findService(services, serviceUuid);
    if (service == null) {
      throw StateError(
        'Servicio OE4 no encontrado. Esperado: ${serviceUuid.str128}. '
        'Servicios encontrados: ${_describeServices(services)}. '
        'Verifica que el ESP32 este usando el firmware OE4 BLE y que el dispositivo conectado sea AstroPilot-OE4.',
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

    _rxCharacteristic = rx;
    _cachedDeviceId = deviceId;

    if (tx.properties.notify || tx.properties.indicate) {
      await tx.setNotifyValue(true);
      _notifySubscription = tx.onValueReceived.listen((value) {
        if (value.isEmpty) return;
        _responseController.add(utf8.decode(value, allowMalformed: true));
      });
    }
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

  bool _isStaleGattWriteError(PlatformException e) {
    final details = '${e.message ?? ''} ${e.details ?? ''}'.toLowerCase();
    return e.code == 'writeCharacteristic' &&
        details.contains('primary service not found');
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
    await _notifySubscription?.cancel();
    await _responseController.close();
  }
}
