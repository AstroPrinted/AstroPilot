import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/motor_command_service.dart';

class Oe4ControlController extends ChangeNotifier {
  final MotorCommandService _motorCommandService;
  late final StreamSubscription<String> _responseSubscription;

  bool _isSending = false;
  String? _lastSentCommand;
  String? _lastResponse;
  String? _errorMessage;

  bool get isSending => _isSending;
  String? get lastSentCommand => _lastSentCommand;
  String? get lastResponse => _lastResponse;
  String? get errorMessage => _errorMessage;

  Oe4ControlController(this._motorCommandService) {
    _responseSubscription = _motorCommandService.responseStream.listen((value) {
      _lastResponse = value;
      _errorMessage = null;
      notifyListeners();
    });
  }

  Future<void> sendGoto(
    String deviceId, {
    required double alt,
    required double az,
  }) {
    return _send(
      () => _motorCommandService.sendGotoCommand(deviceId, alt: alt, az: az),
    );
  }

  Future<void> sendHome(String deviceId) {
    return _send(() => _motorCommandService.sendHomeCommand(deviceId));
  }

  Future<void> sendStatus(String deviceId) {
    return _send(() => _motorCommandService.sendStatusCommand(deviceId));
  }

  Future<void> sendStop(String deviceId) {
    return _send(() => _motorCommandService.sendStopCommand(deviceId));
  }

  Future<void> sendTestRoutine(String deviceId) {
    return _send(() => _motorCommandService.sendTestRoutineCommand(deviceId));
  }

  Future<void> _send(Future<String> Function() command) async {
    _isSending = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _lastSentCommand = await command();
    } catch (e) {
      _errorMessage = 'No se pudo enviar comando OE4: $e';
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _responseSubscription.cancel();
    _motorCommandService.dispose();
    super.dispose();
  }
}
