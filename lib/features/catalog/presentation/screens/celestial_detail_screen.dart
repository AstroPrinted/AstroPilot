import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../observation/application/ephemeris_service.dart';
import '../../../observation/domain/models/alt_az_result.dart';
import '../../../settings/application/settings_service.dart';
import '../../domain/models/celestial_object.dart';
import '../utils/coordinate_formatters.dart';
import 'celestial_control_screen.dart';

class CelestialDetailScreen extends StatefulWidget {
  final CelestialObject object;

  const CelestialDetailScreen({super.key, required this.object});

  @override
  State<CelestialDetailScreen> createState() => _CelestialDetailScreenState();
}

class _CelestialDetailScreenState extends State<CelestialDetailScreen> {
  late final EphemerisService _ephemerisService;

  bool get _isSun =>
      widget.object is SolarSystemBody &&
      (widget.object as SolarSystemBody).isSun;

  @override
  void initState() {
    super.initState();
    _ephemerisService = EphemerisService(
      observerDataProvider: context.read<SettingsService>(),
    );
    if (!_isSun) {
      _ephemerisService.startTracking(widget.object);
    }
  }

  @override
  void dispose() {
    _ephemerisService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final object = widget.object;
    final solarMagnitude = object is SolarSystemBody
        ? object.getDynamicMagnitude(DateTime.now().toUtc())
        : null;
    final notes = object.notes?.trim();

    return Scaffold(
      appBar: AppBar(title: Text(object.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_isSun) const _SolarSafetyCard(),
          _DataCard(
            title: 'Objeto',
            icon: Icons.auto_awesome_rounded,
            children: [
              _InfoRow(label: 'Nombre', value: object.name),
              _InfoRow(label: 'Tipo', value: _objectTypeLabel(object)),
              _InfoRow(
                label: 'Magnitud',
                value: solarMagnitude ?? object.magnitude ?? 'N/A',
              ),
              ..._buildObjectRows(object),
              if (notes != null && notes.isNotEmpty)
                _InfoRow(label: 'Curiosidad', value: notes),
            ],
          ),
          const SizedBox(height: 14),
          _DataCard(
            title: 'Coordenadas J2000',
            icon: Icons.public_rounded,
            children: _buildJ2000Rows(object),
          ),
          const SizedBox(height: 14),
          _DataCard(
            title: 'Coordenadas Horizontales',
            icon: Icons.explore_rounded,
            accent: Theme.of(context).colorScheme.secondary,
            children: [
              if (_isSun)
                const _BlockedCoordinatesMessage()
              else
                StreamBuilder<AltAzResult>(
                  stream: _ephemerisService.stream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _StatusMessage(
                        icon: Icons.error_outline_rounded,
                        message:
                            'No se pudo calcular Alt/Az: ${snapshot.error}',
                      );
                    }
                    final result = snapshot.data;
                    if (result == null) {
                      return const _StatusMessage(
                        icon: Icons.sync_rounded,
                        message: 'Calculando efemérides...',
                      );
                    }
                    return _HorizontalCoordinatesPanel(result: result);
                  },
                ),
            ],
          ),
          const SizedBox(height: 20),
          _buildOpenControlCard(),
        ],
      ),
    );
  }

  Widget _buildOpenControlCard() {
    return _OpenControlCard(
      onOpen: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CelestialControlScreen(object: widget.object),
        ),
      ),
    );
  }

  List<Widget> _buildObjectRows(CelestialObject object) {
    if (object is DeepSkyObject) {
      return [
        _InfoRow(
          label: 'Constelación',
          value: object.constellations.join(', '),
        ),
        _InfoRow(label: 'Catálogos', value: object.catalogs.join(', ')),
      ];
    }
    if (object is CalibrationStar) {
      return [
        _InfoRow(label: 'Constelación', value: object.constellation),
        _InfoRow(label: 'Tipo espectral', value: object.spectralType),
        _InfoRow(label: 'Catálogos', value: object.catalogs.join(', ')),
      ];
    }
    return const [];
  }

  List<Widget> _buildJ2000Rows(CelestialObject object) {
    if (object is DeepSkyObject) {
      return [
        _CoordinateRow(
          label: 'RA',
          value: CoordinateFormatters.formatRightAscension(object.raJ2000Hours),
        ),
        _CoordinateRow(
          label: 'Dec',
          value: CoordinateFormatters.formatDeclination(object.decJ2000Degrees),
        ),
      ];
    }
    if (object is CalibrationStar) {
      return [
        _CoordinateRow(
          label: 'RA',
          value: CoordinateFormatters.formatRightAscension(object.raJ2000Hours),
        ),
        _CoordinateRow(
          label: 'Dec',
          value: CoordinateFormatters.formatDeclination(object.decJ2000Degrees),
        ),
      ];
    }
    return const [
      _StatusMessage(
        icon: Icons.info_outline_rounded,
        message: 'Los cuerpos del Sistema Solar se calculan dinámicamente.',
      ),
    ];
  }

  String _objectTypeLabel(CelestialObject object) {
    if (object is SolarSystemBody) return 'Sistema Solar';
    if (object is DeepSkyObject) return object.objectType;
    return 'Estrella de Calibración';
  }
}

