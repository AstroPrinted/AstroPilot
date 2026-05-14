import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geoengine/geoengine.dart';

import '../../domain/models/celestial_object.dart';

class CelestialCatalogRepository {
  static final CelestialCatalogRepository _instance =
      CelestialCatalogRepository._();
  factory CelestialCatalogRepository() => _instance;
  CelestialCatalogRepository._();

  static const _assetPath = 'assets/celestial_catalog.json';

  List<CelestialObject>? _catalog;

  Future<void> initialize() async {
    if (_catalog != null) {
      return;
    }

    final jsonObjects = <CelestialObject>[];

    try {
      final raw = await rootBundle.loadString(_assetPath);
      final map = json.decode(raw) as Map<String, dynamic>;

      final deepSky = (map['deep_sky_objects'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(_parseDeepSky)
          .toList();

      final stars = (map['calibration_targets'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(_parseCalibrationStar)
          .toList();

      jsonObjects
        ..addAll(deepSky)
        ..addAll(stars);
    } on FlutterError catch (e) {
      debugPrint('Catalog asset missing: $e');
    } on FormatException catch (e) {
      debugPrint('Catalog JSON format error: $e');
    } catch (e) {
      debugPrint('Catalog load error: $e');
    }

    final solarSystem = _buildSolarSystemBodies();
    _catalog = _mergeAndSort(solarSystem, jsonObjects);
  }

  List<CelestialObject> getAllObjects() {
    _ensureInitialized();
    return List.unmodifiable(_catalog!);
  }

  List<CelestialObject> getByCategory(String category) {
    _ensureInitialized();

    final all = _catalog!;
    switch (category) {
      case 'solar_system':
        return all.whereType<SolarSystemBody>().toList(growable: false);
      case 'deep_sky':
        return all.whereType<DeepSkyObject>().toList(growable: false);
      case 'stars':
        return all.whereType<CalibrationStar>().toList(growable: false);
      default:
        return List.unmodifiable(all);
    }
  }

  List<CelestialObject> searchByName(String query, {String category = 'all'}) {
    final source = getByCategory(category);
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return source;
    }

    final normalizedQuery = trimmed.toLowerCase();
    return source
        .where((obj) => obj.name.toLowerCase().contains(normalizedQuery))
        .toList(growable: false);
  }

  DeepSkyObject _parseDeepSky(Map<String, dynamic> item) {
    final name = item['name'] as String? ?? 'Objeto sin nombre';
    return DeepSkyObject(
      id: 'dso_${_slug(name)}',
      name: name,
      magnitude: _parseMagnitude(item['magnitude_v']),
      objectType: item['object_type'] as String? ?? 'Cielo profundo',
      constellations: (item['constellations'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      raJ2000Hours: (item['right_ascension_hours'] as num?)?.toDouble() ?? 0,
      decJ2000Degrees: (item['declination_degrees'] as num?)?.toDouble() ?? 0,
      catalogs: (item['catalogs'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      notes: item['notes'] as String?,
    );
  }

  CalibrationStar _parseCalibrationStar(Map<String, dynamic> item) {
    final name = item['name'] as String? ?? 'Estrella sin nombre';
    return CalibrationStar(
      id: 'star_${_slug(name)}',
      name: name,
      magnitude: _parseMagnitude(item['magnitude_v']),
      constellation: item['constellation'] as String? ?? 'N/A',
      spectralType: item['spectral_type'] as String? ?? 'N/A',
      raJ2000Hours: (item['right_ascension_hours'] as num?)?.toDouble() ?? 0,
      decJ2000Degrees: (item['declination_degrees'] as num?)?.toDouble() ?? 0,
      catalogs: (item['catalogs'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
    );
  }

  List<SolarSystemBody> _buildSolarSystemBodies() {
    const bodies = <({Body body, String name})>[
      (body: Body.Jupiter, name: 'Jupiter'),
      (body: Body.Moon, name: 'Luna'),
      (body: Body.Mars, name: 'Marte'),
      (body: Body.Mercury, name: 'Mercurio'),
      (body: Body.Neptune, name: 'Neptuno'),
      (body: Body.Pluto, name: 'Pluton'),
      (body: Body.Saturn, name: 'Saturno'),
      (body: Body.Sun, name: 'Sol'),
      (body: Body.Uranus, name: 'Urano'),
      (body: Body.Venus, name: 'Venus'),
    ];

    return bodies
        .map(
          (entry) => SolarSystemBody(
            id: 'solar_${entry.body.name.toLowerCase()}',
            name: entry.name,
            geoengineBody: entry.body,
          ),
        )
        .toList(growable: false);
  }

  List<CelestialObject> _mergeAndSort(
    List<SolarSystemBody> solarSystem,
    List<CelestialObject> jsonObjects,
  ) {
    final deepSky = jsonObjects.whereType<DeepSkyObject>().toList(
      growable: false,
    )..sort((a, b) => a.name.compareTo(b.name));
    final stars = jsonObjects.whereType<CalibrationStar>().toList(
      growable: false,
    )..sort((a, b) => a.name.compareTo(b.name));
    final solarSorted = [...solarSystem]
      ..sort((a, b) => a.name.compareTo(b.name));

    return [...solarSorted, ...deepSky, ...stars];
  }

  String? _parseMagnitude(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
    }
    return value.toString();
  }

  String _slug(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  void _ensureInitialized() {
    if (_catalog == null) {
      throw StateError('Repository not initialized');
    }
  }
}
