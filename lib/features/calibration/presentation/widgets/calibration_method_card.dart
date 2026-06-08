import 'package:flutter/material.dart';

import '../../domain/models/calibration_method.dart';

class CalibrationMethodCard extends StatelessWidget {
  final CalibrationMethod method;
  final bool enabled;
  final String? badgeText;
  final VoidCallback? onTap;

  const CalibrationMethodCard({
    super.key,
    required this.method,
    this.enabled = true,
    this.badgeText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final interactive = enabled && method.isEnabledInMvp;
    final accent = interactive
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return Card(
      child: InkWell(
        onTap: interactive ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: enabled ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconFor(method), color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            method.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (!interactive)
                          _MethodBadge(label: badgeText ?? 'Bloqueada'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      method.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(CalibrationMethod method) {
    return switch (method) {
      CalibrationMethod.oneStar => Icons.filter_1_rounded,
      CalibrationMethod.twoStars => Icons.filter_2_rounded,
      CalibrationMethod.threeStars => Icons.filter_3_rounded,
      CalibrationMethod.fixedObjectSync => Icons.my_location_rounded,
    };
  }
}

class _MethodBadge extends StatelessWidget {
  final String label;

  const _MethodBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
