class CalibrationPoint {
  final String objectName;
  final double calculatedAltitude;
  final double calculatedAzimuth;
  final double adjustedAltitude;
  final double adjustedAzimuth;
  final double altitudeError;
  final double azimuthError;
  final DateTime timestamp;

  const CalibrationPoint({
    required this.objectName,
    required this.calculatedAltitude,
    required this.calculatedAzimuth,
    required this.adjustedAltitude,
    required this.adjustedAzimuth,
    required this.altitudeError,
    required this.azimuthError,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'objectName': objectName,
      'calculatedAltitude': calculatedAltitude,
      'calculatedAzimuth': calculatedAzimuth,
      'adjustedAltitude': adjustedAltitude,
      'adjustedAzimuth': adjustedAzimuth,
      'altitudeError': altitudeError,
      'azimuthError': azimuthError,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }

  factory CalibrationPoint.fromJson(Map<String, dynamic> json) {
    return CalibrationPoint(
      objectName: json['objectName'] as String? ?? 'Objeto desconocido',
      calculatedAltitude: _readDouble(json, 'calculatedAltitude'),
      calculatedAzimuth: _readDouble(json, 'calculatedAzimuth'),
      adjustedAltitude: _readDoubleAny(
        json,
        'adjustedAltitude',
        'centeredAltitude',
      ),
      adjustedAzimuth: _readDoubleAny(
        json,
        'adjustedAzimuth',
        'centeredAzimuth',
      ),
      altitudeError: _readDouble(json, 'altitudeError'),
      azimuthError: _readDouble(json, 'azimuthError'),
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  static double _readDouble(Map<String, dynamic> json, String key) {
    return (json[key] as num?)?.toDouble() ?? 0.0;
  }

  static double _readDoubleAny(
    Map<String, dynamic> json,
    String preferredKey,
    String fallbackKey,
  ) {
    return (json[preferredKey] as num?)?.toDouble() ??
        (json[fallbackKey] as num?)?.toDouble() ??
        0.0;
  }
}
