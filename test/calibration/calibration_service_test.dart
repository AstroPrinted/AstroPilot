import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/calibration_method.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/models/calibration_status.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/services/calibration_service.dart';
import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/services/pointing_correction_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = CalibrationService(
    correctionService: PointingCorrectionService(),
  );

  test('one star calibration keeps direct offset', () {
    var session = service.startSession(CalibrationMethod.oneStar);
    final point = service.createPoint(
      objectId: 'star_a',
      objectName: 'Star A',
      calculatedAltitude: 30,
      calculatedAzimuth: 120,
      adjustedAltitude: 27,
      adjustedAzimuth: 110,
    );

    session = service.addPoint(session, point);
    final result = service.completeSession(session);

    expect(result.method, CalibrationMethod.oneStar);
    expect(result.status, CalibrationStatus.calibratedOneStar);
    expect(result.points, hasLength(1));
    expect(result.altitudeOffset, 3);
    expect(result.azimuthOffset, 10);
  });

  test('two star calibration averages offsets', () {
    var session = service.startSession(CalibrationMethod.twoStars);

    session = service.addPoint(
      session,
      service.createPoint(
        objectId: 'star_a',
        objectName: 'Star A',
        calculatedAltitude: 30,
        calculatedAzimuth: 20,
        adjustedAltitude: 28,
        adjustedAzimuth: 15,
      ),
    );
    session = service.addPoint(
      session,
      service.createPoint(
        objectId: 'star_b',
        objectName: 'Star B',
        calculatedAltitude: 50,
        calculatedAzimuth: 350,
        adjustedAltitude: 53,
        adjustedAzimuth: 10,
      ),
    );

    final result = service.completeSession(session);

    expect(result.method, CalibrationMethod.twoStars);
    expect(result.status, CalibrationStatus.calibratedTwoStars);
    expect(result.points, hasLength(2));
    expect(result.altitudeOffset, closeTo(-0.5, 0.0001));
    expect(result.azimuthOffset, closeTo(-7.5, 0.0001));
  });

  test('three star calibration averages offsets', () {
    var session = service.startSession(CalibrationMethod.threeStars);

    for (final point in [
      service.createPoint(
        objectId: 'star_a',
        objectName: 'Star A',
        calculatedAltitude: 30,
        calculatedAzimuth: 20,
        adjustedAltitude: 28,
        adjustedAzimuth: 15,
      ),
      service.createPoint(
        objectId: 'star_b',
        objectName: 'Star B',
        calculatedAltitude: 50,
        calculatedAzimuth: 100,
        adjustedAltitude: 46,
        adjustedAzimuth: 110,
      ),
      service.createPoint(
        objectId: 'star_c',
        objectName: 'Star C',
        calculatedAltitude: 40,
        calculatedAzimuth: 200,
        adjustedAltitude: 43,
        adjustedAzimuth: 185,
      ),
    ]) {
      session = service.addPoint(session, point);
    }

    final result = service.completeSession(session);

    expect(result.method, CalibrationMethod.threeStars);
    expect(result.status, CalibrationStatus.calibratedThreeStars);
    expect(result.points, hasLength(3));
    expect(result.altitudeOffset, closeTo(1, 0.0001));
    expect(result.azimuthOffset, closeTo(10 / 3, 0.0001));
  });

  test('does not allow repeating a star in one session', () {
    var session = service.startSession(CalibrationMethod.twoStars);
    session = service.addPoint(
      session,
      service.createPoint(
        objectId: 'star_a',
        objectName: 'Star A',
        calculatedAltitude: 30,
        calculatedAzimuth: 120,
        adjustedAltitude: 29,
        adjustedAzimuth: 119,
      ),
    );

    expect(
      () => service.addPoint(
        session,
        service.createPoint(
          objectId: 'star_a',
          objectName: 'Star A',
          calculatedAltitude: 45,
          calculatedAzimuth: 160,
          adjustedAltitude: 44,
          adjustedAzimuth: 159,
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });
}
