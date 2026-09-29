import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/ble_connection_controller.dart';
import 'widgets/connection_status_card.dart';
import 'widgets/scan_button.dart';
import 'widgets/device_list_tile.dart';
import 'widgets/error_banner.dart';
import '../../data/models/ble_device_state.dart';

class ConnectionScreen extends StatelessWidget {
  const ConnectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AstroPilot'),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
        ],
      ),
      body: Consumer<BleConnectionController>(
        builder: (context, controller, _) {
          final state = controller.state;

          if (!state.arePermissionsGranted) {
            return _PermissionDeniedView(
              onRequestPermissions: controller.requestPermissions,
              onOpenSettings: controller.openSettings,
            );
          }

          if (!state.isBluetoothEnabled) {
            return const _BluetoothOffView();
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ConnectionStatusCard(
                  isConnected:
                      state.connectionStatus == BleConnectionStatus.connected,
                  isConnecting:
                      state.connectionStatus == BleConnectionStatus.connecting,
                ),
                const SizedBox(height: 16),
                if (state.connectionStatus !=
                    BleConnectionStatus.connected) ...[
                  ScanButton(
                    isScanning: state.scanStatus == BleScanStatus.scanning,
                    onToggle: controller.toggleScan,
                  ),
                  const SizedBox(height: 16),
                  if (state.errorMessage != null) ...[
                    ErrorBanner(message: state.errorMessage!),
                    const SizedBox(height: 16),
                  ],
                  Expanded(
                    child: state.discoveredDevices.isEmpty
                        ? const Center(
                            child: Text(
                              'Presiona "Buscar dispositivos" para escanear',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                          )
                        : ListView.separated(
                            itemCount: state.discoveredDevices.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final device = state.discoveredDevices[index];
                              return DeviceListTile(
                                device: device,
                                onConnect: () =>
                                    controller.connectToDevice(device),
                                isConnecting: false,
                              );
                            },
                          ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: controller.disconnect,
                    icon: const Icon(Icons.power_settings_new),
                    label: const Text('Desconectar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const Spacer(),
                  const Center(
                    child: Text(
                      'Dispositivo conectado',
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ),
                  const Spacer(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BluetoothOffView extends StatelessWidget {
  const _BluetoothOffView();

  @override
  Widget build(BuildContext context) {
    // The Scaffold body is loosely constrained; without Center this column
    // shrinks to the text width and sticks to the left edge.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.bluetooth_disabled,
              size: 64,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 16),
            const Text(
              'Bluetooth está desactivado.\nHabilítalo para continuar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionDeniedView extends StatelessWidget {
  final VoidCallback onRequestPermissions;
  final VoidCallback onOpenSettings;

  const _PermissionDeniedView({
    required this.onRequestPermissions,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 64, color: Color(0xFFF59E0B)),
          const SizedBox(height: 16),
          const Text(
            'Autoriza los permisos solicitados por la app\npara buscar dispositivos Bluetooth.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onRequestPermissions,
              child: const Text('Solicitar permisos'),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onOpenSettings,
            child: const Text('Abrir configuración de la app'),
          ),
        ],
      ),
    );
  }
}
