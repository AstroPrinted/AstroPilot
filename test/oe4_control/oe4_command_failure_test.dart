import 'dart:async';

import 'package:astroprintedlogicincludedgeoengine/features/oe4_control/domain/motor_command_service.dart';
import 'package:astroprintedlogicincludedgeoengine/features/oe4_control/presentation/controllers/oe4_control_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'checked SET_POSITION propagates firmware rejection to calibration',
    () async {
      final service = _MotorService();
      final controller = Oe4ControlController(service);
      addTearDown(controller.dispose);
      await expectLater(
        controller.sendSetPosition(
          'test',
          alt: 45,
          az: 120,
          throwOnError: true,
        ),
        throwsStateError,
      );
      expect(controller.errorMessage, contains('motores detenidos'));
      expect(controller.isSending, isFalse);
    },
  );

  test(
    'STOP remains available while a movement is awaiting completion',
    () async {
      final service = _MotorService();
      final controller = Oe4ControlController(service);
      addTearDown(controller.dispose);
      final moving = controller.sendGoto(
        'test',
        alt: 45,
        az: 120,
        throwOnError: true,
      );
      final failedMove = expectLater(moving, throwsStateError);
      expect(controller.isSending, isTrue);
      await controller.sendStop('test');
      await failedMove;
      expect(service.stopped, isTrue);
      expect(controller.isSending, isFalse);
      expect(controller.lastSentCommand, 'STOP');
    },
  );
}

class _MotorService extends MotorCommandService {
  final movement = Completer<String>();
  bool stopped = false;

  @override
  Future<String> sendSetPositionCommand(
    String deviceId, {
    required double alt,
    required double az,
  }) async {
    throw StateError('ERROR: SET_POSITION requiere motores detenidos');
  }

  @override
  Future<String> sendGotoCommand(
    String deviceId, {
    required double alt,
    required double az,
  }) => movement.future;

  @override
  Future<String> sendStopCommand(String deviceId) async {
    stopped = true;
    movement.completeError(StateError('ERROR: movimiento cancelado por STOP'));
    return 'STOP';
  }
}
