class ObserverData {
  final double latDeg;
  final double lonDeg;
  final double heightMeters;
  final DateTime utc;
  final bool isLive;

  const ObserverData({
    required this.latDeg,
    required this.lonDeg,
    required this.heightMeters,
    required this.utc,
    this.isLive = true,
  });
}
