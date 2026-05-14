import 'package:flutter/material.dart';

class ConnectionStatusCard extends StatelessWidget {
  final bool isConnected;
  final bool isConnecting;

  const ConnectionStatusCard({
    super.key,
    required this.isConnected,
    required this.isConnecting,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            if (isConnecting)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                isConnected ? Icons.circle : Icons.circle_outlined,
                color: isConnected ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                size: 20,
              ),
            const SizedBox(width: 12),
            Text(
              isConnected ? 'Conectado' : 'Desconectado',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
