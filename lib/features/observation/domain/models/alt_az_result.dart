class AltAzResult {
  final double altitudeDeg;
  final double azimuthDeg;
  final double altitudeRawDeg;
  final double azimuthRawDeg;
  final DateTime computedAt;

  const AltAzResult({
    required this.altitudeDeg,
    required this.azimuthDeg,
    required this.altitudeRawDeg,
    required this.azimuthRawDeg,
    required this.computedAt,
  });
}
