import 'calibration_method.dart';
import 'calibration_point.dart';
import 'calibration_stage.dart';
import 'calibration_status.dart';
import 'correction_model.dart';

class CalibrationResult {
  final double altitudeOffset;
  final double azimuthOffset;
  final double? estimatedError;
  final CalibrationStage stage;
  final CorrectionModel correctionModel;
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
    required this.stage,
    required this.correctionModel,
    required this.points,
    required this.createdAt,
    this.warnings = const [],
    this.estimatedError,
  });

  bool get isInitialAlignment => stage == CalibrationStage.initialAlignment;

  bool get isCorrectionCalibration =>
      stage == CalibrationStage.correctionCalibration;

  bool get hasCorrectionCalibration =>
      isCorrectionCalibration && correctionModel != CorrectionModel.none;

  CalibrationPoint? get lastReference => points.isEmpty ? null : points.last;

  Map<String, dynamic> toJson() {
    return {
      'altitudeOffset': altitudeOffset,
      'azimuthOffset': azimuthOffset,
      'estimatedError': estimatedError,
      'stage': stage.name,
      'correctionModel': correctionModel.name,
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
    final stage = calibrationStageFromName(
      json['stage'] as String?,
      fallback: _stageForLegacyResult(method),
    );
    final correctionModel = correctionModelFromName(
      json['correctionModel'] as String?,
      fallback: correctionModelFor(stage: stage, method: method),
    );
    return CalibrationResult(
      altitudeOffset: _readDouble(json, 'altitudeOffset'),
      azimuthOffset: _readDouble(json, 'azimuthOffset'),
      estimatedError: (json['estimatedError'] as num?)?.toDouble(),
      stage: stage,
      correctionModel: correctionModel,
      method: method,
      status: json['status'] == null
          ? _statusFor(stage, method)
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

  static CalibrationStage _stageForLegacyResult(CalibrationMethod method) {
    return method == CalibrationMethod.oneStar
        ? CalibrationStage.initialAlignment
        : CalibrationStage.correctionCalibration;
  }

  static CalibrationStatus _statusFor(
    CalibrationStage stage,
    CalibrationMethod method,
  ) {
    if (stage == CalibrationStage.initialAlignment) {
      return CalibrationStatus.calibrated;
    }

    return switch (method) {
      CalibrationMethod.oneStar => CalibrationStatus.calibratedOneStar,
      CalibrationMethod.twoStars => CalibrationStatus.calibratedTwoStars,
      CalibrationMethod.threeStars => CalibrationStatus.calibratedThreeStars,
      CalibrationMethod.fixedObjectSync => CalibrationStatus.localSyncActive,
    };
  }
}
