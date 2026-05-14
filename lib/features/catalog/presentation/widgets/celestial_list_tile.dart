import 'package:flutter/material.dart';

import '../../domain/models/celestial_object.dart';

class CelestialListTile extends StatelessWidget {
  final CelestialObject object;
  final VoidCallback onTap;

  const CelestialListTile({
    super.key,
    required this.object,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = _subtitleLines(object);
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
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }

  IconData _iconFor(CelestialObject object) {
    if (object is SolarSystemBody) return Icons.public;
    if (object is DeepSkyObject) return Icons.travel_explore;
    return Icons.auto_awesome;
  }

  String _subtitleLines(CelestialObject object) {
    if (object is SolarSystemBody) {
      final dynamicMagnitude = object.getDynamicMagnitude(DateTime.now().toUtc());
      if (object.isSun) {
        return 'Sistema Solar · Mag: ${dynamicMagnitude ?? 'N/A'}\nAdvertencia: observacion solar bloqueada';
      }
      return 'Sistema Solar\nMagnitud: ${dynamicMagnitude ?? 'N/A'}';
    }

    if (object is DeepSkyObject) {
      final catalogs = object.catalogs.take(2).join(', ');
      final constellation = object.constellations.isNotEmpty
          ? object.constellations.first
          : 'N/A';
      return '$catalogs · Mag: ${object.magnitude ?? 'N/A'}\n${object.objectType} · $constellation';
    }

    final star = object as CalibrationStar;
    final primaryCatalog = star.catalogs.isNotEmpty
        ? star.catalogs.first
        : 'N/A';
    return '$primaryCatalog · Mag: ${star.magnitude ?? 'N/A'}\n${star.spectralType} · ${star.constellation}';
  }
}
