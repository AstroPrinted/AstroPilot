import 'calibration_method.dart';
import 'calibration_point.dart';
import 'calibration_status.dart';

class CalibrationResult {
  final double altitudeOffset;
  final double azimuthOffset;
  final double? estimatedError;
  final CalibrationMethod method;
  final CalibrationStatus status;
  final List<CalibrationPoint> points;
  final List<String> warnings;
  final DateTime createdAt;

  const CalibrationResult({
    required this.altitudeOffset,
    required this.azimuthOffset,
    required this.method,
    required this.status,
    required this.points,
    required this.createdAt,
    this.warnings = const [],
    this.estimatedError,
  });

  Map<String, dynamic> toJson() {
    return {
      'altitudeOffset': altitudeOffset,
      'azimuthOffset': azimuthOffset,
      'estimatedError': estimatedError,
      'method': method.name,
      'status': status.name,
      'points': points.map((point) => point.toJson()).toList(),
      'warnings': warnings,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  factory CalibrationResult.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List<dynamic>? ?? const [];
    final method = calibrationMethodFromName(json['method'] as String?);
    final rawWarnings = json['warnings'] as List<dynamic>? ?? const [];
    return CalibrationResult(
      altitudeOffset: _readDouble(json, 'altitudeOffset'),
      azimuthOffset: _readDouble(json, 'azimuthOffset'),
      estimatedError: (json['estimatedError'] as num?)?.toDouble(),
      method: method,
      status: json['status'] == null
          ? _statusFor(method)
          : calibrationStatusFromName(json['status'] as String?),
      points: rawPoints
          .whereType<Map<String, dynamic>>()
          .map(CalibrationPoint.fromJson)
          .toList(growable: false),
      warnings: rawWarnings
          .map((warning) => warning.toString())
          .toList(growable: false),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }

  static double _readDouble(Map<String, dynamic> json, String key) {
    return (json[key] as num?)?.toDouble() ?? 0.0;
  }

  static CalibrationStatus _statusFor(CalibrationMethod method) {
    return switch (method) {
      CalibrationMethod.oneStar => CalibrationStatus.calibratedOneStar,
      CalibrationMethod.twoStars => CalibrationStatus.calibratedTwoStars,
      CalibrationMethod.threeStars => CalibrationStatus.calibratedThreeStars,
      CalibrationMethod.fixedObjectSync => CalibrationStatus.localSyncActive,
    };
  }
}
