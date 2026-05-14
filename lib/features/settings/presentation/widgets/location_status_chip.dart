import 'package:flutter/material.dart';

import '../../domain/models/observer_state.dart';

class LocationStatusChip extends StatelessWidget {
  final ObserverState state;

  const LocationStatusChip({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (label, icon, color) = switch (state.status) {
      LocationStatus.gpsActive => (
        'GPS activo',
        Icons.gps_fixed_rounded,
        colorScheme.secondary,
      ),
      LocationStatus.manual => (
        'Manual',
        Icons.edit_location_alt_rounded,
        colorScheme.primary,
      ),
      LocationStatus.gpsDisabled => (
        'GPS no disponible',
        Icons.gps_off_rounded,
        colorScheme.error,
      ),
      LocationStatus.permissionDenied => (
        'Permiso denegado',
        Icons.lock_outline_rounded,
        colorScheme.error,
      ),
      LocationStatus.outOfBounds => (
        'Fuera de Chile',
        Icons.warning_amber_rounded,
        colorScheme.error,
      ),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.36)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.isLoadingLocation)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            state.isLoadingLocation ? 'Obteniendo GPS...' : label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
