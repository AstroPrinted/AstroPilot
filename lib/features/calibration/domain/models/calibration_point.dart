class CalibrationPoint {
  final String objectId;
  final String objectName;
  final double calculatedAltitude;
  final double calculatedAzimuth;
  final double adjustedAltitude;
  final double adjustedAzimuth;
  final double altitudeError;
  final double azimuthError;
  final double? referenceRaJ2000Hours;
  final double? referenceDecJ2000Degrees;
  final double? motorAltitudeAtCalibration;
  final double? motorAzimuthAtCalibration;
  final DateTime timestamp;

  const CalibrationPoint({
    required this.objectId,
    required this.objectName,
    required this.calculatedAltitude,
    required this.calculatedAzimuth,
    required this.adjustedAltitude,
    required this.adjustedAzimuth,
    required this.altitudeError,
    required this.azimuthError,
    required this.timestamp,
    this.referenceRaJ2000Hours,
    this.referenceDecJ2000Degrees,
    this.motorAltitudeAtCalibration,
    this.motorAzimuthAtCalibration,
  });

  Map<String, dynamic> toJson() {
    return {
      'objectId': objectId,
      'objectName': objectName,
      'calculatedAltitude': calculatedAltitude,
      'calculatedAzimuth': calculatedAzimuth,
      'adjustedAltitude': adjustedAltitude,
      'adjustedAzimuth': adjustedAzimuth,
      'altitudeError': altitudeError,
      'azimuthError': azimuthError,
      'referenceRaJ2000Hours': referenceRaJ2000Hours,
      'referenceDecJ2000Degrees': referenceDecJ2000Degrees,
      'motorAltitudeAtCalibration': motorAltitudeAtCalibration,
      'motorAzimuthAtCalibration': motorAzimuthAtCalibration,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }

  factory CalibrationPoint.fromJson(Map<String, dynamic> json) {
    final objectName = json['objectName'] as String? ?? 'Objeto desconocido';
    return CalibrationPoint(
      objectId: json['objectId'] as String? ?? objectName,
      objectName: objectName,
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
      referenceRaJ2000Hours: _readNullableDouble(json, 'referenceRaJ2000Hours'),
      referenceDecJ2000Degrees: _readNullableDouble(
        json,
        'referenceDecJ2000Degrees',
      ),
      motorAltitudeAtCalibration: _readNullableDouble(
        json,
        'motorAltitudeAtCalibration',
      ),
      motorAzimuthAtCalibration: _readNullableDouble(
        json,
        'motorAzimuthAtCalibration',
      ),
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

  static double? _readNullableDouble(Map<String, dynamic> json, String key) {
    return (json[key] as num?)?.toDouble();
  }
}
