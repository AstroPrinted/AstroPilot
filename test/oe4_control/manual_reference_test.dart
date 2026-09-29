import 'dart:async';

import 'package:astroprintedlogicincludedgeoengine/features/calibration/domain/services/alignment_session.dart';
import 'package:astroprintedlogicincludedgeoengine/features/oe4_control/domain/motor_command_service.dart';
import 'package:astroprintedlogicincludedgeoengine/features/oe4_control/presentation/controllers/oe4_control_controller.dart';
import 'package:astroprintedlogicincludedgeoengine/features/oe4_control/presentation/widgets/manual_reference_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'reference changes only after firmware acknowledgement, normalizing north',
    () async {
      final service = _ReferenceService();
      final controller = Oe4ControlController(service);
      addTearDown(controller.dispose);
      final session = AlignmentSession.token;
      final sending = controller.setManualReference('test', alt: 0, az: 360);
      expect(service.coordinates, (0.0, 0.0));
      expect(AlignmentSession.token, session);
      expect(controller.isSending, isTrue);
      service.reply.complete('SET_POSITION');
      await sending;
      expect(AlignmentSession.token, isNot(session));
      expect(controller.isSending, isFalse);
    },
  );

  test(
    'rejection preserves the previous reference and propagates the error',
    () async {
      final service = _ReferenceService();
      final controller = Oe4ControlController(service);
      addTearDown(controller.dispose);
      final session = AlignmentSession.token;
      final sending = controller.setManualReference('test', alt: 0, az: 0);
      final assertion = expectLater(sending, throwsStateError);
      service.reply.completeError(StateError('motores detenidos'));
      await assertion;
      expect(AlignmentSession.token, session);
      expect(controller.errorMessage, contains('motores detenidos'));
    },
  );

  test('invalid values never reach firmware', () async {
    final service = _ReferenceService();
    final controller = Oe4ControlController(service);
    addTearDown(controller.dispose);
    for (final value in [double.nan, double.infinity, -91.0, 91.0]) {
      await expectLater(
        controller.setManualReference('test', alt: value, az: 0),
        throwsArgumentError,
      );
    }
    await expectLater(
      controller.setManualReference('test', alt: 0, az: -3),
      throwsArgumentError,
    );
    expect(service.coordinates, isNull);
  });

  test(
    'late acknowledgement after disconnect cannot confirm a reference',
    () async {
      final service = _ReferenceService();
      final controller = Oe4ControlController(service);
      addTearDown(controller.dispose);
      final sending = controller.setManualReference('test', alt: 0, az: 0);
      final assertion = expectLater(sending, throwsStateError);
      AlignmentSession.invalidate();
      final session = AlignmentSession.token;
      service.reply.complete('SET_POSITION');
      await assertion;
      expect(AlignmentSession.token, session);
      expect(controller.errorMessage, contains('conexión cambió'));
    },
  );

  testWidgets('reference form accepts decimals and waits for confirmation', (
    tester,
  ) async {
    final reply = Completer<void>();
    (double, double)? coordinates;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ManualReferenceCard(
              enabled: true,
              onSetReference: (alt, az) {
                coordinates = (alt, az);
                return reply.future;
              },
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).first, '-3,5');
    await tester.enterText(find.byType(TextFormField).last, '357');
    await tester.ensureVisible(find.text('Fijar coordenadas actuales'));
    await tester.tap(find.text('Fijar coordenadas actuales'));
    await tester.pump();
    expect(coordinates, (-3.5, 357.0));
    expect(find.text('Esperando confirmación…'), findsOneWidget);
    expect(find.textContaining('Referencia confirmada:'), findsNothing);
    reply.complete();
    await tester.pump();
    expect(find.textContaining('Referencia confirmada:'), findsOneWidget);
  });
}

class _ReferenceService extends MotorCommandService {
  final reply = Completer<String>();
  (double, double)? coordinates;

  @override
  Future<String> sendSetPositionCommand(
    String deviceId, {
    required double alt,
    required double az,
  }) {
    coordinates = (alt, az);
    return reply.future;
  }
}
