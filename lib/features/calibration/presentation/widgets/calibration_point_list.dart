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
            'Referencia $index: ${point.objectName}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _Row(label: 'Alt estrella', value: _format(point.calculatedAltitude)),
          _Row(label: 'Az estrella', value: _format(point.calculatedAzimuth)),
          _Row(
            label: 'Alt motor',
            value: _format(
              point.motorAltitudeAtCalibration ?? point.adjustedAltitude,
            ),
          ),
          _Row(
            label: 'Az motor',
            value: _format(
              point.motorAzimuthAtCalibration ?? point.adjustedAzimuth,
            ),
          ),
          if (point.referenceRaJ2000Hours != null)
            _Row(
              label: 'RA J2000',
              value: '${point.referenceRaJ2000Hours!.toStringAsFixed(4)} h',
            ),
          if (point.referenceDecJ2000Degrees != null)
            _Row(
              label: 'Dec J2000',
              value: _format(point.referenceDecJ2000Degrees!),
            ),
        ],
      ),
    );
  }

  String _format(double value) => '${value.toStringAsFixed(2)}°';
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
            width: 104,
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
