import 'calibration_method.dart';
import 'calibration_point.dart';
import 'calibration_stage.dart';
import 'calibration_status.dart';

class CalibrationSession {
  final CalibrationStage stage;
  final CalibrationMethod method;
  final CalibrationStatus status;
  final List<CalibrationPoint> points;
  final List<String> warnings;
  final DateTime startedAt;
  final DateTime? completedAt;

  const CalibrationSession({
    required this.stage,
    required this.method,
    required this.status,
    required this.points,
    this.warnings = const [],
    required this.startedAt,
    this.completedAt,
  });

  CalibrationSession copyWith({
    CalibrationStage? stage,
    CalibrationMethod? method,
    CalibrationStatus? status,
    List<CalibrationPoint>? points,
    List<String>? warnings,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return CalibrationSession(
      stage: stage ?? this.stage,
      method: method ?? this.method,
      status: status ?? this.status,
      points: points ?? this.points,
      warnings: warnings ?? this.warnings,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stage': stage.name,
      'method': method.name,
      'status': status.name,
      'points': points.map((point) => point.toJson()).toList(),
      'warnings': warnings,
      'startedAt': startedAt.toUtc().toIso8601String(),
      'completedAt': completedAt?.toUtc().toIso8601String(),
    };
  }

  factory CalibrationSession.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List<dynamic>? ?? const [];
    final rawWarnings = json['warnings'] as List<dynamic>? ?? const [];
    final method = calibrationMethodFromName(json['method'] as String?);
    return CalibrationSession(
      stage: calibrationStageFromName(
        json['stage'] as String?,
        fallback: method == CalibrationMethod.oneStar
            ? CalibrationStage.initialAlignment
            : CalibrationStage.correctionCalibration,
      ),
      method: method,
      status: calibrationStatusFromName(json['status'] as String?),
      points: rawPoints
          .whereType<Map<String, dynamic>>()
          .map(CalibrationPoint.fromJson)
          .toList(growable: false),
      warnings: rawWarnings
          .map((warning) => warning.toString())
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
