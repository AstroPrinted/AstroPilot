import 'calibration_method.dart';
import 'calibration_point.dart';

class CalibrationResult {
  final double altitudeOffset;
  final double azimuthOffset;
  final double? estimatedError;
  final CalibrationMethod method;
  final List<CalibrationPoint> points;
  final DateTime createdAt;

  const CalibrationResult({
    required this.altitudeOffset,
    required this.azimuthOffset,
    required this.method,
    required this.points,
    required this.createdAt,
    this.estimatedError,
  });

  Map<String, dynamic> toJson() {
    return {
      'altitudeOffset': altitudeOffset,
      'azimuthOffset': azimuthOffset,
      'estimatedError': estimatedError,
      'method': method.name,
      'points': points.map((point) => point.toJson()).toList(),
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  factory CalibrationResult.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List<dynamic>? ?? const [];
    return CalibrationResult(
      altitudeOffset: _readDouble(json, 'altitudeOffset'),
      azimuthOffset: _readDouble(json, 'azimuthOffset'),
      estimatedError: (json['estimatedError'] as num?)?.toDouble(),
      method: calibrationMethodFromName(json['method'] as String?),
      points: rawPoints
          .whereType<Map<String, dynamic>>()
          .map(CalibrationPoint.fromJson)
          .toList(growable: false),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }

  static double _readDouble(Map<String, dynamic> json, String key) {
    return (json[key] as num?)?.toDouble() ?? 0.0;
  }
}
