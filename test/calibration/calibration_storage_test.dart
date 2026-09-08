import 'dart:convert';

import 'package:astroprintedlogicincludedgeoengine/features/calibration/data/calibration_storage.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/calibration_method.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/calibration_point.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/calibration_result.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/calibration_stage.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/calibration_status.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/correction_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/services/alignment_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CalibrationStorage storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = CalibrationStorage();
  });

  test('persists multipoint calibration result', () async {
    final result = CalibrationResult(
      altitudeOffset: 1.5,
      azimuthOffset: -3.25,
      stage: CalibrationStage.correctionCalibration,
      correctionModel: CorrectionModel.threeStarCorrection,
      method: CalibrationMethod.threeStars,
      status: CalibrationStatus.calibratedThreeStars,
      points: [
        _point('star_a', 'Star A'),
        _point('star_b', 'Star B'),
        _point('star_c', 'Star C'),
      ],
      warnings: const ['Advertencia: referencia cercana.'],
      createdAt: DateTime.utc(2026, 6, 3, 12),
    );

    await storage.saveCorrectionCalibrationResult(result);
    final loaded = await storage.loadCorrectionCalibrationResult();

    expect(loaded, isNotNull);
    expect(loaded!.method, CalibrationMethod.threeStars);
    expect(loaded.status, CalibrationStatus.calibratedThreeStars);
    expect(loaded.points, hasLength(3));
    expect(loaded.points.first.objectId, 'star_a');
    expect(loaded.warnings, ['Advertencia: referencia cercana.']);
    expect(loaded.altitudeOffset, 1.5);
    expect(loaded.azimuthOffset, -3.25);
  });

  test(
    'old saved references without a connection session are invalid',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'astropilot.calibration.current',
        jsonEncode({
          'altitudeOffset': 2.0,
          'azimuthOffset': -4.0,
          'method': 'twoStars',
          'points': [
            {
              'objectName': 'Legacy Star',
              'calculatedAltitude': 30.0,
              'calculatedAzimuth': 40.0,
              'adjustedAltitude': 29.0,
              'adjustedAzimuth': 41.0,
              'altitudeError': 1.0,
              'azimuthError': -1.0,
              'timestamp': DateTime.utc(2026).toIso8601String(),
            },
          ],
          'createdAt': DateTime.utc(2026, 1, 2).toIso8601String(),
        }),
      );

      final loaded = await storage.loadCorrectionCalibrationResult();

      expect(loaded, isNull);
    },
  );

  test('a new connection invalidates saved alignment and correction', () async {
    final result = CalibrationResult(
      altitudeOffset: 0,
      azimuthOffset: 0,
      stage: CalibrationStage.initialAlignment,
      correctionModel: CorrectionModel.none,
      method: CalibrationMethod.oneStar,
      status: CalibrationStatus.calibrated,
      points: [_point('star', 'Star')],
      createdAt: DateTime.now(),
    );
    await storage.saveInitialAlignmentResult(result);
    expect(await storage.loadInitialAlignmentResult(), isNotNull);
    AlignmentSession.invalidate();
    expect(await storage.loadInitialAlignmentResult(), isNull);
  });
}

CalibrationPoint _point(String objectId, String objectName) {
  return CalibrationPoint(
    objectId: objectId,
    objectName: objectName,
    calculatedAltitude: 30,
    calculatedAzimuth: 40,
    adjustedAltitude: 29,
    adjustedAzimuth: 39,
    altitudeError: 1,
    azimuthError: 1,
    timestamp: DateTime.utc(2026),
  );
}
