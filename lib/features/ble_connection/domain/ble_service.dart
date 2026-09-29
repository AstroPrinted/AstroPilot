import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../oe4_control/domain/motor_command_service.dart';
import '../data/models/ble_device_state.dart';

class BleService {
  final Duration _connectionTimeout = const Duration(seconds: 15);

  Stream<bool> get bluetoothStateStream => FlutterBluePlus.adapterState
      .where((state) => state != BluetoothAdapterState.unknown)
      .map((state) => state == BluetoothAdapterState.on);

  Future<bool> isBluetoothEnabled() async {
    // CoreBluetooth initially reports unknown while its manager initializes.
    final state = await FlutterBluePlus.adapterState
        .where((state) => state != BluetoothAdapterState.unknown)
        .first
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => BluetoothAdapterState.unknown,
        );
    return state == BluetoothAdapterState.on;
  }

  Stream<List<BleDevice>> scanDevices() async* {
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 30));

    await for (final event in FlutterBluePlus.scanResults) {
      yield sortDevicesForTelescope(event.map(_toDevice));
    }
  }

  BleDevice _toDevice(ScanResult r) {
    final name = r.advertisementData.advName.isNotEmpty
        ? r.advertisementData.advName
        : r.device.platformName.isNotEmpty
        ? r.device.platformName
        : unnamedBleDeviceName;
    return BleDevice(
      id: r.device.remoteId.str,
      name: name,
      rssi: r.rssi,
      isTelescope:
          r.advertisementData.serviceUuids.contains(
            MotorCommandService.serviceUuid,
          ) ||
          name.toLowerCase().contains('astropilot'),
    );
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
