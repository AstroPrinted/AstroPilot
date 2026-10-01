import 'package:flutter/material.dart';

import '../../../catalog/domain/models/celestial_object.dart';
import '../../../catalog/presentation/utils/coordinate_formatters.dart';

/// Textos e íconos de un objeto del catálogo, compartidos por las listas y
/// fichas de Observación y Educativo.
abstract final class ObjectDisplay {
  static IconData icon(CelestialObject object) => switch (object) {
    SolarSystemBody() => Icons.public,
    DeepSkyObject() => Icons.travel_explore,
    CalibrationStar() => Icons.auto_awesome,
  };

  static bool isSun(CelestialObject object) =>
      object is SolarSystemBody && object.isSun;

  static String? magnitude(CelestialObject object) => switch (object) {
    final SolarSystemBody body => body.getDynamicMagnitude(
      DateTime.now().toUtc(),
    ),
    _ => object.magnitude,
  };

  static String typeLabel(CelestialObject object) => switch (object) {
    SolarSystemBody() => 'Sistema Solar',
    final DeepSkyObject o => o.objectType,
    CalibrationStar() => 'Estrella',
  };

  static String? constellation(CelestialObject object) => switch (object) {
    final DeepSkyObject o =>
      o.constellations.isEmpty ? null : o.constellations.join(', '),
    final CalibrationStar s => s.constellation,
    SolarSystemBody() => null,
  };

  /// "Nebulosa · M42, NGC 1976 · Orión" / "Estrella · Mag: 0.8 · Crux".
  static String subtitle(CelestialObject object) {
    final parts = <String>[typeLabel(object)];
    if (object is DeepSkyObject) {
      if (object.catalogs.isNotEmpty) parts.add(object.catalogs.join(', '));
    } else {
      final mag = magnitude(object);
      if (mag != null) parts.add('Mag: $mag');
    }
    final constellation = ObjectDisplay.constellation(object);
    if (constellation != null) parts.add(constellation);
    return parts.join(' · ');
  }

  /// "AR 05h 35m 17s · Dec -05° 23' 28"" para objetos con coordenadas fijas.
  static String? j2000(CelestialObject object) {
    final coordinates = j2000Parts(object);
    if (coordinates == null) return null;
    return 'AR ${coordinates.ra} · Dec ${coordinates.dec}';
  }

  static ({String ra, String dec})? j2000Parts(CelestialObject object) {
    final (ra, dec) = switch (object) {
      final DeepSkyObject o => (o.raJ2000Hours, o.decJ2000Degrees),
      final CalibrationStar s => (s.raJ2000Hours, s.decJ2000Degrees),
      SolarSystemBody() => (null, null),
    };
    if (ra == null || dec == null) return null;
    return (
      ra: CoordinateFormatters.formatRightAscension(ra),
      dec: CoordinateFormatters.formatDeclination(dec),
    );
  }

  /// Nombre corto para la barra superior ("M42" para la Nebulosa de Orión).
  static String shortName(CelestialObject object) {
    if (object is DeepSkyObject) {
      final messier = object.catalogs.firstWhere(
        (c) => RegExp(r'^M\s?\d+$').hasMatch(c),
        orElse: () => '',
      );
      if (messier.isNotEmpty) return messier.replaceAll(' ', '');
    }
    return object.name;
  }
}

/// Categorías de los chips de filtro del catálogo.
enum CatalogCategory {
  all('all', 'Todos'),
  solar('solar_system', 'Sist. Solar'),
  deep('deep_sky', 'Cielo Prof.'),
  stars('stars', 'Estrellas');

  final String key;
  final String label;
  const CatalogCategory(this.key, this.label);
}
