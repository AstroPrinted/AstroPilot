import 'package:geoengine/geoengine.dart';

sealed class CelestialObject {
  final String id;
  final String name;
  final String? magnitude;

  const CelestialObject({required this.id, required this.name, this.magnitude});
}

final class DeepSkyObject extends CelestialObject {
  final String objectType;
  final List<String> constellations;
  final double raJ2000Hours;
  final double decJ2000Degrees;
  final List<String> catalogs;
  final String? notes;

  const DeepSkyObject({
    required super.id,
    required super.name,
    super.magnitude,
    required this.objectType,
    required this.constellations,
    required this.raJ2000Hours,
    required this.decJ2000Degrees,
    required this.catalogs,
    this.notes,
  });
}

final class CalibrationStar extends CelestialObject {
  final String constellation;
  final String spectralType;
  final double raJ2000Hours;
  final double decJ2000Degrees;
  final List<String> catalogs;

  const CalibrationStar({
    required super.id,
    required super.name,
    super.magnitude,
    required this.constellation,
    required this.spectralType,
    required this.raJ2000Hours,
    required this.decJ2000Degrees,
    required this.catalogs,
  });
}

final class SolarSystemBody extends CelestialObject {
  final Body geoengineBody;

  const SolarSystemBody({
    required super.id,
    required super.name,
    super.magnitude,
    required this.geoengineBody,
  });

  EquatorialCoordinates getCurrentCoordinates(
    DateTime date,
    Observer observer,
  ) {
    return equator(geoengineBody, date.toUtc(), observer, true, true);
  }

  String? getDynamicMagnitude(DateTime date) {
    try {
      if (geoengineBody == Body.Sun) {
        return '-26.7';
      }
      if (geoengineBody == Body.Moon) {
        return '-12.7';
      }
      if (geoengineBody == Body.Earth ||
          geoengineBody == Body.EMB ||
          geoengineBody == Body.SSB) {
        return null;
      }
      final illuminationInfo = IlluminationInfo.getBodyIllumination(
        geoengineBody,
        date.toUtc(),
      );
      return illuminationInfo.mag.toStringAsFixed(2);
    } catch (_) {
      return null;
    }
  }

  bool get isSun => geoengineBody == Body.Sun;
}
