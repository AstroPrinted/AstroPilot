import 'package:flutter/material.dart';

class ScanButton extends StatelessWidget {
  final bool isScanning;
  final VoidCallback onToggle;

  const ScanButton({
    super.key,
    required this.isScanning,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onToggle,
        icon: isScanning
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.search),
        label: Text(isScanning ? 'Detener búsqueda' : 'Buscar dispositivos'),
        style: ElevatedButton.styleFrom(
          backgroundColor: isScanning ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
