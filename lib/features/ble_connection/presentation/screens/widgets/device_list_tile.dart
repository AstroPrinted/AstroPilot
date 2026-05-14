import 'package:flutter/material.dart';
import '../../../data/models/ble_device_state.dart';

class DeviceListTile extends StatelessWidget {
  final BleDevice device;
  final VoidCallback onConnect;
  final bool isConnecting;

  const DeviceListTile({
    super.key,
    required this.device,
    required this.onConnect,
    this.isConnecting = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            const Icon(Icons.signal_cellular_alt, color: Color(0xFF94A3B8)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'RSSI: ${device.rssi} dBm',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            isConnecting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: onConnect,
                    child: const Text('Conectar'),
                  ),
          ],
        ),
      ),
    );
  }
}
