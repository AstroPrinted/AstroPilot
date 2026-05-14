import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../data/models/ble_device_state.dart';

class BleService {
  final Duration _connectionTimeout = const Duration(seconds: 15);

  Stream<bool> get bluetoothStateStream =>
      FlutterBluePlus.adapterState.map((state) => state == BluetoothAdapterState.on);

  Future<bool> isBluetoothEnabled() async {
    final state = await FlutterBluePlus.adapterState.first;
    return state == BluetoothAdapterState.on;
  }

  Stream<List<BleDevice>> scanDevices() async* {
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 30));

    await for (final event in FlutterBluePlus.scanResults) {
      final devices = event
          .where((r) => r.device.platformName.isNotEmpty)
          .map((r) => BleDevice(
                id: r.device.remoteId.str,
                name: r.device.platformName,
                rssi: r.rssi,
              ))
          .toList();
      yield devices;
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  Future<void> connectToDevice(String deviceId) async {
    final device = BluetoothDevice.fromId(deviceId);
    await device.connect(license: License.free, timeout: _connectionTimeout);
  }

  Future<void> disconnectDevice(String deviceId) async {
    final device = BluetoothDevice.fromId(deviceId);
    await device.disconnect();
  }

  Stream<BleConnectionStatus> connectionStatusStream(String deviceId) {
    final device = BluetoothDevice.fromId(deviceId);
    return device.connectionState.map((state) {
      switch (state) {
        case BluetoothConnectionState.connected:
          return BleConnectionStatus.connected;
        case BluetoothConnectionState.disconnected:
          return BleConnectionStatus.disconnected;
        default:
          return BleConnectionStatus.connecting;
      }
    });
  }
}
