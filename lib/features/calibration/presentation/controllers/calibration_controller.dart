import 'package:flutter/foundation.dart';

import '../../../catalog/data/repository/celestial_catalog_repository.dart';
import '../../../catalog/domain/models/celestial_object.dart';
import '../../../observation/domain/models/alt_az_result.dart';
import '../../../observation/domain/services/observer_data_provider.dart';
import '../../../observation/domain/utils/angle_math.dart';
import '../../data/calibration_repository.dart';
import '../../domain/models/calibration_flow_step.dart';
import '../../domain/models/calibration_method.dart';
import '../../domain/models/calibration_point.dart';
import '../../domain/models/calibration_result.dart';
import '../../domain/models/calibration_session.dart';
import '../../domain/models/calibration_status.dart';
import '../../domain/services/astronomy_position_service.dart';
import '../../domain/services/calibration_service.dart';

typedef CalibrationCommandSender = Future<void> Function();
typedef CalibrationGotoSender =
    Future<void> Function(double altitude, double azimuth);

enum CalibrationNudgeDirection { up, down, left, right }

@immutable
final class CalibrationStarOption {
  final CalibrationStar star;
  final AltAzResult position;
  final bool isVisible;

  const CalibrationStarOption({
    required this.star,
    required this.position,
    required this.isVisible,
  });
}

class CalibrationController extends ChangeNotifier {
  static const double fineStepDegrees = 0.25;
  static const double visibleStarAltitudeThresholdDeg = 15.0;

  final CelestialCatalogRepository catalogRepository;
  final CalibrationRepository calibrationRepository;
  final AstronomyPositionService astronomyPositionService;
  final CalibrationService calibrationService;
  final ObserverDataProvider observerDataProvider;

  bool _initialized = false;
  bool _isLoading = false;
  bool _isBusy = false;
  String? _errorMessage;
  CalibrationFlowStep _flowStep = CalibrationFlowStep.idle;
  CalibrationSession? _session;
  CalibrationResult? _savedResult;
  CalibrationResult? _pendingResult;
  CalibrationStar? _selectedStar;
  AltAzResult? _targetPosition;
  double? _adjustedAltitude;
  double? _adjustedAzimuth;
  List<CalibrationStar> _calibrationStars = const [];
  List<CalibrationStarOption> _calibrationStarOptions = const [];

  CalibrationController({
    required this.catalogRepository,
    required this.calibrationRepository,
    required this.astronomyPositionService,
    required this.calibrationService,
    required this.observerDataProvider,
  });

  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;
  CalibrationFlowStep get flowStep => _flowStep;
  CalibrationSession? get session => _session;
  CalibrationResult? get savedResult => _savedResult;
  CalibrationResult? get pendingResult => _pendingResult;
  CalibrationResult? get visibleResult => _pendingResult ?? _savedResult;
  CalibrationStar? get selectedStar => _selectedStar;
  AltAzResult? get targetPosition => _targetPosition;
  double? get adjustedAltitude => _adjustedAltitude;
  double? get adjustedAzimuth => _adjustedAzimuth;
  List<CalibrationStar> get calibrationStars => _calibrationStars;
  List<CalibrationStarOption> get calibrationStarOptions =>
      _calibrationStarOptions;
  bool get hasUnsavedResult => _pendingResult != null;

  CalibrationStatus get status {
    if (_session != null &&
        _flowStep != CalibrationFlowStep.idle &&
        _flowStep != CalibrationFlowStep.completed) {
      return _session!.status;
    }
    final result = visibleResult;
    if (result != null) return _statusForResult(result);
    return CalibrationStatus.notCalibrated;
  }

  CalibrationPoint? get latestPoint {
    final resultPoints = visibleResult?.points;
    if (resultPoints != null && resultPoints.isNotEmpty) {
      return resultPoints.last;
    }
    final sessionPoints = _session?.points;
    if (sessionPoints != null && sessionPoints.isNotEmpty) {
      return sessionPoints.last;
    }
    return null;
  }

