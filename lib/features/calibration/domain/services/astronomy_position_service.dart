import '../../../catalog/domain/models/celestial_object.dart';
import '../../../observation/domain/models/alt_az_result.dart';
import '../../../observation/domain/models/ephemeris_input.dart';
import '../../../observation/domain/models/observer_data.dart';
import '../../../observation/domain/services/ephemeris_engine.dart';

class AstronomyPositionService {
  const AstronomyPositionService();

  AltAzResult calculateForObject({
    required CelestialObject object,
    required ObserverData observer,
  }) {
    return switch (object) {
      final SolarSystemBody body when body.isSun => throw StateError(
        'Coordenadas solares bloqueadas por seguridad ocular.',
      ),
      final SolarSystemBody body => EphemerisEngine.computeSolarBodyAltAz(
        body: body.geoengineBody,
        utc: observer.utc,
        latDeg: observer.latDeg,
        lonDeg: observer.lonDeg,
        heightMeters: observer.heightMeters,
      ),
      final DeepSkyObject deepSkyObject => EphemerisEngine.computeAltAz(
        EphemerisInput(
          raJ2000Hours: deepSkyObject.raJ2000Hours,
          decJ2000Deg: deepSkyObject.decJ2000Degrees,
          utc: observer.utc,
          latDeg: observer.latDeg,
          lonDeg: observer.lonDeg,
          heightMeters: observer.heightMeters,
        ),
      ),
      final CalibrationStar star => calculateForStar(
        star: star,
        observer: observer,
      ),
    };
  }

  AltAzResult calculateForStar({
    required CalibrationStar star,
    required ObserverData observer,
  }) {
    return EphemerisEngine.computeAltAz(
      EphemerisInput(
        raJ2000Hours: star.raJ2000Hours,
        decJ2000Deg: star.decJ2000Degrees,
        utc: observer.utc,
        latDeg: observer.latDeg,
        lonDeg: observer.lonDeg,
        heightMeters: observer.heightMeters,
      ),
    );
  }
}
