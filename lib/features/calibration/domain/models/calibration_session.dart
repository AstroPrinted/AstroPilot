import 'calibration_method.dart';
import 'calibration_point.dart';
import 'calibration_status.dart';

class CalibrationSession {
  final CalibrationMethod method;
  final CalibrationStatus status;
  final List<CalibrationPoint> points;
  final DateTime startedAt;
  final DateTime? completedAt;

  const CalibrationSession({
    required this.method,
    required this.status,
    required this.points,
    required this.startedAt,
    this.completedAt,
  });

  CalibrationSession copyWith({
    CalibrationMethod? method,
    CalibrationStatus? status,
    List<CalibrationPoint>? points,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return CalibrationSession(
      method: method ?? this.method,
      status: status ?? this.status,
      points: points ?? this.points,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'method': method.name,
      'status': status.name,
      'points': points.map((point) => point.toJson()).toList(),
      'startedAt': startedAt.toUtc().toIso8601String(),
      'completedAt': completedAt?.toUtc().toIso8601String(),
    };
  }

  factory CalibrationSession.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List<dynamic>? ?? const [];
    return CalibrationSession(
      method: calibrationMethodFromName(json['method'] as String?),
      status: calibrationStatusFromName(json['status'] as String?),
      points: rawPoints
          .whereType<Map<String, dynamic>>()
          .map(CalibrationPoint.fromJson)
          .toList(growable: false),
      startedAt:
          DateTime.tryParse(json['startedAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      completedAt: DateTime.tryParse(
        json['completedAt'] as String? ?? '',
      )?.toUtc(),
    );
  }
}
