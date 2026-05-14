class CoordinateFormatters {
  const CoordinateFormatters._();

  static String formatRightAscension(double hours) {
    final totalSeconds = (hours * 3600).round();
    final normalizedSeconds = totalSeconds.remainder(24 * 3600);
    final positiveSeconds = normalizedSeconds < 0
        ? normalizedSeconds + 24 * 3600
        : normalizedSeconds;

    final h = positiveSeconds ~/ 3600;
    final m = (positiveSeconds % 3600) ~/ 60;
    final s = positiveSeconds % 60;

    return '${_twoDigits(h)}h ${_twoDigits(m)}m ${_twoDigits(s)}s';
  }

  static String formatDeclination(double degrees) {
    final sign = degrees < 0 ? '-' : '+';
    final totalSeconds = (degrees.abs() * 3600).round();
    final d = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;

    return '$sign${_twoDigits(d)}° ${_twoDigits(m)}\' ${_twoDigits(s)}"';
  }

  static String formatSignedArc(double degrees) {
    final sign = degrees >= 0 ? '+' : '-';
    return '$sign${_formatArcParts(degrees.abs())}';
  }

  static String formatUnsignedArc(double degrees) {
    final normalized = degrees % 360;
    final positiveDegrees = normalized < 0 ? normalized + 360 : normalized;
    return _formatArcParts(positiveDegrees);
  }

  static String formatSignedDegrees(double degrees) {
    final sign = degrees >= 0 ? '+' : '-';
    return '$sign${degrees.abs().toStringAsFixed(2)}°';
  }

  static String formatUnsignedDegrees(double degrees) {
    return '${degrees.toStringAsFixed(2)}°';
  }

  static String _formatArcParts(double degrees) {
    final totalTenths = (degrees * 36000).round();
    final d = totalTenths ~/ 36000;
    final remainingTenths = totalTenths % 36000;
    final m = remainingTenths ~/ 600;
    final sTenths = remainingTenths % 600;
    final s = (sTenths / 10).toStringAsFixed(1).padLeft(4, '0');

    return '${_twoDigits(d)}° ${_twoDigits(m)}\' $s"';
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
