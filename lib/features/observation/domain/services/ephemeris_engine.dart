import 'dart:math';

import 'package:geoengine/geoengine.dart';

import '../models/alt_az_result.dart';
import '../models/ephemeris_input.dart';
import '../utils/angle_math.dart';

class EphemerisEngine {
  const EphemerisEngine._();

  static AltAzResult computeAltAz(EphemerisInput input) {
    _validateInput(input);

    final utc = input.utc.toUtc();
    final observer = Observer(input.latDeg, input.lonDeg, input.heightMeters);
    final raRad = normalizeHours24(input.raJ2000Hours) * 15.0 * pi / 180.0;
    final decRad = input.decJ2000Deg * pi / 180.0;

    final j2000Vector = <double>[
      cos(decRad) * cos(raRad),
      cos(decRad) * sin(raRad),
      sin(decRad),
    ];

    final astroTime = AstroTime(utc);
    final jNowVector = gyration(
      j2000Vector,
      astroTime,
      PrecessDirection.From2000,
    );

    final xyProjection = sqrt(
      jNowVector[0] * jNowVector[0] + jNowVector[1] * jNowVector[1],
    );
    final raJNowHours = normalizeHours24(
      atan2(jNowVector[1], jNowVector[0]) * 180.0 / pi / 15.0,
    );
    final decJNowDeg = atan2(jNowVector[2], xyProjection) * 180.0 / pi;

    final withRefraction = HorizontalCoordinates.horizon(
      utc,
      observer,
      raJNowHours,
      decJNowDeg,
      RefractionType.normal,
    );
    final withoutRefraction = HorizontalCoordinates.horizon(
      utc,
      observer,
      raJNowHours,
      decJNowDeg,
      RefractionType.airless,
    );

    return AltAzResult(
      altitudeDeg: withRefraction.altitude,
      azimuthDeg: normalizeDegrees360(withRefraction.azimuth),
      altitudeRawDeg: withoutRefraction.altitude,
      azimuthRawDeg: normalizeDegrees360(withoutRefraction.azimuth),
      computedAt: utc,
    );
  }

  static AltAzResult computeSolarBodyAltAz({
    required Body body,
    required DateTime utc,
    required double latDeg,
    required double lonDeg,
    required double heightMeters,
  }) {
    if (body == Body.Sun) {
      throw ArgumentError('Solar coordinates are blocked for safety.');
    }
    if (latDeg < -90.0 || latDeg > 90.0) {
      throw ArgumentError('Lat must be in range [-90, +90]');
    }
    if (lonDeg < -180.0 || lonDeg > 180.0) {
      throw ArgumentError('Lon must be in range [-180, +180]');
    }

    final computedAt = utc.toUtc();
    final observer = Observer(latDeg, lonDeg, heightMeters);
    final eq = equator(body, computedAt, observer, true, true);

    final withRefraction = HorizontalCoordinates.horizon(
      computedAt,
      observer,
      eq.ra,
      eq.dec,
      RefractionType.normal,
    );
    final withoutRefraction = HorizontalCoordinates.horizon(
      computedAt,
      observer,
      eq.ra,
      eq.dec,
      RefractionType.airless,
    );

    return AltAzResult(
      altitudeDeg: withRefraction.altitude,
      azimuthDeg: normalizeDegrees360(withRefraction.azimuth),
      altitudeRawDeg: withoutRefraction.altitude,
      azimuthRawDeg: normalizeDegrees360(withoutRefraction.azimuth),
      computedAt: computedAt,
    );
  }

  static void _validateInput(EphemerisInput input) {
    if (input.decJ2000Deg < -90.0 || input.decJ2000Deg > 90.0) {
      throw ArgumentError('Dec must be in range [-90, +90]');
    }
    if (input.latDeg < -90.0 || input.latDeg > 90.0) {
      throw ArgumentError('Lat must be in range [-90, +90]');
    }
    if (input.lonDeg < -180.0 || input.lonDeg > 180.0) {
      throw ArgumentError('Lon must be in range [-180, +180]');
    }
  }
}
