import 'dart:async';
import 'dart:convert';

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

  Future<String> _sendCommand(
    String deviceId,
    Map<String, Object> command,
  ) async {
    await _ensureCharacteristics(deviceId);
    final json = jsonEncode(command);
    final data = utf8.encode(json);
    await _rxCharacteristic!.write(data, withoutResponse: false);
    return json;
  }

  Future<void> _ensureCharacteristics(String deviceId) async {
    if (_cachedDeviceId == deviceId && _rxCharacteristic != null) return;

    await _notifySubscription?.cancel();
    _notifySubscription = null;
    _rxCharacteristic = null;
    _cachedDeviceId = null;

    final device = BluetoothDevice.fromId(deviceId);
    final services = await device.discoverServices();
    final service = _findService(services, serviceUuid);
    if (service == null) {
      throw StateError('Servicio OE4 no encontrado en el ESP32.');
    }

    final rx = _findCharacteristic(service.characteristics, rxWriteUuid);
    if (rx == null) {
      throw StateError('Caracteristica RX Write OE4 no encontrada.');
    }

    final tx = _findCharacteristic(service.characteristics, txNotifyUuid);
    if (tx == null) {
      throw StateError('Caracteristica TX Notify OE4 no encontrada.');
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

  Future<void> dispose() async {
    await _notifySubscription?.cancel();
    await _responseController.close();
  }
}
