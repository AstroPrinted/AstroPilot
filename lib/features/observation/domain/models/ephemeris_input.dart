class EphemerisInput {
  final double raJ2000Hours;
  final double decJ2000Deg;
  final DateTime utc;
  final double latDeg;
  final double lonDeg;
  final double heightMeters;

  const EphemerisInput({
    required this.raJ2000Hours,
    required this.decJ2000Deg,
    required this.utc,
    required this.latDeg,
    required this.lonDeg,
    required this.heightMeters,
  });
}
