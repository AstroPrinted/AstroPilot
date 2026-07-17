import 'package:flutter/material.dart';

import '../../domain/models/celestial_object.dart';
import '../../domain/models/visible_celestial_object.dart';
import '../utils/coordinate_formatters.dart';

class CelestialListTile extends StatelessWidget {
  final CelestialObject object;
  final VisibleCelestialObject? visibleInfo;
  final VoidCallback onTap;

  const CelestialListTile({
    super.key,
    required this.object,
    this.visibleInfo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = visibleInfo == null
        ? _subtitleLines(object)
        : _visibleSubtitleLines(visibleInfo!);
    final icon = _iconFor(object);
    final isSun =
        object is SolarSystemBody && (object as SolarSystemBody).isSun;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(icon, size: 18),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              object.name,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (isSun)
            Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.error,
              size: 18,
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ),
      trailing: visibleInfo == null
          ? const Icon(Icons.chevron_right_rounded)
          : _VisibilityBadge(info: visibleInfo!),
    );
  }

  IconData _iconFor(CelestialObject object) {
    if (object is SolarSystemBody) return Icons.public;
    if (object is DeepSkyObject) return Icons.travel_explore;
    return Icons.auto_awesome;
  }

  String _subtitleLines(CelestialObject object) {
    if (object is SolarSystemBody) {
      final dynamicMagnitude = object.getDynamicMagnitude(
        DateTime.now().toUtc(),
      );
      if (object.isSun) {
        return 'Sistema Solar · Mag: ${dynamicMagnitude ?? 'N/A'}\nAdvertencia: observación solar bloqueada';
      }
      return 'Sistema Solar\nMagnitud: ${dynamicMagnitude ?? 'N/A'}';
    }

    if (object is DeepSkyObject) {
      final catalogs = object.catalogs.take(2).join(', ');
      final constellation = object.constellations.isNotEmpty
          ? object.constellations.first
          : 'N/A';
      return '${object.objectType} · $constellation\n$catalogs · Mag: ${object.magnitude ?? 'N/A'}';
    }

    final star = object as CalibrationStar;
    final primaryCatalog = star.catalogs.isNotEmpty
        ? star.catalogs.first
        : 'N/A';
    return 'Estrella de calibración · ${star.constellation}\n$primaryCatalog · Mag: ${star.magnitude ?? 'N/A'} · ${star.spectralType}';
  }

  String _visibleSubtitleLines(VisibleCelestialObject info) {
    final position = info.position;
    if (position == null) {
      return '${_typeSummary(info.object)}\n${info.blockedReason ?? 'Sin coordenadas'}';
    }

    final horizon = info.isNearHorizon
        ? 'Muy cerca del horizonte'
        : 'Sobre el horizonte';
    return 'Alt ${CoordinateFormatters.formatSignedDegrees(position.altitudeDeg)} · '
        'Az ${CoordinateFormatters.formatUnsignedDegrees(position.azimuthDeg)}\n'
        '${_typeSummary(info.object)} · $horizon';
  }

  String _typeSummary(CelestialObject object) {
    if (object is SolarSystemBody) return 'Sistema Solar';
    if (object is DeepSkyObject) return object.objectType;
    return 'Estrella de calibración';
  }
}

class _VisibilityBadge extends StatelessWidget {
  final VisibleCelestialObject info;

  const _VisibilityBadge({required this.info});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = info.isNearHorizon
        ? colorScheme.tertiary
        : colorScheme.secondary;

    return Tooltip(
      message: info.isNearHorizon
          ? 'Visible, pero entre 0 y 5 grados de altitud'
          : 'Visible',
      child: Icon(
        info.isNearHorizon
            ? Icons.warning_amber_rounded
            : Icons.visibility_rounded,
        color: color,
        size: 20,
      ),
    );
  }
}
