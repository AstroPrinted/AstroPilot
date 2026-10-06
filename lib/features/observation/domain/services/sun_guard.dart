import 'package:geoengine/geoengine.dart';

import '../models/observer_data.dart';
import '../utils/angle_math.dart';
import 'observer_data_provider.dart';

/// Un movimiento rechazado porque dejaría el telescopio cerca del Sol.
class SunSafetyError extends StateError {
  SunSafetyError(super.message);
}

typedef SunPositionResolver =
    ({double altitude, double azimuth}) Function(
      ObserverData observer,
      DateTime utc,
    );

/// Bloquea los destinos que quedan cerca del Sol.
///
/// Un objeto que está delante o detrás del Sol tiene casi las mismas
/// coordenadas Alt/Az que él, así que apuntarle es apuntar al Sol. La
/// posición del Sol no sale de esta clase: la app no la muestra para que
/// nadie apunte a mano.
class SunGuard {
  /// Separación mínima entre un destino y el Sol. Es amplia a propósito:
  /// cubre el error de la alineación con una estrella y la holgura mecánica.
  static const double exclusionRadiusDeg = 15.0;

  /// Con el Sol por debajo de esta altitud lo tapa el horizonte y no hay
  /// riesgo. El margen cubre la refracción y un horizonte más bajo que el
  /// observador.
  static const double sunHiddenBelowDeg = -2.0;

  final ObserverDataProvider observerDataProvider;
  final SunPositionResolver? sunPositionResolver;
  final DateTime Function()? clock;

  const SunGuard({
    required this.observerDataProvider,
    this.sunPositionResolver,
    this.clock,
  });

  /// Indica si [altitude]/[azimuth] cae dentro de la zona prohibida.
  ///
  /// Sin [at] usa la hora real del dispositivo, no la hora personalizada de
  /// Configuración: el Sol que importa es el que está en el cielo ahora.
  bool isNearSun(double altitude, double azimuth, {DateTime? at}) {
    final observer = observerDataProvider.current();
    final utc = (at ?? clock?.call() ?? DateTime.now()).toUtc();
    final sun = (sunPositionResolver ?? _sunPosition)(observer, utc);
    if (sun.altitude < sunHiddenBelowDeg) return false;
    return sphericalAngularDistance(
          altitude,
          azimuth,
          sun.altitude,
          sun.azimuth,
        ) <
        exclusionRadiusDeg;
  }

  /// Lanza [SunSafetyError] si el destino cae dentro de la zona prohibida.
  /// [what] nombra el destino en el mensaje ("Acrux").
  void ensureSafe(
    double altitude,
    double azimuth, {
    String? what,
    DateTime? at,
  }) {
    if (!isNearSun(altitude, azimuth, at: at)) return;
    throw SunSafetyError(blockedMessage(what: what));
  }

  static String blockedMessage({String? what}) {
    final radius = exclusionRadiusDeg.toStringAsFixed(0);
    return '${what ?? 'Ese destino'} está a menos de $radius° del Sol. Movimiento bloqueado '
        'por seguridad ocular.';
  }

  static ({double altitude, double azimuth}) _sunPosition(
    ObserverData data,
    DateTime utc,
  ) {
    final observer = Observer(data.latDeg, data.lonDeg, data.heightMeters);
    final eq = equator(Body.Sun, utc, observer, true, true);
    final horizontal = HorizontalCoordinates.horizon(
      utc,
      observer,
      eq.ra,
      eq.dec,
      RefractionType.normal,
    );
    return (
      altitude: horizontal.altitude,
      azimuth: normalizeDegrees360(horizontal.azimuth),
    );
  }
}
