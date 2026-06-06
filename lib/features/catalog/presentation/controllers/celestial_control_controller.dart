import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../calibration/domain/models/calibration_result.dart';
import '../../../observation/domain/models/alt_az_result.dart';
import '../../../observation/domain/utils/angle_math.dart';
import '../../application/astronomical_goto_service.dart';
import '../../domain/models/celestial_object.dart';

typedef CelestialGotoSender =
    Future<void> Function(double altitude, double azimuth);
typedef CelestialStopSender = Future<void> Function();

enum CelestialFineDirection { up, down, left, right }

class CelestialSentCommand {
  final String label;
  final double? altitude;
  final double? azimuth;
  final AstronomicalGotoCommand? astronomicalCommand;
  final DateTime sentAt;

  const CelestialSentCommand({
    required this.label,
    required this.sentAt,
    this.altitude,
    this.azimuth,
    this.astronomicalCommand,
  });

  bool get usedCorrection => astronomicalCommand?.usedCorrection ?? false;
}

class CelestialControlController extends ChangeNotifier {
  static const Duration trackingInterval = Duration(seconds: 15);
  static const double fineStepDegrees = 0.25;

  final CelestialObject object;
  final AstronomicalGotoService gotoService;

  Timer? _trackingTimer;
  bool _disposed = false;
  bool _isSending = false;
  bool _fineTuneInFlight = false;
  bool _isTracking = false;
  bool _trackingTickInFlight = false;
  String? _errorMessage;
  String? _statusMessage;
  AltAzResult? _currentPosition;
  CalibrationResult? _savedCalibration;
  AstronomicalGotoCommand? _previewCommand;
  CelestialSentCommand? _lastSentCommand;
  DateTime? _lastUpdatedAt;
  DateTime? _nextTrackingAt;
  double? _localAltitude;
  double? _localAzimuth;

  CelestialControlController({required this.object, required this.gotoService});

  bool get isSending => _isSending;
  bool get isFineTuneInFlight => _fineTuneInFlight;
  bool get isTracking => _isTracking;
  String? get errorMessage => _errorMessage;
  String? get statusMessage => _statusMessage;
  AltAzResult? get currentPosition => _currentPosition;
  CalibrationResult? get savedCalibration => _savedCalibration;
  AstronomicalGotoCommand? get previewCommand => _previewCommand;
  CelestialSentCommand? get lastSentCommand => _lastSentCommand;
  DateTime? get lastUpdatedAt => _lastUpdatedAt;
  DateTime? get nextTrackingAt => _nextTrackingAt;
  double? get localAltitude => _localAltitude;
  double? get localAzimuth => _localAzimuth;
  bool get canFineTune => _localAltitude != null && _localAzimuth != null;
  bool get isVisible => (_currentPosition?.altitudeDeg ?? -90.0) >= 0.0;

  Future<void> refreshPreview() async {
    try {
      final rawPosition = gotoService.calculateCurrentPosition(object);
      final calibration = await gotoService.loadSavedCalibration();
      AstronomicalGotoCommand? preview;
      String? error;

      try {
        preview = gotoService.buildCommand(
          object: object,
          rawPosition: rawPosition,
          calibration: calibration,
        );
      } catch (e) {
        error = _errorText(e);
      }

      _currentPosition = rawPosition;
      _savedCalibration = calibration;
      _previewCommand = preview;
      _lastUpdatedAt = rawPosition.computedAt;
      _errorMessage = error;
      _statusMessage = error ?? 'Alt/Az actualizado.';
    } catch (e) {
      _currentPosition = null;
      _previewCommand = null;
      _errorMessage = _errorText(e);
      _statusMessage = _errorMessage;
    }
    _safeNotify();
  }

  Future<void> sendInitialGoto(CelestialGotoSender send) async {
    await _sendAstronomicalGoto('GoTo inicial', send);
  }

  Future<void> startTracking(CelestialGotoSender send) async {
    if (_isTracking || _isSending) return;

    await refreshPreview();
    if (_currentPosition == null || !isVisible || _previewCommand == null) {
      _errorMessage ??= 'No se puede iniciar tracking: objeto no disponible.';
      _statusMessage = _errorMessage;
      _safeNotify();
      return;
    }

    _isTracking = true;
    _nextTrackingAt = DateTime.now().toUtc().add(trackingInterval);
    _statusMessage = 'Tracking logico activo. Actualiza cada 15 segundos.';
    _safeNotify();

    _trackingTimer?.cancel();
    _trackingTimer = Timer.periodic(
      trackingInterval,
      (_) => unawaited(_runTrackingTick(send)),
    );
  }

  void stopTracking([String message = 'Tracking detenido.']) {
    _trackingTimer?.cancel();
    _trackingTimer = null;
    _isTracking = false;
    _trackingTickInFlight = false;
    _nextTrackingAt = null;
    _statusMessage = message;
    _safeNotify();
  }

