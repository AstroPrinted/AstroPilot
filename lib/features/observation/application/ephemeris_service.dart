import 'dart:async';

import '../../catalog/domain/models/celestial_object.dart';
import '../domain/models/alt_az_result.dart';
import '../domain/models/ephemeris_input.dart';
import '../domain/services/ephemeris_engine.dart';
import '../domain/services/observer_data_provider.dart';

class EphemerisService {
  final ObserverDataProvider observerDataProvider;

  Timer? _timer;
  CelestialObject? _currentObject;
  final StreamController<AltAzResult> _controller =
      StreamController<AltAzResult>.broadcast();

  EphemerisService({required this.observerDataProvider});

  Stream<AltAzResult> get stream => _controller.stream;

  void startTracking(CelestialObject object) {
    stopTracking();
    _currentObject = object;
    _emitOnce();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _emitOnce());
  }

  void stopTracking() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stopTracking();
    _controller.close();
  }

  void _emitOnce() {
    final object = _currentObject;
    if (object == null || _controller.isClosed) return;

    try {
      final observer = observerDataProvider.current();
      final result = switch (object) {
        final SolarSystemBody body when body.isSun => throw StateError(
          'Solar coordinates are blocked for safety.',
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
        final CalibrationStar star => EphemerisEngine.computeAltAz(
          EphemerisInput(
            raJ2000Hours: star.raJ2000Hours,
            decJ2000Deg: star.decJ2000Degrees,
            utc: observer.utc,
            latDeg: observer.latDeg,
            lonDeg: observer.lonDeg,
            heightMeters: observer.heightMeters,
          ),
        ),
      };

      _controller.add(result);
    } catch (error, stackTrace) {
      _controller.addError(error, stackTrace);
    }
  }
}
