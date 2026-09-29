import 'package:astroprintedlogicincludedgeoengine/features/ble_connection/data/models/ble_device_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const device = BleDevice(
    id: 'iphone-uuid',
    name: 'AstroPilot-OE4',
    rssi: -50,
  );
  const connected = BleConnectionState(
    connectionStatus: BleConnectionStatus.connected,
    connectedDevice: device,
  );

  test('scan and permission updates preserve the active BLE device', () {
    final updated = connected.copyWith(
      scanStatus: BleScanStatus.stopped,
      arePermissionsGranted: true,
    );
    expect(updated.connectedDevice, same(device));
    expect(updated.connectionStatus, BleConnectionStatus.connected);
  });

  test('disconnect can explicitly clear the active BLE device', () {
    final updated = connected.copyWith(
      connectionStatus: BleConnectionStatus.disconnected,
      connectedDevice: null,
    );
    expect(updated.connectedDevice, isNull);
  });

  test('scan list puts the telescope first even among stronger devices', () {
    final sorted = sortDevicesForTelescope(const [
      BleDevice(id: 'a', name: unnamedBleDeviceName, rssi: -30),
      BleDevice(id: 'b', name: 'JBL Flip', rssi: -40),
      BleDevice(id: 'c', name: 'AstroPilot-OE4', rssi: -80, isTelescope: true),
      BleDevice(id: 'd', name: 'Mi Band', rssi: -60),
    ]);
    expect(sorted.map((d) => d.id), ['c', 'b', 'd', 'a']);
  });
}
