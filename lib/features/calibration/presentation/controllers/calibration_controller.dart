import 'package:flutter/foundation.dart';

import '../../../catalog/data/repository/celestial_catalog_repository.dart';
import '../../../catalog/domain/models/celestial_object.dart';
import '../../../observation/domain/models/alt_az_result.dart';
import '../../../observation/domain/services/observer_data_provider.dart';
import '../../../observation/domain/services/sun_guard.dart';
import '../../../observation/domain/utils/angle_math.dart';
import '../../data/calibration_repository.dart';
import '../../domain/models/calibration_flow_step.dart';
import '../../domain/models/calibration_method.dart';
import '../../domain/models/calibration_point.dart';
import '../../domain/models/calibration_result.dart';
import '../../domain/models/calibration_session.dart';
import '../../domain/models/calibration_stage.dart';
import '../../domain/models/calibration_status.dart';
import '../../domain/models/correction_calibration_status.dart';
import '../../domain/models/initial_alignment_status.dart';
import '../../domain/services/astronomy_position_service.dart';
import '../../domain/services/calibration_service.dart';
import '../../domain/services/alignment_session.dart';

typedef CalibrationCommandSender = Future<void> Function();
typedef CalibrationGotoSender =
    Future<void> Function(double altitude, double azimuth);

/// Relative move from the shared telescope position.
typedef CalibrationManualMoveSender =
    Future<void> Function(double deltaAltitude, double deltaAzimuth);
typedef CalibrationSetPositionSender =
    Future<void> Function(double altitude, double azimuth);

enum CalibrationNudgeDirection { up, down, left, right }

@immutable
final class CalibrationStarOption {
  final CalibrationStar star;
  final AltAzResult position;
  final bool isVisible;
  final bool isAlreadySelected;
  final double? closestReferenceDistanceDeg;
  final bool isTooCloseToReference;

  /// Está dentro de la zona prohibida alrededor del Sol.
  final bool isNearSun;

  const CalibrationStarOption({
    required this.star,
    required this.position,
    required this.isVisible,
    this.isAlreadySelected = false,
    this.closestReferenceDistanceDeg,
    this.isTooCloseToReference = false,
    this.isNearSun = false,
  });

  /// Sobre el horizonte mínimo y lejos del Sol.
  bool get isUsable => isVisible && !isNearSun;

  bool get isSelectable => isUsable && !isAlreadySelected;
}

class CalibrationController extends ChangeNotifier {
  // Nominal half-step at the 28BYJ-48 output, before external gearing.
  static const double nominalMotorStepDegrees = 360.0 / 4096.0;
  static const double fineStepDegrees = 0.25;
  static const double visibleStarAltitudeThresholdDeg = 15.0;
  static const double minimumRecommendedSeparationDeg = 30.0;
  static const List<String> _recommendedStarOrder = [
    'Acrux',
    'Becrux (Mimosa)',
    'Gacrux',
    'Canopus',
    'Sirio',
    'Achernar',
    'Alfa Centauri A',
    'Hadar (Agena)',
  ];

  final CelestialCatalogRepository catalogRepository;
  final CalibrationRepository calibrationRepository;
  final AstronomyPositionService astronomyPositionService;
  final CalibrationService calibrationService;
  final ObserverDataProvider observerDataProvider;
  final SunGuard? sunGuard;
  final ({double altitude, double azimuth})? Function()? motorPositionProvider;

  bool _initialized = false;
  bool _isLoading = false;
  bool _isBusy = false;
  bool _abortRequested = false;
  String? _errorMessage;
  CalibrationFlowStep _flowStep = CalibrationFlowStep.idle;
  CalibrationStage _activeStage = CalibrationStage.initialAlignment;
  CalibrationSession? _session;
  CalibrationResult? _initialAlignmentResult;
  CalibrationResult? _correctionCalibrationResult;
  CalibrationResult? _pendingResult;
  CalibrationStar? _selectedStar;
  AltAzResult? _targetPosition;
  double? _adjustedAltitude;
  double? _adjustedAzimuth;
  String? _flowWarningMessage;
  String? _pendingSeparationWarning;
  List<CalibrationStar> _calibrationStars = const [];
  List<CalibrationStarOption> _calibrationStarOptions = const [];

  CalibrationController({
    required this.catalogRepository,
    required this.calibrationRepository,
    required this.astronomyPositionService,
    required this.calibrationService,
    required this.observerDataProvider,
    this.sunGuard,
    this.motorPositionProvider,
  }) {
    AlignmentSession.changes.addListener(_onSessionChanged);
  }

  void _onSessionChanged() {
    _initialAlignmentResult = null;
    _correctionCalibrationResult = null;
    cancelFlow();
  }

