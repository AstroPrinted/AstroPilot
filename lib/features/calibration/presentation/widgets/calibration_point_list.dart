import 'package:flutter/material.dart';

import '../../domain/models/calibration_point.dart';

class CalibrationPointList extends StatelessWidget {
  final List<CalibrationPoint> points;

  const CalibrationPointList({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Text(
        'Sin puntos guardados todavia.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return Column(
      children: [
        for (var index = 0; index < points.length; index++)
          Padding(
            padding: EdgeInsets.only(
              bottom: index == points.length - 1 ? 0 : 10,
            ),
            child: _PointTile(index: index + 1, point: points[index]),
          ),
      ],
    );
  }
}

class _PointTile extends StatelessWidget {
  final int index;
  final CalibrationPoint point;

  const _PointTile({required this.index, required this.point});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Punto $index: ${point.objectName}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _Row(
            label: 'Calculado',
            value: _pair(point.calculatedAltitude, point.calculatedAzimuth),
          ),
          _Row(
            label: 'Ajustado',
            value: _pair(point.adjustedAltitude, point.adjustedAzimuth),
          ),
          _Row(
            label: 'Offset',
            value:
                'Alt ${_formatSigned(point.altitudeError)} / Az ${_formatSigned(point.azimuthError)}',
          ),
        ],
      ),
    );
  }

  String _pair(double altitude, double azimuth) {
    return 'Alt ${_format(altitude)} / Az ${_format(azimuth)}';
  }

  String _format(double value) => '${value.toStringAsFixed(2)}°';

  String _formatSigned(double value) {
    final sign = value >= 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(2)}°';
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
