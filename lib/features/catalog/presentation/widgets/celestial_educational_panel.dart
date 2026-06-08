import 'package:flutter/material.dart';

import '../../../calibration/domain/models/calibration_result.dart';
import '../../../observation/domain/models/alt_az_result.dart';
import '../../application/astronomical_goto_service.dart';
import '../utils/coordinate_formatters.dart';

class CelestialEducationalPanel extends StatelessWidget {
  final String objectName;
  final AltAzResult? currentPosition;
  final CalibrationResult? savedCalibration;
  final AstronomicalGotoCommand? previewCommand;
  final DateTime? lastUpdatedAt;
  final DateTime? nextTrackingAt;
  final Duration trackingInterval;

  const CelestialEducationalPanel({
    super.key,
    required this.objectName,
    required this.currentPosition,
    required this.savedCalibration,
    required this.previewCommand,
    required this.lastUpdatedAt,
    required this.nextTrackingAt,
    required this.trackingInterval,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.school_rounded, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Qué está haciendo AstroPilot?',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Modo visual para explicar el flujo del prototipo educativo. '
              'No envía comandos, no recalcula posiciones y no cambia el '
              'tracking lógico.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            _EducationalTile(
              icon: Icons.route_rounded,
              title: 'Resumen del flujo',
              children: [
                _FlowStep(
                  number: '1',
                  text: 'Se calcula la posición del objeto: $objectName.',
                ),
                const _FlowStep(
                  number: '2',
                  text:
                      'Se verifica que exista una referencia de calibración guardada.',
                ),
                const _FlowStep(
                  number: '3',
                  text: 'Se prepara el comando GOTO final para el ESP32.',
                ),
                const _FlowStep(
                  number: '4',
                  text:
                      'Si el tracking lógico está activo, se repite cada '
                      '15 segundos.',
                ),
              ],
            ),
            _EducationalTile(
              icon: Icons.explore_rounded,
              title: 'Qué es Altitud y Azimut?',
              children: [
                const _BodyText(
                  'Altitud indica qué tan alto está el objeto sobre el '
                  'horizonte. Altitud 0 grados es el horizonte y altitud '
                  '90 grados es sobre la cabeza.',
                ),
                const SizedBox(height: 8),
                const _BodyText(
                  'Azimut indica la dirección horizontal alrededor del '
                  'horizonte: 0/360 grados es norte, 90 grados es este, '
                  '180 grados es sur y 270 grados es oeste.',
                ),
                const SizedBox(height: 12),
                _MetricWrap(
                  metrics: [
                    _EducationalMetric(
                      label: 'Altitud actual',
                      value: _currentAltitudeText,
                    ),
                    _EducationalMetric(
                      label: 'Azimut actual',
                      value: _currentAzimuthText,
                    ),
                  ],
                ),
              ],
            ),
            _EducationalTile(
              icon: Icons.tune_rounded,
              title: 'Qué hace la referencia calibrada?',
              children: [
                const _BodyText(
                  'La calibración con una estrella fija la posición lógica '
                  'actual del telescopio usando la Alt/Az real de una estrella '
                  'centrada manualmente.',
                ),
                const SizedBox(height: 8),
                const _BodyText(
                  'Luego el firmware mueve los motores desde esa posición '
                  'lógica hacia la Alt/Az real del objeto objetivo.',
                ),
                const SizedBox(height: 8),
                const _BodyText(
                  'Es una referencia inicial; no corrige automáticamente '
                  'errores mecánicos, desnivel del trípode o desalineación '
                  'avanzada.',
                ),
                const SizedBox(height: 12),
                if (savedCalibration == null) ...[
                  const _SafeNotice(
                    icon: Icons.info_outline_rounded,
                    text:
                        'Sin calibración guardada. El GoTo automático debe '
                        'permanecer bloqueado hasta centrar una estrella.',
                  ),
                  const SizedBox(height: 12),
                ],
                _MetricWrap(
                  metrics: [
                    _EducationalMetric(
                      label: 'Referencia altitud',
                      value: _altitudeOffsetText,
                    ),
                    _EducationalMetric(
                      label: 'Referencia azimut',
                      value: _azimuthOffsetText,
                    ),
                  ],
                ),
              ],
            ),
            _EducationalTile(
              icon: Icons.send_rounded,
              title: 'Qué comando se envía al telescopio?',
              children: [
                const _BodyText(
                  'La app calcula la posición real del objeto en Alt/Az usando '
                  'fecha, hora y ubicación actuales.',
                ),
                const SizedBox(height: 8),
                const _BodyText(
                  'Luego prepara un comando GOTO final hacia esa Alt/Az. La '
                  'diferencia de movimiento la resuelve el firmware desde su '
                  'posición lógica actual.',
                ),
                const SizedBox(height: 12),
                _DataLine(
                  label: 'Alt/Az calculado',
                  value: _calculatedPairText,
                ),
                _DataLine(label: 'Alt/Az final', value: _correctedPairText),
                _DataLine(label: 'Comando final', value: _finalCommandText),
              ],
            ),
            _EducationalTile(
              icon: Icons.track_changes_rounded,
              title: 'Cómo funciona el tracking lógico?',
              children: [
                const _BodyText(
                  'El cielo cambia con el tiempo. La app recalcula la '
                  'posición del objeto cada 15 segundos y prepara un nuevo '
                  'GOTO.',
                ),
                const SizedBox(height: 8),
                const _BodyText(
                  'Esto es tracking lógico por app. No es validación óptica ni '
                  'seguimiento físico continuo de alta precisión.',
                ),
                const SizedBox(height: 12),
                _DataLine(
                  label: 'Intervalo de tracking',
                  value: '${trackingInterval.inSeconds} segundos',
                ),
                _DataLine(
                  label: 'Última actualización',
                  value: _dateText(lastUpdatedAt, fallback: 'Aún no calculado'),
                ),
                _DataLine(
                  label: 'Proximo envio',
                  value: _dateText(
                    nextTrackingAt,
                    fallback: 'Tracking inactivo',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _currentAltitudeText {
    final position = currentPosition;
    if (position == null) return 'Aún no calculado';
    return _formatSigned(position.altitudeDeg);
  }

  String get _currentAzimuthText {
    final position = currentPosition;
    if (position == null) return 'Aún no calculado';
    return _formatUnsigned(position.azimuthDeg);
  }

  String get _altitudeOffsetText {
    final calibration = savedCalibration;
    if (calibration == null) return 'Sin calibración';
    final point = calibration.points.isNotEmpty
        ? calibration.points.last
        : null;
    if (point?.motorAltitudeAtCalibration != null) {
      return _formatSigned(point!.motorAltitudeAtCalibration!);
    }
    return _formatSigned(calibration.altitudeOffset);
  }

  String get _azimuthOffsetText {
    final calibration = savedCalibration;
    if (calibration == null) return 'Sin calibración';
    final point = calibration.points.isNotEmpty
        ? calibration.points.last
        : null;
    if (point?.motorAzimuthAtCalibration != null) {
      return _formatUnsigned(point!.motorAzimuthAtCalibration!);
    }
    return _formatSigned(calibration.azimuthOffset);
  }

  String get _calculatedPairText {
    final position = currentPosition;
    if (position == null) return 'Aún no calculado';
    return _formatPair(position.altitudeDeg, position.azimuthDeg);
  }

  String get _correctedPairText {
    final command = previewCommand;
    if (command == null) return 'Aún no calculado';
    return _formatPair(command.finalAltitude, command.finalAzimuth);
  }

  String get _finalCommandText {
    final command = previewCommand;
    if (command == null) return 'Aún no calculado';
    return 'GOTO(${_formatSigned(command.finalAltitude)}, '
        '${_formatUnsigned(command.finalAzimuth)})';
  }

  String _dateText(DateTime? value, {required String fallback}) {
    return value?.toIso8601String() ?? fallback;
  }

  String _formatPair(double altitude, double azimuth) {
    return '${_formatSigned(altitude)} / ${_formatUnsigned(azimuth)}';
  }

  String _formatSigned(double degrees) {
    return CoordinateFormatters.formatSignedDegrees(degrees);
  }

  String _formatUnsigned(double degrees) {
    return CoordinateFormatters.formatUnsignedDegrees(degrees);
  }
}

class _EducationalTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _EducationalTile({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        leading: Icon(icon, color: colorScheme.primary),
        title: Text(title, style: Theme.of(context).textTheme.titleSmall),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        shape: shape,
        collapsedShape: shape,
        children: children,
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  final String text;

  const _BodyText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.bodyMedium);
  }
}

class _SafeNotice extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SafeNotice({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.secondary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.secondary.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.secondary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  final String number;
  final String text;

  const _FlowStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _MetricWrap extends StatelessWidget {
  final List<_EducationalMetric> metrics;

  const _MetricWrap({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final itemWidth = compact
            ? constraints.maxWidth
            : (constraints.maxWidth - 8) / 2;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: itemWidth,
                child: _MetricBox(metric: metric),
              ),
          ],
        );
      },
    );
  }
}

class _MetricBox extends StatelessWidget {
  final _EducationalMetric metric;

  const _MetricBox({required this.metric});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(metric.label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              metric.value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontFamily: 'monospace',
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DataLine extends StatelessWidget {
  final String label;
  final String value;

  const _DataLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label: ',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _EducationalMetric {
  final String label;
  final String value;

  const _EducationalMetric({required this.label, required this.value});
}
