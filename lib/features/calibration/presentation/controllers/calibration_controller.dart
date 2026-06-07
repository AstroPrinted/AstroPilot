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

  const CalibrationStarOption({
    required this.star,
    required this.position,
    required this.isVisible,
    this.isAlreadySelected = false,
    this.closestReferenceDistanceDeg,
    this.isTooCloseToReference = false,
  });

  bool get isSelectable => isVisible && !isAlreadySelected;
}

class CalibrationController extends ChangeNotifier {
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
  String? get flowWarningMessage => _flowWarningMessage;
  List<CalibrationStar> get calibrationStars => _calibrationStars;
  List<CalibrationStarOption> get calibrationStarOptions =>
      _calibrationStarOptions;
  bool get hasUnsavedResult => _pendingResult != null;
  CalibrationMethod? get currentMethod =>
      _session?.method ?? visibleResult?.method;

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
    if (currentMethod == CalibrationMethod.oneStar) return 4;
    return 1 + (requiredReferenceCount * 4) + 2;
  }

  int get currentFlowStepNumber {
    if (currentMethod == CalibrationMethod.oneStar) {
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

    final referenceBase = 2 + ((currentReferenceNumber - 1) * 4);
    return switch (_flowStep) {
      CalibrationFlowStep.waitingHome => 1,
      CalibrationFlowStep.selectingObject ||
      CalibrationFlowStep.calculatingTarget => referenceBase,
      CalibrationFlowStep.movingToTarget => referenceBase + 1,
      CalibrationFlowStep.waitingUserCentering => referenceBase + 2,
      CalibrationFlowStep.savingPoint => referenceBase + 3,
      CalibrationFlowStep.calculatingCorrection => totalFlowSteps - 1,
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
    final result = visibleResult;
    if (result != null) return result.status;
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
      _errorMessage = 'No se pudo cargar calibracion: $error';
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
    _flowWarningMessage = null;
    _pendingSeparationWarning = null;
    try {
      _calibrationStarOptions = _buildCalibrationStarOptions();
      _flowStep = CalibrationFlowStep.selectingObject;
      _errorMessage = _visibilityRequirementError(_calibrationStarOptions);
      debugPrint(
        '[Calibration] Visible calibration stars: '
        '${_calibrationStarOptions.where((option) => option.isVisible).length} / '
        '${_calibrationStarOptions.length}',
      );
    } catch (error) {
      _flowStep = CalibrationFlowStep.failed;
      _session = _session?.copyWith(
        status: CalibrationStatus.calibrationFailed,
      );
      _errorMessage = 'No se pudo calcular visibilidad de estrellas: $error';
      debugPrint('[Calibration] Star visibility calculation failed: $error');
    }
    debugPrint('[Calibration] Method selected: ${method.name}');
    notifyListeners();
  }

  Future<void> selectStar(CalibrationStarOption option) async {
    if (_session == null) return;

    if (option.isAlreadySelected) {
      _errorMessage =
          '${option.star.name} ya fue registrada como referencia en esta sesion.';
      notifyListeners();
      return;
    }

    if (!option.isVisible) {
      _errorMessage =
          'Selecciona una estrella visible sobre ${visibleStarAltitudeThresholdDeg.toStringAsFixed(0)} grados de altitud.';
      notifyListeners();
      return;
    }

    final star = option.star;

    _selectedStar = star;
    _targetPosition = null;
    _adjustedAltitude = 0.0;
    _adjustedAzimuth = 0.0;
    _flowWarningMessage = null;
    _pendingSeparationWarning = null;
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
      _adjustedAltitude = 0.0;
      _adjustedAzimuth = 0.0;
      final closestDistance = _closestReferenceDistance(target);
      if (closestDistance != null &&
          closestDistance < minimumRecommendedSeparationDeg) {
        _pendingSeparationWarning = _separationWarningMessage(
          star.name,
          closestDistance,
        );
        _flowWarningMessage = _pendingSeparationWarning;
      }
      _session = _session?.copyWith(
        status: CalibrationStatus.waitingForManualCentering,
      );
      _flowStep = CalibrationFlowStep.waitingUserCentering;
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
        _adjustedAltitude = (_adjustedAltitude ?? 0.0) + delta.altitude;
        _adjustedAzimuth = (_adjustedAzimuth ?? 0.0) + delta.azimuth;
      },
    );
  }

  Future<void> moveToAdjustedPosition({
    required double altitude,
    required double azimuth,
    required CalibrationManualMoveSender sendManualMove,
  }) async {
    if (_selectedStar == null ||
        _flowStep != CalibrationFlowStep.waitingUserCentering) {
      return;
    }

    if (!altitude.isFinite || !azimuth.isFinite) {
      _errorMessage = 'Ingresa valores numericos validos.';
      notifyListeners();
      return;
    }

    final currentAltitude = _adjustedAltitude ?? 0.0;
    final currentAzimuth = _adjustedAzimuth ?? 0.0;
    final deltaAltitude = altitude - currentAltitude;
    final deltaAzimuth = azimuth - currentAzimuth;

    if (deltaAltitude.abs() < 0.0001 && deltaAzimuth.abs() < 0.0001) {
      return;
    }

    await _runCommand(
      logLabel:
          '[Calibration] Manual direct move: '
          '${deltaAltitude.toStringAsFixed(2)} / '
          '${deltaAzimuth.toStringAsFixed(2)}',
      action: () => sendManualMove(deltaAltitude, deltaAzimuth),
      onSuccess: () {
        _adjustedAltitude = altitude;
        _adjustedAzimuth = azimuth;
      },
    );
  }

  Future<void> confirmCenteredReference(
    CalibrationSetPositionSender setPosition,
  ) async {
    final session = _session;
    final star = _selectedStar;
    if (session == null || star == null) {
      return;
    }

    if (_isBusy) return;

    _isBusy = true;
    _flowStep = CalibrationFlowStep.savingPoint;
    _errorMessage = null;
    notifyListeners();

    try {
      final observer = observerDataProvider.current();
      final target = astronomyPositionService.calculateForStar(
        star: star,
        observer: observer,
      );
      if (!_isVisibleForCalibration(target)) {
        _targetPosition = target;
        _flowStep = CalibrationFlowStep.waitingUserCentering;
        _errorMessage =
            'La estrella ya no esta visible para calibracion. Selecciona otra referencia.';
        return;
      }

      await setPosition(target.altitudeDeg, target.azimuthDeg);

      var updatedSession = session;
      final separationWarning = _pendingSeparationWarning;
      if (separationWarning != null) {
        updatedSession = calibrationService.addWarning(
          updatedSession,
          separationWarning,
        );
      }

      final point = calibrationService.createPositionReferencePoint(
        objectId: star.id,
        objectName: star.name,
        referenceRaJ2000Hours: star.raJ2000Hours,
        referenceDecJ2000Degrees: star.decJ2000Degrees,
        altitude: target.altitudeDeg,
        azimuth: target.azimuthDeg,
      );
      updatedSession = calibrationService.addPoint(updatedSession, point);
      final result = calibrationService.completeSession(updatedSession);
      await calibrationRepository.saveCurrentResult(result);

      _session = updatedSession;
      _savedResult = result;
      _pendingResult = null;
      _selectedStar = null;
      _targetPosition = target;
      _adjustedAltitude = target.altitudeDeg;
      _adjustedAzimuth = target.azimuthDeg;
      _flowWarningMessage = null;
      _pendingSeparationWarning = null;
      _flowStep = CalibrationFlowStep.completed;
      _errorMessage = null;
      debugPrint(
        '[Calibration] SET_POSITION reference Alt/Az: '
        '${target.altitudeDeg.toStringAsFixed(4)} / '
        '${target.azimuthDeg.toStringAsFixed(4)}',
      );
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
      debugPrint('[Calibration] Saved calibration');
    } catch (error) {
      _errorMessage = 'No se pudo guardar calibracion: $error';
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
      _flowWarningMessage = null;
      _pendingSeparationWarning = null;
      _calibrationStarOptions = const [];
      _flowStep = CalibrationFlowStep.idle;
      debugPrint('[Calibration] Cleared calibration');
    } catch (error) {
      _errorMessage = 'No se pudo borrar calibracion: $error';
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
      );
    }).toList();

    options.sort((a, b) {
      if (a.isVisible != b.isVisible) {
        return a.isVisible ? -1 : 1;
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
        'Busca la Cruz del Sur. Acrux es la estrella mas brillante ubicada en el extremo inferior de la cruz.',
      'Becrux (Mimosa)' =>
        'Busca la Cruz del Sur. Mimosa es una estrella azul brillante en uno de los brazos de la cruz, cerca de Acrux.',
      'Gacrux' =>
        'Busca la Cruz del Sur. Gacrux es la estrella rojiza del extremo superior de la cruz.',
      'Canopus' =>
        'Canopus es muy brillante y se ve baja o media en cielos australes; queda en Carina y suele destacar lejos de Orion.',
      'Sirio' =>
        'Sirio es la estrella mas brillante del cielo nocturno. Busca Canis Major, cerca de Orion.',
      'Achernar' =>
        'Achernar es una estrella azul muy brillante del sur, al final de Eridanus; suele verse aislada y destacada.',
      'Alfa Centauri A' =>
        'Alfa Centauri aparece como una estrella muy brillante cerca de la Cruz del Sur, junto a Hadar.',
      'Hadar (Agena)' =>
        'Hadar, o Beta Centauri, esta cerca de Alfa Centauri y apunta visualmente hacia la Cruz del Sur.',
      _ =>
        'Usa la constelacion ${star.constellation}, su brillo y la posicion Alt/Az mostrada para reconocerla antes de centrarla.',
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
    final visibleCount = options.where((option) => option.isVisible).length;
    if (visibleCount < requiredCount) {
      return _insufficientStarsMessage(session.method);
    }

    final remainingRequired = requiredCount - session.points.length;
    final selectableCount = options
        .where((option) => option.isSelectable)
        .length;
    if (selectableCount < remainingRequired) {
      return 'No quedan suficientes estrellas visibles sin repetir para completar calibracion con ${session.method.title}. Se requieren $remainingRequired referencias adicionales sobre ${visibleStarAltitudeThresholdDeg.toStringAsFixed(0)} grados de altitud.';
    }

    return null;
  }

  String _insufficientStarsMessage(CalibrationMethod method) {
    if (method == CalibrationMethod.oneStar) {
      return 'No hay estrellas visibles para calibracion con ${method.title}. Se requiere al menos una estrella sobre ${visibleStarAltitudeThresholdDeg.toStringAsFixed(0)} grados de altitud.';
    }
    return 'No hay suficientes estrellas visibles para calibracion con ${method.title}. Se requieren al menos ${method.requiredPointCount} estrellas sobre ${visibleStarAltitudeThresholdDeg.toStringAsFixed(0)} grados de altitud.';
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
    return 'Advertencia: $starName esta a ${distanceDeg.toStringAsFixed(1)} grados de una referencia anterior. La calibracion puede ser menos util.';
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
