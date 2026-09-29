enum BleConnectionStatus { disconnected, connecting, connected, error }

enum BleScanStatus { idle, scanning, stopped }

const _unchangedDevice = Object();

class BleDevice {
  final String id;
  final String name;
  final int rssi;

  /// Advertises the OE4 service UUID or the AstroPilot name.
  final bool isTelescope;

  const BleDevice({
    required this.id,
    required this.name,
    required this.rssi,
    this.isTelescope = false,
  });
}

/// Telescope first, then named devices, then unnamed; strongest signal first.
List<BleDevice> sortDevicesForTelescope(Iterable<BleDevice> devices) {
  int rank(BleDevice d) => d.isTelescope
      ? 0
      : d.name == unnamedBleDeviceName
      ? 2
      : 1;
  return devices.toList()..sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    return byRank != 0 ? byRank : b.rssi.compareTo(a.rssi);
  });
}

const unnamedBleDeviceName = 'Dispositivo BLE sin nombre';

class BleConnectionState {
  final BleConnectionStatus connectionStatus;
  final BleScanStatus scanStatus;
  final List<BleDevice> discoveredDevices;
  final BleDevice? connectedDevice;
  final String? errorMessage;
  final bool isBluetoothEnabled;
  final bool arePermissionsGranted;

  const BleConnectionState({
    this.connectionStatus = BleConnectionStatus.disconnected,
    this.scanStatus = BleScanStatus.idle,
    this.discoveredDevices = const [],
    this.connectedDevice,
    this.errorMessage,
    this.isBluetoothEnabled = true,
    this.arePermissionsGranted = true,
  });

  BleConnectionState copyWith({
    BleConnectionStatus? connectionStatus,
    BleScanStatus? scanStatus,
    List<BleDevice>? discoveredDevices,
    Object? connectedDevice = _unchangedDevice,
    String? errorMessage,
    bool? isBluetoothEnabled,
    bool? arePermissionsGranted,
  }) {
    return BleConnectionState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      scanStatus: scanStatus ?? this.scanStatus,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      connectedDevice: identical(connectedDevice, _unchangedDevice)
          ? this.connectedDevice
          : connectedDevice as BleDevice?,
      errorMessage: errorMessage,
      isBluetoothEnabled: isBluetoothEnabled ?? this.isBluetoothEnabled,
      arePermissionsGranted:
          arePermissionsGranted ?? this.arePermissionsGranted,
    );
  }
}
