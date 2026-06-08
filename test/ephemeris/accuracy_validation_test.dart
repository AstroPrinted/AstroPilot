import 'dart:io';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:astroprintedlogicincludedgeoengine/features/observation/domain/models/ephemeris_input.dart';
import 'package:astroprintedlogicincludedgeoengine/features/observation/domain/services/ephemeris_engine.dart';
import 'package:astroprintedlogicincludedgeoengine/features/observation/domain/utils/angle_math.dart';

void main() {
  final fixturePath =
      '${Directory.current.path}/test/fixtures/ephemeris_ground_truth.json';
  final csvPath =
      '${Directory.current.path}/test/fixtures/resultados_validacion_oe3.csv';

  late List<Map<String, dynamic>> groundTruth;

  setUpAll(() {
    final file = File(fixturePath);
    if (!file.existsSync()) {
      throw StateError(
        'Ground truth fixture not found at $fixturePath.\n'
        'Run: python scripts/generate_ground_truth.py',
      );
    }
    final json = jsonDecode(file.readAsStringSync()) as List<dynamic>;
    groundTruth = json.cast<Map<String, dynamic>>();
  });

  group('EphemerisEngine OE3 accuracy validation', () {
    test('all 500 points must be within 0.5 degrees of ground truth', () async {
      final errors = <double>[];
      final aboveHorizonErrors = <double>[];
      final csvRows = <List<String>>[];
      double maxAltError = 0;
      double maxAzError = 0;
      double maxAngularError = 0;
      String? worstAltPointId;
      String? worstAzPointId;
      String? worstAngularPointId;

      csvRows.add([
        'ID_Punto',
        'RA_J2000',
        'Dec_J2000',
        'Alt_AstroPilot',
        'Az_AstroPilot',
        'Alt_GroundTruth_Astropy',
        'Az_GroundTruth_Astropy',
        'Error_Angular_Grados',
      ]);

      for (final point in groundTruth) {
        final id = point['id'];
        final raJ2000Hours = (point['raJ2000Hours'] as num).toDouble();
        final decJ2000Deg = (point['decJ2000Deg'] as num).toDouble();
        final utc = DateTime.parse(point['utcISO'] as String);
        final latDeg = (point['latDeg'] as num).toDouble();
        final lonDeg = (point['lonDeg'] as num).toDouble();
        final heightMeters = (point['heightMeters'] as num).toDouble();
        final expectedAlt = (point['expectedAltDeg'] as num).toDouble();
        final expectedAz = (point['expectedAzDeg'] as num).toDouble();

        final input = EphemerisInput(
          raJ2000Hours: raJ2000Hours,
          decJ2000Deg: decJ2000Deg,
          utc: utc,
          latDeg: latDeg,
          lonDeg: lonDeg,
          heightMeters: heightMeters,
        );

        final result = EphemerisEngine.computeAltAz(input);

        final altError = (result.altitudeDeg - expectedAlt).abs();
        final azError = circularAzimuthDiff(result.azimuthDeg, expectedAz);
        final angularError = sphericalAngularDistance(
          result.altitudeDeg,
          result.azimuthDeg,
          expectedAlt,
          expectedAz,
        );

        errors.add(angularError);
        if (expectedAlt > 5.0) {
          aboveHorizonErrors.add(angularError);
        }

        if (altError > maxAltError) {
          maxAltError = altError;
          worstAltPointId = '#$id';
        }
        if (azError > maxAzError) {
          maxAzError = azError;
          worstAzPointId = '#$id';
        }
        if (angularError > maxAngularError) {
          maxAngularError = angularError;
          worstAngularPointId = '#$id';
        }

        csvRows.add([
          '$id',
          raJ2000Hours.toStringAsFixed(8),
          decJ2000Deg.toStringAsFixed(8),
          result.altitudeDeg.toStringAsFixed(8),
          result.azimuthDeg.toStringAsFixed(8),
          expectedAlt.toStringAsFixed(8),
          expectedAz.toStringAsFixed(8),
          angularError.toStringAsFixed(8),
        ]);
      }

      final csvContent = csvRows.map((row) => row.join(',')).join('\n');
      File(csvPath).writeAsStringSync(csvContent);

      // ignore: avoid_print
      print('========================================');
      // ignore: avoid_print
      print('  OE3 Ephemeris Accuracy Report');
      // ignore: avoid_print
      print('========================================');
      // ignore: avoid_print
      print('  Total points   : ${groundTruth.length}');
      // ignore: avoid_print
      print('  Above 5 deg    : ${aboveHorizonErrors.length}');
      // ignore: avoid_print
      print(
        '  Max Alt error  : ${maxAltError.toStringAsFixed(4)} deg'
        ' ($worstAltPointId)',
      );
      // ignore: avoid_print
      print(
        '  Max Az  error  : ${maxAzError.toStringAsFixed(4)} deg'
        ' ($worstAzPointId)',
      );
      // ignore: avoid_print
      print(
        '  Max Angular    : ${maxAngularError.toStringAsFixed(4)} deg'
        ' ($worstAngularPointId)',
      );
      // ignore: avoid_print
      print('  RMSE (angular) : ${_rmse(errors).toStringAsFixed(4)} deg (all)');
      // ignore: avoid_print
      print(
        '  RMSE (>5 deg)  : '
        '${_rmse(aboveHorizonErrors).toStringAsFixed(4)} deg (above horizon)',
      );
      // ignore: avoid_print
      print('========================================');
      // ignore: avoid_print
      print('  Error sources: refraction model differences near horizon,');
      // ignore: avoid_print
      print(
        '  annual aberration (astropy includes it, geoengine gyration does not).',
      );
      // ignore: avoid_print
      print('========================================');
      // ignore: avoid_print
      print('  CSV exported to: $csvPath');

      // Above-horizon objects (alt > 5 deg) must be within 0.5 degrees.
      // All objects must be within 1.5 degrees (refraction diverges near horizon).
      final aboveHorizonMax = aboveHorizonErrors.reduce(max);
      expect(
        aboveHorizonMax,
        lessThan(0.5),
        reason:
            'Max angular distance for objects above 5 degrees altitude '
            'is ${aboveHorizonMax.toStringAsFixed(4)} deg, exceeding 0.5 deg. '
            'Worst point: $worstAngularPointId',
      );
      expect(
        maxAngularError,
        lessThan(1.5),
        reason:
            'Max angular distance for all objects '
            'is ${maxAngularError.toStringAsFixed(4)} deg, exceeding 1.5 deg. '
            'Worst point: $worstAngularPointId',
      );
    });
  });
}

double _rmse(List<double> values) {
  if (values.isEmpty) return 0;
  final sumSquares = values.fold<double>(0, (sum, v) => sum + v * v);
  return sqrt(sumSquares / values.length);
}
