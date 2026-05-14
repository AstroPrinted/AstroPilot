enum BleConnectionStatus { disconnected, connecting, connected, error }

enum BleScanStatus { idle, scanning, stopped }

class BleDevice {
  final String id;
  final String name;
  final int rssi;

  const BleDevice({
    required this.id,
    required this.name,
    required this.rssi,
  });
}

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
    BleDevice? connectedDevice,
    String? errorMessage,
    bool? isBluetoothEnabled,
    bool? arePermissionsGranted,
  }) {
    return BleConnectionState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      scanStatus: scanStatus ?? this.scanStatus,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      connectedDevice: connectedDevice,
      errorMessage: errorMessage,
      isBluetoothEnabled: isBluetoothEnabled ?? this.isBluetoothEnabled,
      arePermissionsGranted: arePermissionsGranted ?? this.arePermissionsGranted,
    );
  }
}
