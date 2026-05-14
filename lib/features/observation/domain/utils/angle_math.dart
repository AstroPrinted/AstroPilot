import 'dart:math';

double normalizeDegrees360(double value) {
  final normalized = value % 360.0;
  return normalized < 0 ? normalized + 360.0 : normalized;
}

double normalizeHours24(double value) {
  final normalized = value % 24.0;
  return normalized < 0 ? normalized + 24.0 : normalized;
}

double circularAzimuthDiff(double a, double b) {
  final diff = (normalizeDegrees360(a) - normalizeDegrees360(b)).abs();
  return diff <= 180.0 ? diff : 360.0 - diff;
}

double sphericalAngularDistance(
  double alt1Deg,
  double az1Deg,
  double alt2Deg,
  double az2Deg,
) {
  final alt1 = alt1Deg * pi / 180.0;
  final alt2 = alt2Deg * pi / 180.0;
  final az1 = normalizeDegrees360(az1Deg) * pi / 180.0;
  final az2 = normalizeDegrees360(az2Deg) * pi / 180.0;

  final cosD = sin(alt1) * sin(alt2) + cos(alt1) * cos(alt2) * cos(az1 - az2);
  final clamped = cosD.clamp(-1.0, 1.0);
  return acos(clamped) * 180.0 / pi;
}
