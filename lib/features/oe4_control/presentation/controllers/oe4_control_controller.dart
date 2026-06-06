import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/motor_command_service.dart';

class Oe4ControlController extends ChangeNotifier {
  static const Duration _heartbeatInterval = Duration(milliseconds: 300);
  static const Duration _rssiInterval = Duration(seconds: 1);

  final MotorCommandService _motorCommandService;
  late final StreamSubscription<String> _responseSubscription;
  Timer? _heartbeatTimer;
  Timer? _rssiTimer;

  bool _isSending = false;
  bool _isTogglingWatchdog = false;
  bool _heartbeatActive = false;
  bool _pingInFlight = false;
  bool _rssiReadInFlight = false;
  bool _rssiUnavailable = false;
  bool _watchdogEnabled = false;
  bool _disposed = false;

  String? _connectedDeviceId;
  String? _lastSentCommand;
  String? _lastResponse;
  String? _errorMessage;
  String? _lastEsp32Alert;
  DateTime? _lastPongReceivedAt;
  int? _currentRssi;

  bool get isSending => _isSending;
  bool get isTogglingWatchdog => _isTogglingWatchdog;
  bool get heartbeatActive => _heartbeatActive;
  bool get watchdogEnabled => _watchdogEnabled;
  bool get rssiUnavailable => _rssiUnavailable;
  String? get lastSentCommand => _lastSentCommand;
  String? get lastResponse => _lastResponse;
  String? get errorMessage => _errorMessage;
  String? get lastEsp32Alert => _lastEsp32Alert;
  DateTime? get lastPongReceivedAt => _lastPongReceivedAt;
  int? get currentRssi => _currentRssi;

  Oe4ControlController(this._motorCommandService) {
    _responseSubscription = _motorCommandService.responseStream.listen((value) {
      if (_isPongResponse(value)) {
        _lastPongReceivedAt = DateTime.now();
        _safeNotify();
        return;
      }

      _lastResponse = value;
      _errorMessage = null;
      if (value.startsWith('ALERTA:')) {
        _lastEsp32Alert = value;
      }
      if (value.contains('"watchdog":true')) {
        _watchdogEnabled = true;
      } else if (value.contains('"watchdog":false')) {
        _watchdogEnabled = false;
      }
      _safeNotify();
    });
  }

  void syncConnectionDevice(String? deviceId) {
    if (_connectedDeviceId == deviceId) return;

    _connectedDeviceId = deviceId;
    if (deviceId == null) {
      _stopHeartbeat();
      _stopRssiPolling();
      _currentRssi = null;
      _rssiUnavailable = false;
      _watchdogEnabled = false;
      _safeNotify();
      return;
    }

    _lastPongReceivedAt = null;
    _startHeartbeat(deviceId);
    _startRssiPolling(deviceId);
    _safeNotify();
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

  Future<void> sendNudge(
    String deviceId, {
    required double deltaAlt,
    required double deltaAz,
  }) {
    return _send(
      () => _motorCommandService.sendNudgeCommand(
        deviceId,
        deltaAlt: deltaAlt,
        deltaAz: deltaAz,
      ),
    );
  }

  Future<void> sendSetPosition(
    String deviceId, {
    required double alt,
    required double az,
  }) {
    return _send(
      () => _motorCommandService.sendSetPositionCommand(
        deviceId,
        alt: alt,
        az: az,
      ),
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

  Future<void> setWatchdogEnabled(String deviceId, bool enabled) async {
    if (_isTogglingWatchdog) return;

    _isTogglingWatchdog = true;
    _errorMessage = null;
    _safeNotify();

    try {
      _lastSentCommand = await _motorCommandService.sendEnableWatchdogCommand(
        deviceId,
        enabled,
      );
      _watchdogEnabled = enabled;
    } catch (e) {
      _errorMessage = 'No se pudo cambiar watchdog OE4: ${_errorText(e)}';
    } finally {
      _isTogglingWatchdog = false;
      _safeNotify();
    }
  }

  void _startHeartbeat(String deviceId) {
    _heartbeatTimer?.cancel();
    _heartbeatActive = true;
    _sendHeartbeatPing(deviceId);

    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      final activeDeviceId = _connectedDeviceId;
      if (activeDeviceId == null) return;
      _sendHeartbeatPing(activeDeviceId);
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _heartbeatActive = false;
    _pingInFlight = false;
  }

  Future<void> _sendHeartbeatPing(String deviceId) async {
    if (_pingInFlight || _connectedDeviceId != deviceId) return;

    _pingInFlight = true;
    try {
      await _motorCommandService.sendPingCommand(deviceId);
    } catch (_) {
      // The BLE connection controller owns disconnect/error state; avoid noisy UI errors every 300 ms.
    } finally {
      _pingInFlight = false;
    }
  }

  void _startRssiPolling(String deviceId) {
    _rssiTimer?.cancel();
    _readRssi(deviceId);
    _rssiTimer = Timer.periodic(_rssiInterval, (_) {
      final activeDeviceId = _connectedDeviceId;
      if (activeDeviceId == null) return;
      _readRssi(activeDeviceId);
    });
  }

  void _stopRssiPolling() {
    _rssiTimer?.cancel();
    _rssiTimer = null;
    _rssiReadInFlight = false;
  }

  Future<void> _readRssi(String deviceId) async {
    if (_rssiReadInFlight || _connectedDeviceId != deviceId) return;

    _rssiReadInFlight = true;
    try {
      final rssi = await _motorCommandService.readRssi(deviceId);
      if (_connectedDeviceId != deviceId) return;
      final changed = _currentRssi != rssi || _rssiUnavailable;
      _currentRssi = rssi;
      _rssiUnavailable = false;
      if (changed) _safeNotify();
    } catch (_) {
      if (_connectedDeviceId != deviceId) return;
      final changed = _currentRssi != null || !_rssiUnavailable;
      _currentRssi = null;
      _rssiUnavailable = true;
      if (changed) _safeNotify();
    } finally {
      _rssiReadInFlight = false;
    }
  }

  Future<void> _send(Future<String> Function() command) async {
    _isSending = true;
    _errorMessage = null;
    _safeNotify();

    try {
      _lastSentCommand = await command();
    } catch (e) {
      _errorMessage = 'No se pudo enviar comando OE4: ${_errorText(e)}';
    } finally {
      _isSending = false;
      _safeNotify();
    }
  }

  bool _isPongResponse(String value) {
    return value.contains('"msg":"PONG"') || value.trim() == 'PONG';
  }

  String _errorText(Object error) {
    return error is StateError ? error.message : error.toString();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _heartbeatTimer?.cancel();
    _rssiTimer?.cancel();
    _responseSubscription.cancel();
    _motorCommandService.dispose();
    super.dispose();
  }
}