  Future<void> loadSavedCalibration() async {
    if (_initialized || _isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await catalogRepository.initialize();
      _calibrationStars = catalogRepository
          .getByCategory('stars')
          .whereType<CalibrationStar>()
          .toList(growable: false);
      _savedResult = await calibrationRepository.loadCurrentResult();
      _initialized = true;
      debugPrint(
        '[Calibration] Loaded ${_calibrationStars.length} calibration stars',
      );
    } catch (error) {
      _errorMessage = 'No se pudo cargar correccion estimada: $error';
      debugPrint('[Calibration] Load failed: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void startMethod(CalibrationMethod method) {
    if (!method.isEnabledInMvp) {
      _errorMessage = '${method.title} estara disponible proximamente.';
      notifyListeners();
      return;
    }

    _session = calibrationService.startSession(method);
    _pendingResult = null;
    _selectedStar = null;
    _targetPosition = null;
    _adjustedAltitude = null;
    _adjustedAzimuth = null;
    _calibrationStarOptions = const [];
    _flowStep = CalibrationFlowStep.waitingHome;
    _errorMessage = null;
    debugPrint('[Calibration] Method selected: ${method.name}');
    notifyListeners();
  }

  Future<void> sendHome(CalibrationCommandSender send) async {
    if (_session == null) return;
    await _runCommand(logLabel: '[Calibration] HOME requested', action: send);
  }

  void continueAfterHome() {
    if (_session == null) return;

    try {
      _calibrationStarOptions = _buildCalibrationStarOptions();
      _flowStep = CalibrationFlowStep.selectingObject;
      _errorMessage = null;
      debugPrint(
        '[Calibration] Visible calibration stars: '
        '${_calibrationStarOptions.where((option) => option.isVisible).length} / '
        '${_calibrationStarOptions.length}',
      );
    } catch (error) {
      _flowStep = CalibrationFlowStep.failed;
      _errorMessage = 'No se pudo calcular visibilidad de estrellas: $error';
      debugPrint('[Calibration] Star visibility calculation failed: $error');
    }

    notifyListeners();
  }

  Future<void> selectStar(CalibrationStarOption option) async {
    if (_session == null) return;

    if (!option.isVisible) {
      _errorMessage =
          'Selecciona una estrella visible sobre ${visibleStarAltitudeThresholdDeg.toStringAsFixed(0)} grados de altitud.';
      notifyListeners();
      return;
    }

    final star = option.star;

    _selectedStar = star;
    _targetPosition = null;
    _adjustedAltitude = null;
    _adjustedAzimuth = null;
    _flowStep = CalibrationFlowStep.calculatingTarget;
    _errorMessage = null;
    debugPrint('[Calibration] Object selected: ${star.name}');
    notifyListeners();

    try {
      final observer = observerDataProvider.current();
      final target = astronomyPositionService.calculateForStar(
        star: star,
        observer: observer,
      );
      if (!_isVisibleForCalibration(target)) {
        _calibrationStarOptions = _buildCalibrationStarOptions();
        _selectedStar = null;
        _flowStep = CalibrationFlowStep.selectingObject;
        _errorMessage =
            'La estrella ya no esta visible para referencia. Selecciona otra estrella visible.';
        return;
      }

      _targetPosition = target;
      _adjustedAltitude = target.altitudeDeg;
      _adjustedAzimuth = target.azimuthDeg;
      _flowStep = CalibrationFlowStep.movingToTarget;
      debugPrint(
        '[Calibration] Calculated Alt/Az: '
        '${target.altitudeDeg.toStringAsFixed(2)} / '
        '${target.azimuthDeg.toStringAsFixed(2)}',
      );
    } catch (error) {
      _flowStep = CalibrationFlowStep.failed;
      _errorMessage = 'No se pudo calcular Alt/Az: $error';
      debugPrint('[Calibration] Alt/Az calculation failed: $error');
    } finally {
      notifyListeners();
    }
  }

  Future<void> sendGotoToTarget(CalibrationGotoSender sendGoto) async {
    final target = _targetPosition;
    if (target == null) return;
    if (!_isVisibleForCalibration(target)) {
      _errorMessage =
          'La estrella seleccionada no supera el umbral de visibilidad para calibracion.';
      notifyListeners();
      return;
    }

    await _runCommand(
      logLabel:
          '[Calibration] GOTO requested: '
          '${target.altitudeDeg.toStringAsFixed(2)} / '
          '${target.azimuthDeg.toStringAsFixed(2)}',
      action: () => sendGoto(target.altitudeDeg, target.azimuthDeg),
      onSuccess: () {
        _adjustedAltitude = target.altitudeDeg;
        _adjustedAzimuth = target.azimuthDeg;
        _flowStep = CalibrationFlowStep.waitingUserCentering;
      },
    );
  }

  Future<void> nudge(
    CalibrationNudgeDirection direction,
    CalibrationGotoSender sendGoto,
  ) async {
    // Fase 1 trabaja en lazo abierto: es una posicion local estimada
    // de motores, no una confirmacion optica del telescopio.
    final currentAltitude = _adjustedAltitude;
    final currentAzimuth = _adjustedAzimuth;
    if (currentAltitude == null || currentAzimuth == null) return;

    final next = _nextNudgePosition(direction, currentAltitude, currentAzimuth);

    await _runCommand(
      logLabel:
          '[Calibration] Fine GOTO: '
          '${next.altitude.toStringAsFixed(2)} / '
          '${next.azimuth.toStringAsFixed(2)}',
      action: () => sendGoto(next.altitude, next.azimuth),
      onSuccess: () {
        _adjustedAltitude = next.altitude;
        _adjustedAzimuth = next.azimuth;
      },
    );
  }

  void confirmAdjustedReference() {
    final session = _session;
    final star = _selectedStar;
    final target = _targetPosition;
    final adjustedAltitude = _adjustedAltitude;
    final adjustedAzimuth = _adjustedAzimuth;
    if (session == null ||
        star == null ||
        target == null ||
        adjustedAltitude == null ||
        adjustedAzimuth == null) {
      return;
    }

    _flowStep = CalibrationFlowStep.savingPoint;
    notifyListeners();

    final point = calibrationService.createPoint(
      objectName: star.name,
      calculatedAltitude: target.altitudeDeg,
      calculatedAzimuth: target.azimuthDeg,
      adjustedAltitude: adjustedAltitude,
      adjustedAzimuth: adjustedAzimuth,
    );
    _session = calibrationService.addPoint(session, point);
    _flowStep = CalibrationFlowStep.calculatingCorrection;
    _pendingResult = calibrationService.completeSession(_session!);
    _flowStep = CalibrationFlowStep.completed;
    _errorMessage = null;
    debugPrint(
      '[Calibration] Adjusted reference Alt/Az: '
      '${adjustedAltitude.toStringAsFixed(2)} / '
      '${adjustedAzimuth.toStringAsFixed(2)}',
    );
    debugPrint(
      '[Calibration] Estimated offset Alt/Az: '
      '${point.altitudeError.toStringAsFixed(2)} / '
      '${point.azimuthError.toStringAsFixed(2)}',
    );
    notifyListeners();
  }

  Future<void> savePendingResult() async {
    final result = _pendingResult;
    if (result == null) return;

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await calibrationRepository.saveCurrentResult(result);
      _savedResult = result;
      _pendingResult = null;
      debugPrint('[Calibration] Saved estimated correction');
    } catch (error) {
      _errorMessage = 'No se pudo guardar correccion estimada: $error';
      debugPrint('[Calibration] Save failed: $error');
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> clearCalibration() async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await calibrationRepository.clearCurrentResult();
      _savedResult = null;
      _pendingResult = null;
      _session = null;
      _selectedStar = null;
      _targetPosition = null;
      _adjustedAltitude = null;
      _adjustedAzimuth = null;
      _calibrationStarOptions = const [];
      _flowStep = CalibrationFlowStep.idle;
      debugPrint('[Calibration] Cleared estimated correction');
    } catch (error) {
      _errorMessage = 'No se pudo borrar correccion estimada: $error';
      debugPrint('[Calibration] Clear failed: $error');
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  void cancelFlow() {
    _session = null;
    _pendingResult = null;
    _selectedStar = null;
    _targetPosition = null;
    _adjustedAltitude = null;
    _adjustedAzimuth = null;
    _calibrationStarOptions = const [];
    _flowStep = CalibrationFlowStep.idle;
    _errorMessage = null;
    notifyListeners();
  }

  List<CalibrationStarOption> _buildCalibrationStarOptions() {
    final observer = observerDataProvider.current();
    final options = _calibrationStars.map((star) {
      final position = astronomyPositionService.calculateForStar(
        star: star,
        observer: observer,
      );
      return CalibrationStarOption(
        star: star,
        position: position,
        isVisible: _isVisibleForCalibration(position),
      );
    }).toList();

    options.sort((a, b) {
      if (a.isVisible != b.isVisible) {
        return a.isVisible ? -1 : 1;
      }
      final altitudeOrder = b.position.altitudeDeg.compareTo(
        a.position.altitudeDeg,
      );
      if (altitudeOrder != 0) return altitudeOrder;
      return a.star.name.compareTo(b.star.name);
    });

    return options;
  }

  bool _isVisibleForCalibration(AltAzResult position) {
    return position.altitudeDeg > visibleStarAltitudeThresholdDeg;
  }

  Future<void> _runCommand({
    required String logLabel,
    required CalibrationCommandSender action,
    VoidCallback? onSuccess,
  }) async {
    if (_isBusy) return;

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint(logLabel);
      await action();
      onSuccess?.call();
    } catch (error) {
      _errorMessage = 'No se pudo enviar comando: $error';
      debugPrint('[Calibration] Command failed: $error');
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  ({double altitude, double azimuth}) _nextNudgePosition(
    CalibrationNudgeDirection direction,
    double altitude,
    double azimuth,
  ) {
    final nextAltitude = switch (direction) {
      CalibrationNudgeDirection.up => altitude + fineStepDegrees,
      CalibrationNudgeDirection.down => altitude - fineStepDegrees,
      _ => altitude,
    };
    final nextAzimuth = switch (direction) {
      CalibrationNudgeDirection.left => azimuth - fineStepDegrees,
      CalibrationNudgeDirection.right => azimuth + fineStepDegrees,
      _ => azimuth,
    };

    return (
      altitude: nextAltitude.clamp(-90.0, 90.0).toDouble(),
      azimuth: normalizeDegrees360(nextAzimuth),
    );
  }

  CalibrationStatus _statusForResult(CalibrationResult result) {
    return switch (result.method) {
      CalibrationMethod.oneStar => CalibrationStatus.calibratedOneStar,
      CalibrationMethod.twoStars => CalibrationStatus.calibratedTwoStars,
      CalibrationMethod.threeStars => CalibrationStatus.calibratedThreeStars,
      CalibrationMethod.fixedObjectSync => CalibrationStatus.localSyncActive,
    };
  }
}