  @override
  void dispose() {
    AlignmentSession.changes.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _ensureLiveTime() {
    if (!observerDataProvider.current().isLive) {
      throw StateError(
        'Activa Usar hora actual en Configuración antes de alinear o apuntar.',
      );
    }
  }

  void _recordMotorPositionIfKnown() {
    final position = motorPositionProvider?.call();
    if (position == null) return;
    _adjustedAltitude = position.altitude;
    _adjustedAzimuth = position.azimuth;
  }

  void _recordMotorPosition({
    required double fallbackAltitude,
    required double fallbackAzimuth,
  }) {
    final position = motorPositionProvider?.call();
    if (motorPositionProvider != null && position == null) {
      throw StateError(
        'El ESP32 no confirmó su posición. Solicita STATUS antes de continuar.',
      );
    }
    _adjustedAltitude = position?.altitude ?? fallbackAltitude;
    _adjustedAzimuth = position?.azimuth ?? fallbackAzimuth;
  }

  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;
  CalibrationFlowStep get flowStep => _flowStep;
  CalibrationStage get activeStage => _session?.stage ?? _activeStage;
  CalibrationSession? get session => _session;
  CalibrationResult? get savedResult =>
      _correctionCalibrationResult ?? _initialAlignmentResult;
  CalibrationResult? get initialAlignmentResult => _initialAlignmentResult;
  CalibrationResult? get correctionCalibrationResult =>
      _correctionCalibrationResult;
  CalibrationResult? get pendingResult => _pendingResult;
  CalibrationResult? get visibleResult =>
      _pendingResult ??
      (activeStage == CalibrationStage.initialAlignment
          ? _initialAlignmentResult
          : _correctionCalibrationResult);
  CalibrationStar? get selectedStar => _selectedStar;
  AltAzResult? get targetPosition => _targetPosition;
  double? get adjustedAltitude => _adjustedAltitude;
  double? get adjustedAzimuth => _adjustedAzimuth;
  String? get flowWarningMessage => _flowWarningMessage;
  List<CalibrationStar> get calibrationStars => _calibrationStars;
  List<CalibrationStarOption> get calibrationStarOptions =>
      _calibrationStarOptions;
  bool get hasUnsavedResult => _pendingResult != null;
  bool get isInitialAlignmentFlow =>
      activeStage == CalibrationStage.initialAlignment;
  bool get isCorrectionCalibrationFlow =>
      activeStage == CalibrationStage.correctionCalibration;
  bool get isInitialAligned => _initialAlignmentResult != null;
  bool get hasCorrectionCalibration =>
      _correctionCalibrationResult?.hasCorrectionCalibration ?? false;
  CalibrationMethod? get currentMethod =>
      _session?.method ?? visibleResult?.method;
  CalibrationMethod? get correctionCalibrationMode =>
      _correctionCalibrationResult?.method;

  InitialAlignmentStatus get initialAlignmentStatus {
    final session = _session;
    if (session != null &&
        session.stage == CalibrationStage.initialAlignment &&
        _flowStep != CalibrationFlowStep.idle &&
        _flowStep != CalibrationFlowStep.completed) {
      return switch (_flowStep) {
        CalibrationFlowStep.selectingObject ||
        CalibrationFlowStep.calculatingTarget =>
          InitialAlignmentStatus.selectingReferenceStar,
        CalibrationFlowStep.waitingUserCentering ||
        CalibrationFlowStep.savingPoint =>
          InitialAlignmentStatus.waitingForManualCentering,
        CalibrationFlowStep.failed => InitialAlignmentStatus.alignmentFailed,
        _ => InitialAlignmentStatus.selectingReferenceStar,
      };
    }
    return isInitialAligned
        ? InitialAlignmentStatus.aligned
        : InitialAlignmentStatus.notAligned;
  }

  CorrectionCalibrationStatus get correctionCalibrationStatus {
    final session = _session;
    if (session != null &&
        session.stage == CalibrationStage.correctionCalibration &&
        _flowStep != CalibrationFlowStep.idle &&
        _flowStep != CalibrationFlowStep.completed) {
      return switch (_flowStep) {
        CalibrationFlowStep.selectingMethod =>
          CorrectionCalibrationStatus.selectingCalibrationMode,
        CalibrationFlowStep.selectingObject ||
        CalibrationFlowStep.calculatingTarget =>
          CorrectionCalibrationStatus.selectingCalibrationTarget,
        CalibrationFlowStep.movingToTarget =>
          CorrectionCalibrationStatus.gotoTarget,
        CalibrationFlowStep.waitingUserCentering ||
        CalibrationFlowStep.savingPoint =>
          CorrectionCalibrationStatus.waitingForManualCorrection,
        CalibrationFlowStep.calculatingCorrection =>
          CorrectionCalibrationStatus.correctionCalculated,
        CalibrationFlowStep.failed =>
          CorrectionCalibrationStatus.calibrationFailed,
        _ => CorrectionCalibrationStatus.selectingCalibrationTarget,
      };
    }
    if (hasCorrectionCalibration) {
      return CorrectionCalibrationStatus.calibrated;
    }
    return CorrectionCalibrationStatus.notCalibrated;
  }

  String? get initialAlignmentReferenceName =>
      _initialAlignmentResult?.lastReference?.objectName;
  DateTime? get initialAlignmentTimestamp => _initialAlignmentResult?.createdAt;
  ({double altitude, double azimuth})? get initialAlignedPosition {
    final point = _initialAlignmentResult?.lastReference;
    if (point == null) return null;
    return (
      altitude: point.motorAltitudeAtCalibration ?? point.calculatedAltitude,
      azimuth: point.motorAzimuthAtCalibration ?? point.calculatedAzimuth,
    );
  }

  int get requiredReferenceCount {
    return currentMethod?.requiredPointCount ??
        CalibrationMethod.oneStar.requiredPointCount;
  }

  int get completedReferenceCount => _session?.points.length ?? 0;

  int get currentReferenceNumber {
    final session = _session;
    if (session == null) return 1;

    final rawNumber = switch (_flowStep) {
      CalibrationFlowStep.completed ||
      CalibrationFlowStep.calculatingCorrection => session.points.length,
      _ => session.points.length + 1,
    };
    final required = session.method.requiredPointCount;
    if (rawNumber < 1) return 1;
    if (rawNumber > required) return required;
    return rawNumber;
  }

  int get totalFlowSteps {
    if (isInitialAlignmentFlow) return 4;
    return (requiredReferenceCount * 3) + 1;
  }

  int get currentFlowStepNumber {
    if (isInitialAlignmentFlow) {
      return switch (_flowStep) {
        CalibrationFlowStep.selectingObject ||
        CalibrationFlowStep.calculatingTarget => 1,
        CalibrationFlowStep.waitingUserCentering => 2,
        CalibrationFlowStep.savingPoint ||
        CalibrationFlowStep.calculatingCorrection => 3,
        CalibrationFlowStep.completed => 4,
        _ => 1,
      };
    }

    final referenceBase = 1 + ((currentReferenceNumber - 1) * 3);
    return switch (_flowStep) {
      CalibrationFlowStep.selectingObject ||
      CalibrationFlowStep.calculatingTarget => referenceBase,
      CalibrationFlowStep.movingToTarget => referenceBase + 1,
      CalibrationFlowStep.waitingUserCentering => referenceBase + 2,
      CalibrationFlowStep.savingPoint ||
      CalibrationFlowStep.calculatingCorrection => referenceBase + 2,
      CalibrationFlowStep.completed => totalFlowSteps,
      _ => 1,
    };
  }

  String get referenceProgressLabel {
    return 'Referencia $currentReferenceNumber de $requiredReferenceCount';
  }

  String get selectedStarGuide {
    final star = _selectedStar;
    if (star == null) return '';
    return guideForStar(star);
  }

  CalibrationStatus get status {
    if (_session != null &&
        _flowStep != CalibrationFlowStep.idle &&
        _flowStep != CalibrationFlowStep.completed) {
      return _session!.status;
    }
    if (_correctionCalibrationResult != null) {
      return _correctionCalibrationResult!.status;
    }
    if (_initialAlignmentResult != null) {
      return _initialAlignmentResult!.status;
    }
    return CalibrationStatus.notCalibrated;
  }

  CalibrationPoint? get latestPoint {
    final sessionPoints = _session?.points;
    if (sessionPoints != null && sessionPoints.isNotEmpty) {
      return sessionPoints.last;
    }
    final resultPoints = visibleResult?.points;
    if (resultPoints != null && resultPoints.isNotEmpty) {
      return resultPoints.last;
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
      _initialAlignmentResult = await calibrationRepository
          .loadInitialAlignmentResult();
      _correctionCalibrationResult = await calibrationRepository
          .loadCorrectionCalibrationResult();
      _initialized = true;
      debugPrint(
        '[Calibration] Loaded ${_calibrationStars.length} calibration stars',
      );
    } catch (error) {
      _errorMessage = 'No se pudo cargar estado de alineación: $error';
      debugPrint('[Calibration] Load failed: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void startMethod(CalibrationMethod method) {
    if (method == CalibrationMethod.oneStar && !isInitialAligned) {
      startInitialAlignment();
      return;
    }
    startCorrectionMethod(method);
  }

  void startInitialAlignment() {
    _startSession(
      stage: CalibrationStage.initialAlignment,
      method: CalibrationMethod.oneStar,
    );
  }

  void startCorrectionMethod(CalibrationMethod method) {
    if (!isInitialAligned) {
      _errorMessage =
          'Antes de usar GOTO o calibraciones de corrección, debes realizar la alineación inicial del telescopio con una estrella reconocible.';
      notifyListeners();
      return;
    }

    _startSession(
      stage: CalibrationStage.correctionCalibration,
      method: method,
    );
  }

  void _startSession({
    required CalibrationStage stage,
    required CalibrationMethod method,
  }) {
    _activeStage = stage;
    _session = calibrationService.startSession(stage: stage, method: method);
    _pendingResult = null;
    _selectedStar = null;
    _targetPosition = null;
    _adjustedAltitude = null;
    _adjustedAzimuth = null;
    _flowWarningMessage = null;
    _pendingSeparationWarning = null;
    try {
      _calibrationStarOptions = _buildCalibrationStarOptions();
      _flowStep = CalibrationFlowStep.selectingObject;
      _errorMessage = _visibilityRequirementError(_calibrationStarOptions);
      debugPrint(
        '[Calibration] Visible reference stars: '
        '${_calibrationStarOptions.where((option) => option.isUsable).length} / '
        '${_calibrationStarOptions.length}',
      );
    } catch (error) {
      _flowStep = CalibrationFlowStep.failed;
      _session = _session?.copyWith(
        status: CalibrationStatus.calibrationFailed,
      );
      _errorMessage = 'No se pudo calcular visibilidad de referencias: $error';
      debugPrint('[Calibration] Star visibility calculation failed: $error');
    }
    debugPrint('[Calibration] Stage selected: ${stage.name} / ${method.name}');
    notifyListeners();
  }

  Future<void> selectStar(CalibrationStarOption option) async {
    if (_session == null) return;

    if (option.isAlreadySelected) {
      _errorMessage =
          '${option.star.name} ya fue registrada como referencia en esta sesión.';
      notifyListeners();
      return;
    }

    if (!option.isVisible) {
      _errorMessage =
          'Selecciona una estrella visible sobre ${visibleStarAltitudeThresholdDeg.toStringAsFixed(0)} grados de altitud.';
      notifyListeners();
      return;
    }

    if (option.isNearSun) {
      _errorMessage = SunGuard.blockedMessage(what: option.star.name);
      notifyListeners();
      return;
    }

    final star = option.star;

    _selectedStar = star;
    _targetPosition = null;
    _adjustedAltitude = null;
    _adjustedAzimuth = null;
    _flowWarningMessage = null;
    _pendingSeparationWarning = null;
    _flowStep = CalibrationFlowStep.calculatingTarget;
    _errorMessage = null;
    debugPrint('[Calibration] Object selected: ${star.name}');
    notifyListeners();

    try {
      _ensureLiveTime();
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
            'La estrella ya no está visible para referencia. Selecciona otra estrella visible.';
        return;
      }
      if (_isNearSun(target)) {
        _resetToStarSelection();
        _errorMessage = SunGuard.blockedMessage(what: star.name);
        return;
      }

      _targetPosition = target;
      _adjustedAltitude = target.altitudeDeg;
      _adjustedAzimuth = target.azimuthDeg;
      final closestDistance = _closestReferenceDistance(target);
      if (closestDistance != null &&
          closestDistance < minimumRecommendedSeparationDeg) {
        _pendingSeparationWarning = _separationWarningMessage(
          star.name,
          closestDistance,
        );
        _flowWarningMessage = _pendingSeparationWarning;
      }
      _session = _session?.copyWith(status: CalibrationStatus.inProgress);
      // Both stages first send an approximate GOTO (from the 0/0 reference
      // during the initial alignment) and then wait for manual centering.
      _flowStep = CalibrationFlowStep.movingToTarget;
      debugPrint(
        '[Calibration] Calculated Alt/Az: '
        '${target.altitudeDeg.toStringAsFixed(2)} / '
        '${target.azimuthDeg.toStringAsFixed(2)}',
      );
    } catch (error) {
      _flowStep = CalibrationFlowStep.failed;
      _session = _session?.copyWith(
        status: CalibrationStatus.calibrationFailed,
      );
      _errorMessage = 'No se pudo calcular Alt/Az: $error';
      debugPrint('[Calibration] Alt/Az calculation failed: $error');
    } finally {
      notifyListeners();
    }
  }

  Future<void> sendGotoToReference(CalibrationGotoSender sendGoto) async {
    final session = _session;
    final star = _selectedStar;
    if (session == null ||
        star == null ||
        _flowStep != CalibrationFlowStep.movingToTarget) {
      return;
    }

    if (_isBusy) return;

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _ensureLiveTime();
      final connectionSession = AlignmentSession.token;
      final observer = observerDataProvider.current();
      final target = astronomyPositionService.calculateForStar(
        star: star,
        observer: observer,
      );
      if (!_isVisibleForCalibration(target)) {
        _targetPosition = target;
        _flowStep = CalibrationFlowStep.selectingObject;
        _selectedStar = null;
        _calibrationStarOptions = _buildCalibrationStarOptions();
        _errorMessage =
            'La referencia ya no está visible. Selecciona una estrella sobre ${visibleStarAltitudeThresholdDeg.toStringAsFixed(0)} grados de altitud.';
        return;
      }
      if (_isNearSun(target)) {
        _resetToStarSelection();
        _errorMessage = SunGuard.blockedMessage(what: star.name);
        return;
      }

      // The initial alignment replaces the reference, so the previous
      // correction must not bend its approximate GOTO.
      final destination = session.stage == CalibrationStage.initialAlignment
          ? _rawGotoTarget(target)
          : _correctedGotoTarget(target);
      await sendGoto(destination.altitude, destination.azimuth);
      if (connectionSession != AlignmentSession.token) {
        throw StateError('La conexión cambió. Repite la alineación.');
      }

      _targetPosition = target;
      _recordMotorPosition(
        fallbackAltitude: destination.altitude,
        fallbackAzimuth: destination.azimuth,
      );
      _session = session.copyWith(
        status: CalibrationStatus.waitingForManualCentering,
      );
      _flowStep = CalibrationFlowStep.waitingUserCentering;
      debugPrint(
        '[Calibration] Correction GOTO Alt/Az: '
        '${destination.altitude.toStringAsFixed(4)} / '
        '${destination.azimuth.toStringAsFixed(4)}',
      );
    } catch (error) {
      // A reconnection already reset the flow in _onSessionChanged.
      if (_session == null) return;
      if (_abortRequested) {
        _abortRequested = false;
        _resetToStarSelection();
        return;
      }
      // Nothing moved: centering by hand from here would aim at the Sun.
      if (error is SunSafetyError) {
        _resetToStarSelection();
        _errorMessage = error.message;
        return;
      }
      // The user can still center the star by hand from wherever the
      // telescope stopped (for example after a stall far from the target).
      _flowStep = CalibrationFlowStep.waitingUserCentering;
      _session = _session?.copyWith(
        status: CalibrationStatus.waitingForManualCentering,
      );
      _recordMotorPositionIfKnown();
      _errorMessage = 'No se pudo completar el GOTO a la estrella: $error';
      debugPrint('[Calibration] Reference GOTO failed: $error');
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> nudge(
    CalibrationNudgeDirection direction,
    CalibrationManualMoveSender sendManualMove,
  ) async {
    if (_selectedStar == null ||
        _flowStep != CalibrationFlowStep.waitingUserCentering) {
      return;
    }

    final delta = _nudgeDelta(direction);

    await _runCommand(
      logLabel:
          '[Calibration] Manual nudge: '
          '${delta.altitude.toStringAsFixed(2)} / '
          '${delta.azimuth.toStringAsFixed(2)}',
      action: () => sendManualMove(delta.altitude, delta.azimuth),
      onSuccess: () {
        _recordMotorPosition(
          fallbackAltitude: (_adjustedAltitude ?? 0.0) + delta.altitude,
          fallbackAzimuth: (_adjustedAzimuth ?? 0.0) + delta.azimuth,
        );
      },
    );
  }

  /// Moves to an absolute motor position. It is sent as an absolute GOTO so
  /// the result never depends on where a previous screen left the firmware
  /// target.
  Future<void> moveToAdjustedPosition({
    required double altitude,
    required double azimuth,
    required CalibrationGotoSender sendAbsoluteMove,
  }) async {
    if (_selectedStar == null ||
        _flowStep != CalibrationFlowStep.waitingUserCentering) {
      return;
    }

    if (!altitude.isFinite || !azimuth.isFinite) {
      _errorMessage = 'Ingresa valores numéricos válidos.';
      notifyListeners();
      return;
    }

    if (altitude < -90 || altitude > 90) {
      _errorMessage = 'La altitud debe estar entre -90 y 90 grados.';
      notifyListeners();
      return;
    }
    final destinationAzimuth = normalizeDegrees360(azimuth);

    await _runCommand(
      logLabel:
          '[Calibration] Manual direct move to: '
          '${altitude.toStringAsFixed(2)} / '
          '${destinationAzimuth.toStringAsFixed(2)}',
      action: () => sendAbsoluteMove(altitude, destinationAzimuth),
      onSuccess: () {
        _recordMotorPosition(
          fallbackAltitude: altitude,
          fallbackAzimuth: destinationAzimuth,
        );
      },
    );
  }

  /// [refreshPosition] asks the ESP32 for STATUS so the correction point uses
  /// the encoder position at the moment the user confirms.
  Future<void> confirmCenteredReference({
    CalibrationSetPositionSender? setInitialPosition,
    CalibrationCommandSender? refreshPosition,
  }) async {
    final session = _session;
    final star = _selectedStar;
    if (session == null ||
        star == null ||
        _flowStep != CalibrationFlowStep.waitingUserCentering) {
      return;
    }

    if (_isBusy) return;

    _isBusy = true;
    _flowStep = CalibrationFlowStep.savingPoint;
    _errorMessage = null;
    notifyListeners();

    try {
      _ensureLiveTime();
      final connectionSession = AlignmentSession.token;
      final observer = observerDataProvider.current();
      final target = astronomyPositionService.calculateForStar(
        star: star,
        observer: observer,
      );
      if (!_isVisibleForCalibration(target)) {
        _targetPosition = target;
        _flowStep = CalibrationFlowStep.waitingUserCentering;
        _errorMessage =
            'La referencia ya no está visible. Selecciona otra estrella sobre ${visibleStarAltitudeThresholdDeg.toStringAsFixed(0)} grados de altitud.';
        return;
      }

      var updatedSession = session;
      final separationWarning = _pendingSeparationWarning;
      if (separationWarning != null) {
        updatedSession = calibrationService.addWarning(
          updatedSession,
          separationWarning,
        );
      }

      if (session.stage == CalibrationStage.correctionCalibration &&
          refreshPosition != null) {
        await refreshPosition();
        if (connectionSession != AlignmentSession.token) {
          throw StateError('La conexión cambió. Repite la alineación.');
        }
        _recordMotorPosition(
          fallbackAltitude: _adjustedAltitude ?? target.altitudeDeg,
          fallbackAzimuth: _adjustedAzimuth ?? target.azimuthDeg,
        );
      }

      final point = session.stage == CalibrationStage.initialAlignment
          ? await _createInitialAlignmentPoint(
              star: star,
              target: target,
              setInitialPosition: setInitialPosition,
            )
          : _createCorrectionPoint(star: star, target: target);
      if (connectionSession != AlignmentSession.token) {
        throw StateError('La conexión cambió. Repite la alineación.');
      }

      updatedSession = calibrationService.addPoint(updatedSession, point);

      _session = updatedSession;
      _pendingResult = null;
      _selectedStar = null;
      _targetPosition = target;
      _flowWarningMessage = null;
      _pendingSeparationWarning = null;
      _errorMessage = null;

      if (updatedSession.points.length >=
          updatedSession.method.requiredPointCount) {
        final result = calibrationService.completeSession(updatedSession);
        await _saveCompletedResult(result);
        if (session.stage == CalibrationStage.initialAlignment) {
          _session = null;
          _targetPosition = null;
          _adjustedAltitude = null;
          _adjustedAzimuth = null;
          _activeStage = CalibrationStage.correctionCalibration;
          _flowStep = CalibrationFlowStep.idle;
        } else {
          _adjustedAltitude = point.adjustedAltitude;
          _adjustedAzimuth = point.adjustedAzimuth;
          _flowStep = CalibrationFlowStep.completed;
        }
        debugPrint(
          '[Calibration] Completed ${session.stage.name}: '
          '${result.altitudeOffset.toStringAsFixed(4)} / '
          '${result.azimuthOffset.toStringAsFixed(4)}',
        );
      } else {
        _targetPosition = null;
        _adjustedAltitude = null;
        _adjustedAzimuth = null;
        _calibrationStarOptions = _buildCalibrationStarOptions();
        _flowStep = CalibrationFlowStep.selectingObject;
        _errorMessage = _visibilityRequirementError(_calibrationStarOptions);
      }
    } catch (error) {
      _flowStep = CalibrationFlowStep.failed;
      _session = _session?.copyWith(
        status: CalibrationStatus.calibrationFailed,
      );
      _errorMessage = 'No se pudo confirmar estrella centrada: $error';
      debugPrint('[Calibration] Confirm centered reference failed: $error');
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<CalibrationPoint> _createInitialAlignmentPoint({
    required CalibrationStar star,
    required AltAzResult target,
    required CalibrationSetPositionSender? setInitialPosition,
  }) async {
    if (setInitialPosition == null) {
      throw StateError('La alineación inicial requiere SET_POSITION.');
    }

    await setInitialPosition(target.altitudeDeg, target.azimuthDeg);
    return calibrationService.createPositionReferencePoint(
      objectId: star.id,
      objectName: star.name,
      referenceRaJ2000Hours: star.raJ2000Hours,
      referenceDecJ2000Degrees: star.decJ2000Degrees,
      altitude: target.altitudeDeg,
      azimuth: target.azimuthDeg,
    );
  }

  CalibrationPoint _createCorrectionPoint({
    required CalibrationStar star,
    required AltAzResult target,
  }) {
    final adjustedAltitude = _adjustedAltitude ?? target.altitudeDeg;
    final adjustedAzimuth = _adjustedAzimuth ?? target.azimuthDeg;

    return calibrationService.createPoint(
      objectId: star.id,
      objectName: star.name,
      calculatedAltitude: target.altitudeDeg,
      calculatedAzimuth: target.azimuthDeg,
      adjustedAltitude: adjustedAltitude,
      adjustedAzimuth: adjustedAzimuth,
      referenceRaJ2000Hours: star.raJ2000Hours,
      referenceDecJ2000Degrees: star.decJ2000Degrees,
      motorAltitudeAtCalibration: adjustedAltitude,
      motorAzimuthAtCalibration: adjustedAzimuth,
    );
  }

  Future<void> _saveCompletedResult(CalibrationResult result) async {
    final connectionSession = AlignmentSession.token;
    if (result.isInitialAlignment) {
      await calibrationRepository.saveInitialAlignmentResult(result);
      await calibrationRepository.clearCorrectionCalibrationResult();
      if (connectionSession != AlignmentSession.token) {
        throw StateError('La conexión cambió al guardar.');
      }
      _initialAlignmentResult = result;
      _correctionCalibrationResult = null;
      return;
    }

    await calibrationRepository.saveCorrectionCalibrationResult(result);
    if (connectionSession != AlignmentSession.token) {
      throw StateError('La conexión cambió al guardar.');
    }
    _correctionCalibrationResult = result;
  }

  /// Guarda el centrado manual de un objeto del catálogo como corrección de
  /// una referencia ("Guardar esta corrección" en Observar). Reemplaza la
  /// corrección anterior.
  Future<void> saveObjectCorrection({
    required String objectId,
    required String objectName,
    required double calculatedAltitude,
    required double calculatedAzimuth,
    required double motorAltitude,
    required double motorAzimuth,
  }) async {
    if (!isInitialAligned) {
      throw StateError('Alinea el telescopio antes de guardar correcciones.');
    }
    final point = calibrationService.createPoint(
      objectId: objectId,
      objectName: objectName,
      calculatedAltitude: calculatedAltitude,
      calculatedAzimuth: calculatedAzimuth,
      adjustedAltitude: motorAltitude,
      adjustedAzimuth: motorAzimuth,
      motorAltitudeAtCalibration: motorAltitude,
      motorAzimuthAtCalibration: motorAzimuth,
    );
    final session = calibrationService.addPoint(
      calibrationService.startSession(
        stage: CalibrationStage.correctionCalibration,
        method: CalibrationMethod.oneStar,
      ),
      point,
    );
    await _saveCompletedResult(calibrationService.completeSession(session));
    notifyListeners();
  }

  Future<void> savePendingResult() async {
    final result = _pendingResult;
    if (result == null) return;

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _saveCompletedResult(result);
      _pendingResult = null;
      debugPrint('[Calibration] Saved result');
    } catch (error) {
      _errorMessage = 'No se pudo guardar resultado: $error';
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
      _initialAlignmentResult = null;
      _correctionCalibrationResult = null;
      _pendingResult = null;
      _session = null;
      _selectedStar = null;
      _targetPosition = null;
      _adjustedAltitude = null;
      _adjustedAzimuth = null;
      _flowWarningMessage = null;
      _pendingSeparationWarning = null;
      _calibrationStarOptions = const [];
      _flowStep = CalibrationFlowStep.idle;
      _activeStage = CalibrationStage.initialAlignment;
      debugPrint('[Calibration] Cleared alignment and correction');
    } catch (error) {
      _errorMessage = 'No se pudo borrar alineación y corrección: $error';
      debugPrint('[Calibration] Clear failed: $error');
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> clearCorrectionCalibration() async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await calibrationRepository.clearCorrectionCalibrationResult();
      _correctionCalibrationResult = null;
      if (_activeStage == CalibrationStage.correctionCalibration) {
        cancelFlow();
      }
      debugPrint('[Calibration] Cleared correction calibration');
    } catch (error) {
      _errorMessage = 'No se pudo borrar corrección de precisión: $error';
      debugPrint('[Calibration] Clear correction failed: $error');
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Detiene el GOTO a la referencia y vuelve a la elección de estrella.
  Future<void> abortReferenceGoto(CalibrationCommandSender sendStop) async {
    if (_session == null) return;
    _abortRequested = _isBusy;
    try {
      await sendStop();
    } finally {
      // If the GOTO is still unwinding, its catch block finishes the reset.
      if (!_isBusy) {
        _abortRequested = false;
        returnToStarSelection();
      }
    }
  }

  /// Vuelve a la elección de estrella sin perder las referencias ya
  /// confirmadas en esta sesión.
  void returnToStarSelection() {
    if (_session == null) return;
    _resetToStarSelection();
    notifyListeners();
  }

  void _resetToStarSelection() {
    _selectedStar = null;
    _targetPosition = null;
    _adjustedAltitude = null;
    _adjustedAzimuth = null;
    _flowWarningMessage = null;
    _pendingSeparationWarning = null;
    _calibrationStarOptions = _buildCalibrationStarOptions();
    _flowStep = CalibrationFlowStep.selectingObject;
    _errorMessage = _visibilityRequirementError(_calibrationStarOptions);
  }

  void cancelFlow() {
    _session = null;
    _pendingResult = null;
    _selectedStar = null;
    _targetPosition = null;
    _adjustedAltitude = null;
    _adjustedAzimuth = null;
    _flowWarningMessage = null;
    _pendingSeparationWarning = null;
    _calibrationStarOptions = const [];
    _flowStep = CalibrationFlowStep.idle;
    _errorMessage = null;
    notifyListeners();
  }

  List<CalibrationStarOption> _buildCalibrationStarOptions() {
    final observer = observerDataProvider.current();
    final usedObjectIds =
        _session?.points.map((point) => point.objectId).toSet() ??
        const <String>{};
    final usedObjectNames =
        _session?.points.map((point) => point.objectName).toSet() ??
        const <String>{};
    final options = _calibrationStars.map((star) {
      final position = astronomyPositionService.calculateForStar(
        star: star,
        observer: observer,
      );
      final closestDistance = _closestReferenceDistance(position);
      final isAlreadySelected =
          usedObjectIds.contains(star.id) ||
          usedObjectNames.contains(star.name);
      return CalibrationStarOption(
        star: star,
        position: position,
        isVisible: _isVisibleForCalibration(position),
        isAlreadySelected: isAlreadySelected,
        closestReferenceDistanceDeg: closestDistance,
        isTooCloseToReference:
            closestDistance != null &&
            closestDistance < minimumRecommendedSeparationDeg,
        isNearSun: _isNearSun(position),
      );
    }).toList();

    options.sort((a, b) {
      if (a.isUsable != b.isUsable) {
        return a.isUsable ? -1 : 1;
      }
      if (a.isAlreadySelected != b.isAlreadySelected) {
        return a.isAlreadySelected ? 1 : -1;
      }
      final priorityOrder = _recommendedPriority(
        a.star,
      ).compareTo(_recommendedPriority(b.star));
      if (priorityOrder != 0) return priorityOrder;
      final altitudeOrder = b.position.altitudeDeg.compareTo(
        a.position.altitudeDeg,
      );
      if (altitudeOrder != 0) return altitudeOrder;
      return a.star.name.compareTo(b.star.name);
    });

    return options;
  }

  String guideForStar(CalibrationStar star) {
    return switch (star.name) {
      'Acrux' =>
        'Busca la Cruz del Sur. Acrux es la estrella más brillante ubicada en el extremo inferior de la cruz.',
      'Becrux (Mimosa)' =>
        'Busca la Cruz del Sur. Mimosa es una estrella azul brillante en uno de los brazos de la cruz, cerca de Acrux.',
      'Gacrux' =>
        'Busca la Cruz del Sur. Gacrux es la estrella rojiza del extremo superior de la cruz.',
      'Canopus' =>
        'Canopus es muy brillante y se ve baja o media en cielos australes; queda en Carina y suele destacar lejos de Orión.',
      'Sirio' =>
        'Sirio es la estrella más brillante del cielo nocturno. Busca Canis Major, cerca de Orión.',
      'Achernar' =>
        'Achernar es una estrella azul muy brillante del sur, al final de Eridanus; suele verse aislada y destacada.',
      'Alfa Centauri A' =>
        'Alfa Centauri aparece como una estrella muy brillante cerca de la Cruz del Sur, junto a Hadar.',
      'Hadar (Agena)' =>
        'Hadar, o Beta Centauri, está cerca de Alfa Centauri y apunta visualmente hacia la Cruz del Sur.',
      _ =>
        'Usa la constelación ${star.constellation}, su brillo y la posición Alt/Az mostrada para reconocerla antes de centrarla.',
    };
  }

  int _recommendedPriority(CalibrationStar star) {
    final index = _recommendedStarOrder.indexOf(star.name);
    if (index < 0) return _recommendedStarOrder.length;
    return index;
  }

  String? _visibilityRequirementError(List<CalibrationStarOption> options) {
    final session = _session;
    if (session == null) return null;

    final requiredCount = session.method.requiredPointCount;
    final visibleCount = options.where((option) => option.isUsable).length;
    if (visibleCount < requiredCount) {
      return _insufficientStarsMessage(session);
    }

    final remainingRequired = requiredCount - session.points.length;
    final selectableCount = options
        .where((option) => option.isSelectable)
        .length;
    if (selectableCount < remainingRequired) {
      final flowName = session.stage == CalibrationStage.initialAlignment
          ? 'la alineación inicial'
          : session.method.title;
      return 'No quedan suficientes estrellas visibles sin repetir para completar $flowName. Se requieren $remainingRequired referencias adicionales sobre ${visibleStarAltitudeThresholdDeg.toStringAsFixed(0)} grados de altitud.';
    }

    return null;
  }

  String _insufficientStarsMessage(CalibrationSession session) {
    if (session.stage == CalibrationStage.initialAlignment) {
      return 'No hay estrellas visibles para la alineación inicial. Se requiere una estrella reconocible sobre ${visibleStarAltitudeThresholdDeg.toStringAsFixed(0)} grados de altitud.';
    }
    if (session.method == CalibrationMethod.oneStar) {
      return 'No hay estrellas visibles para ${session.method.title}. Se requiere al menos una estrella sobre ${visibleStarAltitudeThresholdDeg.toStringAsFixed(0)} grados de altitud.';
    }
    return 'No hay suficientes estrellas visibles para ${session.method.title}. Se requieren al menos ${session.method.requiredPointCount} estrellas sobre ${visibleStarAltitudeThresholdDeg.toStringAsFixed(0)} grados de altitud.';
  }

  double? _closestReferenceDistance(AltAzResult position) {
    final points = _session?.points ?? const <CalibrationPoint>[];
    double? closestDistance;
    for (final point in points) {
      final distance = sphericalAngularDistance(
        point.calculatedAltitude,
        point.calculatedAzimuth,
        position.altitudeDeg,
        position.azimuthDeg,
      );
      if (closestDistance == null || distance < closestDistance) {
        closestDistance = distance;
      }
    }
    return closestDistance;
  }

  String _separationWarningMessage(String starName, double distanceDeg) {
    return 'Advertencia: $starName está a ${distanceDeg.toStringAsFixed(1)} grados de una referencia anterior. La corrección puede ser menos útil.';
  }

  bool _isVisibleForCalibration(AltAzResult position) {
    return position.altitudeDeg > visibleStarAltitudeThresholdDeg;
  }

  bool _isNearSun(AltAzResult position) =>
      sunGuard?.isNearSun(
        position.altitudeDeg,
        position.azimuthDeg,
        at: position.computedAt,
      ) ??
      false;

  ({double altitude, double azimuth}) _rawGotoTarget(AltAzResult target) => (
    altitude: target.altitudeDeg.clamp(-90.0, 90.0).toDouble(),
    azimuth: normalizeDegrees360(target.azimuthDeg),
  );

  ({double altitude, double azimuth}) _correctedGotoTarget(AltAzResult target) {
    final correction = _correctionCalibrationResult;
    if (correction == null || !correction.hasCorrectionCalibration) {
      return _rawGotoTarget(target);
    }

    return calibrationService.applyCorrection(
      targetAltitude: target.altitudeDeg,
      targetAzimuth: target.azimuthDeg,
      correction: correction,
    );
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
      final connectionSession = AlignmentSession.token;
      await action();
      if (connectionSession != AlignmentSession.token) {
        throw StateError('La conexión cambió. Repite la alineación.');
      }
      onSuccess?.call();
    } on SunSafetyError catch (error) {
      // Nothing was sent, so the flow keeps its position and can go on.
      _errorMessage = error.message;
    } catch (error) {
      _errorMessage = 'No se pudo enviar comando: $error';
      // An interrupted movement may have advanced only part of the requested
      // distance. Do not let that stale position become a correction reference.
      _flowStep = CalibrationFlowStep.failed;
      _session = _session?.copyWith(
        status: CalibrationStatus.calibrationFailed,
      );
      debugPrint('[Calibration] Command failed: $error');
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  ({double altitude, double azimuth}) _nudgeDelta(
    CalibrationNudgeDirection direction,
  ) {
    final altitude = switch (direction) {
      CalibrationNudgeDirection.up => fineStepDegrees,
      CalibrationNudgeDirection.down => -fineStepDegrees,
      _ => 0.0,
    };
    final azimuth = switch (direction) {
      CalibrationNudgeDirection.left => -fineStepDegrees,
      CalibrationNudgeDirection.right => fineStepDegrees,
      _ => 0.0,
    };

    return (altitude: altitude, azimuth: azimuth);
  }
}