  Future<void> fineTune(
    CelestialFineDirection direction,
    CelestialGotoSender send,
  ) async {
    if (_isSending || _fineTuneInFlight || !canFineTune) return;

    final next = _nextFinePosition(direction);
    _fineTuneInFlight = true;

    try {
      await send(next.altitude, next.azimuth);
      final sentAt = DateTime.now().toUtc();
      _localAltitude = next.altitude;
      _localAzimuth = next.azimuth;
      _lastUpdatedAt = sentAt;
      _lastSentCommand = CelestialSentCommand(
        label: 'Ajuste fino ${_directionLabel(direction)}',
        altitude: next.altitude,
        azimuth: next.azimuth,
        sentAt: sentAt,
      );
      _errorMessage = null;
    } catch (e) {
      _errorMessage = _errorText(e);
      _statusMessage = _errorMessage;
    } finally {
      _fineTuneInFlight = false;
      _safeNotify();
    }
  }

  Future<void> sendStop(CelestialStopSender send) async {
    stopTracking('Tracking detenido por STOP.');
    if (_isSending) return;

    _isSending = true;
    _errorMessage = null;
    _statusMessage = 'Enviando STOP...';
    _safeNotify();

    try {
      await send();
      _lastSentCommand = CelestialSentCommand(
        label: 'STOP',
        sentAt: DateTime.now().toUtc(),
      );
      _statusMessage = 'STOP enviado. Tracking detenido.';
    } catch (e) {
      _errorMessage = _errorText(e);
      _statusMessage = _errorMessage;
    } finally {
      _isSending = false;
      _safeNotify();
    }
  }

  Future<void> _runTrackingTick(CelestialGotoSender send) async {
    if (!_isTracking || _trackingTickInFlight || _isSending) return;

    _trackingTickInFlight = true;
    try {
      await _sendAstronomicalGoto('Tracking logico', send);
      if (_isTracking) {
        _nextTrackingAt = DateTime.now().toUtc().add(trackingInterval);
        _statusMessage = 'Tracking logico activo. Proximo envio programado.';
        _safeNotify();
      }
    } catch (_) {
      // _sendAstronomicalGoto stores the visible error.
    } finally {
      _trackingTickInFlight = false;
    }
  }

  Future<void> _sendAstronomicalGoto(
    String label,
    CelestialGotoSender send,
  ) async {
    if (_isSending) return;

    _isSending = true;
    _errorMessage = null;
    _statusMessage = 'Enviando $label...';
    _safeNotify();

    try {
      final command = await gotoService.sendGoto(object: object, send: send);
      final sentAt = DateTime.now().toUtc();
      _currentPosition = command.rawPosition;
      _savedCalibration = command.calibration;
      _previewCommand = command;
      _lastUpdatedAt = command.rawPosition.computedAt;
      _localAltitude = command.finalAltitude;
      _localAzimuth = command.finalAzimuth;
      _lastSentCommand = CelestialSentCommand(
        label: label,
        altitude: command.finalAltitude,
        azimuth: command.finalAzimuth,
        astronomicalCommand: command,
        sentAt: sentAt,
      );
      _statusMessage = command.usedCorrection
          ? '$label enviado con correccion multipunto.'
          : '$label enviado con referencia calibrada.';
    } catch (e) {
      _errorMessage = _errorText(e);
      _statusMessage = _errorMessage;
      if (_isTracking) {
        stopTracking('Tracking detenido: $_errorMessage');
      }
    } finally {
      _isSending = false;
      _safeNotify();
    }
  }

  ({double altitude, double azimuth}) _nextFinePosition(
    CelestialFineDirection direction,
  ) {
    final currentAltitude = _localAltitude ?? 0.0;
    final currentAzimuth = _localAzimuth ?? 0.0;
    final nextAltitude = switch (direction) {
      CelestialFineDirection.up => currentAltitude + fineStepDegrees,
      CelestialFineDirection.down => currentAltitude - fineStepDegrees,
      _ => currentAltitude,
    };
    final nextAzimuth = switch (direction) {
      CelestialFineDirection.left => currentAzimuth - fineStepDegrees,
      CelestialFineDirection.right => currentAzimuth + fineStepDegrees,
      _ => currentAzimuth,
    };

    return (
      altitude: nextAltitude.clamp(-90.0, 90.0).toDouble(),
      azimuth: normalizeDegrees360(nextAzimuth),
    );
  }

  String _directionLabel(CelestialFineDirection direction) {
    return switch (direction) {
      CelestialFineDirection.up => 'arriba',
      CelestialFineDirection.down => 'abajo',
      CelestialFineDirection.left => 'izquierda',
      CelestialFineDirection.right => 'derecha',
    };
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
    _trackingTimer?.cancel();
    super.dispose();
  }
}
