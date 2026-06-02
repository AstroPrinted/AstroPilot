import 'package:flutter/material.dart';

import '../../domain/models/calibration_status.dart';

class CalibrationStatusBadge extends StatelessWidget {
  final CalibrationStatus status;

  const CalibrationStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      CalibrationStatus.notCalibrated => colorScheme.onSurfaceVariant,
      CalibrationStatus.inProgress ||
      CalibrationStatus.partiallyCalibrated => colorScheme.tertiary,
      CalibrationStatus.failed => colorScheme.error,
      _ => colorScheme.secondary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconFor(status), size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            status.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(CalibrationStatus status) {
    return switch (status) {
      CalibrationStatus.notCalibrated => Icons.radio_button_unchecked_rounded,
      CalibrationStatus.inProgress => Icons.sync_rounded,
      CalibrationStatus.partiallyCalibrated => Icons.adjust_rounded,
      CalibrationStatus.failed => Icons.error_outline_rounded,
      _ => Icons.check_circle_outline_rounded,
    };
  }
}
