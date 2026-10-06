import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../calibration/domain/models/calibration_result.dart';
import '../../../calibration/domain/services/alignment_session.dart';
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
  static const Duration previewInterval = Duration(seconds: 1);
  static const Duration trackingInterval = Duration(seconds: 15);
  static const double fineStepDegrees = 0.25;

  final CelestialObject object;
  final AstronomicalGotoService gotoService;

  /// Shared telescope position, so fine tuning starts where the telescope
  /// really is even if another screen moved it after the GoTo.
  final ({double altitude, double azimuth})? Function()? positionProvider;

  Timer? _trackingTimer;
  Timer? _previewTimer;
  Future<void>? _previewRefresh;
  bool _disposed = false;
  bool _isSending = false;
  bool _fineTuneInFlight = false;
  bool _isTracking = false;
  bool _trackingTickInFlight = false;
  int _stopGeneration = 0;
  String? _errorMessage;
  String? _fineTuneError;
  String? _previewError;
  String? _statusMessage;
  AltAzResult? _currentPosition;
  CalibrationResult? _savedCalibration;
  AstronomicalGotoCommand? _previewCommand;
  CelestialSentCommand? _lastSentCommand;
  DateTime? _lastUpdatedAt;
  DateTime? _nextTrackingAt;
  double? _localAltitude;
  double? _localAzimuth;

  CelestialControlController({
    required this.object,
    required this.gotoService,
    this.positionProvider,
  }) {
    AlignmentSession.changes.addListener(_onReferenceChanged);
  }

  void _onReferenceChanged() {
    _stopGeneration++;
    _isSending = false;
    _localAltitude = null;
    _localAzimuth = null;
    _savedCalibration = null;
    _previewCommand = null;
    _previewError =
        'La referencia cambió. Repite la alineación con una estrella.';
    stopTracking('Tracking detenido: cambió la referencia o la conexión.');
  }

  bool get isSending => _isSending;
  bool get isFineTuneInFlight => _fineTuneInFlight;
  bool get isTracking => _isTracking;
  String? get errorMessage => _errorMessage ?? _previewError;
  String? get previewError => _previewError;

  /// Error de la última flecha de ajuste fino. Va aparte de [errorMessage]
  /// para mostrarlo debajo de las flechas y no moverlas bajo el dedo.
  String? get fineTuneError => _fineTuneError;
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

  void startLivePreview() {
    if (_disposed || _previewTimer != null) return;
    unawaited(refreshPreview(updateStatus: false));
    _previewTimer = Timer.periodic(previewInterval, (_) {
      unawaited(refreshPreview(updateStatus: false));
    });
  }

  Future<void> refreshPreview({bool updateStatus = true}) {
    if (_disposed) return Future<void>.value();
    return _previewRefresh ??= _refreshPreview(
      updateStatus: updateStatus,
    ).whenComplete(() => _previewRefresh = null);
  }

  Future<void> _refreshPreview({required bool updateStatus}) async {
    final session = AlignmentSession.token;
    try {
      final initialAlignment = await gotoService.loadInitialAlignment();
      final correctionCalibration = await gotoService
          .loadCorrectionCalibration();
      if (_disposed || session != AlignmentSession.token) return;
      final rawPosition = gotoService.calculateCurrentPosition(object);
      AstronomicalGotoCommand? preview;
      String? error;

      try {
        preview = gotoService.buildCommand(
          object: object,
          rawPosition: rawPosition,
          initialAlignment: initialAlignment,
          correctionCalibration: correctionCalibration,
        );
      } catch (e) {
        error = _errorText(e);
      }

      _currentPosition = rawPosition;
      _savedCalibration = initialAlignment;
      _previewCommand = preview;
      _lastUpdatedAt = rawPosition.computedAt;
      _previewError = error;
      if (updateStatus && !_isSending) {
        _errorMessage = null;
        _statusMessage = error ?? 'Alt/Az actualizado.';
      }
    } catch (e) {
      if (_disposed || session != AlignmentSession.token) return;
      _currentPosition = null;
      _savedCalibration = null;
      _previewCommand = null;
      _lastUpdatedAt = null;
      _previewError = _errorText(e);
      if (updateStatus && !_isSending) {
        _errorMessage = null;
        _statusMessage = _previewError;
      }
    }
    _safeNotify();
  }

  Future<void> sendInitialGoto(CelestialGotoSender send) async {
    await _sendAstronomicalGoto('GoTo inicial', send);
  }

  Future<void> startTracking(CelestialGotoSender send) async {
    if (_isTracking || _isSending) return;

    final generation = _stopGeneration;
    await refreshPreview();
    if (_disposed || generation != _stopGeneration) return;
    if (_currentPosition == null || !isVisible || _previewCommand == null) {
      _errorMessage ??=
          _previewError ??
          'No se puede iniciar tracking: objeto no disponible.';
      _statusMessage = _errorMessage;
      _safeNotify();
      return;
    }

    _isTracking = true;
    _nextTrackingAt = DateTime.now().toUtc().add(trackingInterval);
    _statusMessage = 'Tracking lógico activo. Actualiza cada 15 segundos.';
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
    final generation = _stopGeneration;
    _fineTuneInFlight = true;

    try {
      await send(next.altitude, next.azimuth);
      if (_disposed || generation != _stopGeneration) return;
      final sentAt = DateTime.now().toUtc();
      _localAltitude = next.altitude;
      _localAzimuth = next.azimuth;
      _lastSentCommand = CelestialSentCommand(
        label: 'Ajuste fino ${_directionLabel(direction)}',
        altitude: next.altitude,
        azimuth: next.azimuth,
        sentAt: sentAt,
      );
      _errorMessage = null;
      _fineTuneError = null;
    } catch (e) {
      if (_disposed || generation != _stopGeneration) return;
      _fineTuneError = _errorText(e);
      _statusMessage = _fineTuneError;
    } finally {
      _fineTuneInFlight = false;
      _safeNotify();
    }
  }

  Future<void> sendStop(CelestialStopSender send) async {
    _stopGeneration++;
    _localAltitude = null;
    _localAzimuth = null;
    stopTracking('Tracking detenido por STOP.');

    _isSending = true;
    _errorMessage = null;
    _fineTuneError = null;
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
      await _sendAstronomicalGoto('Tracking lógico', send);
      if (_isTracking) {
        _nextTrackingAt = DateTime.now().toUtc().add(trackingInterval);
        _statusMessage = 'Tracking lógico activo. Proximo envio programado.';
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

    final generation = _stopGeneration;
    _isSending = true;
    _errorMessage = null;
    _fineTuneError = null;
    _statusMessage = 'Enviando $label...';
    _safeNotify();

    try {
      final command = await gotoService.sendGoto(
        object: object,
        send: (alt, az) async {
          if (_disposed || generation != _stopGeneration) {
            throw StateError('GoTo cancelado por STOP.');
          }
          await send(alt, az);
        },
      );
      if (_disposed || generation != _stopGeneration) return;
      final sentAt = DateTime.now().toUtc();
      if (_lastUpdatedAt == null ||
          !command.rawPosition.computedAt.isBefore(_lastUpdatedAt!)) {
        _currentPosition = command.rawPosition;
        _savedCalibration = command.initialAlignment;
        _previewCommand = command;
        _previewError = null;
        _lastUpdatedAt = command.rawPosition.computedAt;
      }
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
          ? '$label enviado con corrección de precisión.'
          : '$label enviado con alineación inicial.';
    } catch (e) {
      if (_disposed || generation != _stopGeneration) return;
      _errorMessage = _errorText(e);
      _statusMessage = _errorMessage;
      if (_isTracking) {
        stopTracking('Tracking detenido: $_errorMessage');
      }
    } finally {
      if (generation == _stopGeneration) _isSending = false;
      _safeNotify();
    }
  }

  ({double altitude, double azimuth}) _nextFinePosition(
    CelestialFineDirection direction,
  ) {
    final shared = positionProvider?.call();
    final currentAltitude = shared?.altitude ?? _localAltitude ?? 0.0;
    final currentAzimuth = shared?.azimuth ?? _localAzimuth ?? 0.0;
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
    AlignmentSession.changes.removeListener(_onReferenceChanged);
    _previewTimer?.cancel();
    _trackingTimer?.cancel();
    super.dispose();
  }
}
