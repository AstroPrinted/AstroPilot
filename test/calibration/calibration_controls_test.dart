import 'package:astroprintedlogicincludedgeoengine/features/calibration/presentation/widgets/calibration_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'direct movement fields survive parent rebuilds after focus moves',
    (tester) async {
      final submitted = <({double altitude, double azimuth})>[];

      Future<void> pumpControls() {
        return tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CalibrationControls(
                enabled: true,
                adjustedAltitude: 0,
                adjustedAzimuth: 0,
                onNudge: (_) async {},
                onMoveToAdjustment: (altitude, azimuth) async {
                  submitted.add((altitude: altitude, azimuth: azimuth));
                },
              ),
            ),
          ),
        );
      }

      await pumpControls();
      final fields = find.byType(TextField);

      await tester.enterText(fields.at(0), '12.5');
      await tester.tap(fields.at(1));
      await tester.pump();
      await pumpControls();

      expect(tester.widget<TextField>(fields.at(0)).controller?.text, '12.5');

      await tester.enterText(fields.at(1), '33.75');
      await tester.tap(find.text('Mover'));
      await tester.pump();

      expect(submitted, [(altitude: 12.5, azimuth: 33.75)]);
    },
  );

  testWidgets('altitude submitted from keyboard advances to azimuth field', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalibrationControls(
            enabled: true,
            adjustedAltitude: 0,
            adjustedAzimuth: 0,
            onNudge: (_) async {},
            onMoveToAdjustment: (_, _) async {},
          ),
        ),
      ),
    );

    final fields = find.byType(TextField);
    await tester.tap(fields.at(0));
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();

    expect(tester.widget<TextField>(fields.at(1)).focusNode?.hasFocus, isTrue);
  });
}