class _DataCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Color? accent;

  const _DataCard({
    required this.title,
    required this.icon,
    required this.children,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = accent ?? colorScheme.primary;

    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accentColor.withValues(alpha: 0.10),
              colorScheme.surface.withValues(alpha: 0.02),
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accentColor, size: 20),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _HorizontalCoordinatesPanel extends StatelessWidget {
  final AltAzResult result;

  const _HorizontalCoordinatesPanel({required this.result});

  @override
  Widget build(BuildContext context) {
    final visible = result.altitudeDeg >= 0;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Altitud',
                value: CoordinateFormatters.formatSignedArc(result.altitudeDeg),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricTile(
                label: 'Azimut',
                value: CoordinateFormatters.formatUnsignedArc(
                  result.azimuthDeg,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: (visible ? colorScheme.secondary : colorScheme.error)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: (visible ? colorScheme.secondary : colorScheme.error)
                  .withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            children: [
              Icon(
                visible
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                color: visible ? colorScheme.secondary : colorScheme.error,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  visible
                      ? 'Objeto sobre el horizonte'
                      : 'Objeto bajo el horizonte',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'UTC ${result.computedAt.toIso8601String()}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Raw: Alt ${CoordinateFormatters.formatSignedArc(result.altitudeRawDeg)} / Az ${CoordinateFormatters.formatUnsignedArc(result.azimuthRawDeg)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.secondary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontFamily: 'monospace',
                fontFeatures: const [FontFeature.tabularFigures()],
                color: colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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

class _CoordinateRow extends StatelessWidget {
  final String label;
  final String value;

  const _CoordinateRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              fontFeatures: const [FontFeature.tabularFigures()],
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _StatusMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class _BlockedCoordinatesMessage extends StatelessWidget {
  const _BlockedCoordinatesMessage();

  @override
  Widget build(BuildContext context) {
    return _StatusMessage(
      icon: Icons.block_rounded,
      message:
          'Coordenadas solares bloqueadas por seguridad ocular. No se calcula ni se muestra Alt/Az del Sol.',
    );
  }
}

class _SolarSafetyCard extends StatelessWidget {
  const _SolarSafetyCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: colorScheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'ADVERTENCIA DE SEGURIDAD: nunca apuntes el telescopio al Sol sin filtros certificados.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenControlCard extends StatelessWidget {
  final VoidCallback onOpen;

  const _OpenControlCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return _DataCard(
      title: 'Control del telescopio',
      icon: Icons.precision_manufacturing_rounded,
      children: [
        const _StatusMessage(
          icon: Icons.info_outline_rounded,
          message:
              'El GoTo inicial, ajustes finos, STOP y tracking lógico se realizan desde la pantalla de control del objeto.',
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onOpen,
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('Abrir control del objeto'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      ],
    );
  }
}
