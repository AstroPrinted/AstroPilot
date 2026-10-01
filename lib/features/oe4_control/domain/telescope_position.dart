import '../../observation/domain/utils/angle_math.dart';

/// Coordenadas del motor (grados). Es la misma escala que usan GOTO,
/// SET_POSITION y STATUS del firmware OE4.
typedef MotorAngles = ({double altitude, double azimuth});

MotorAngles normalizeMotorAngles(double altitude, double azimuth) => (
  altitude: altitude.clamp(-90.0, 90.0).toDouble(),
  azimuth: normalizeDegrees360(azimuth),
);

/// Diferencia de azimut por el camino más corto, en (-180, 180].
double azimuthDelta(double from, double to) {
  final delta = normalizeDegrees360(to - from + 180.0) - 180.0;
  return delta == -180.0 ? 180.0 : delta;
}

/// Mayor de los dos errores por eje, en grados.
double axisError(MotorAngles a, MotorAngles b) {
  final alt = (a.altitude - b.altitude).abs();
  final az = azimuthDelta(a.azimuth, b.azimuth).abs();
  return alt > az ? alt : az;
}

enum MoveOutcomeKind {
  /// El firmware envió `GOTO/NUDGE/HOME Completado`.
  completed,

  /// El encoder quedó dentro de la tolerancia de la app, aunque el firmware
  /// todavía no lo haya declarado completado.
  arrived,

  /// El encoder dejó de avanzar lejos del objetivo (falta de torque, carga
  /// pesada o traba mecánica). El firmware sigue intentando llegar.
  stalled,
}

class MoveOutcome {
  final MoveOutcomeKind kind;
  final String command;
  final MotorAngles? target;
  final MotorAngles? reached;

  const MoveOutcome({
    required this.kind,
    required this.command,
    this.target,
    this.reached,
  });

  /// Distancia entre el objetivo y la última posición del encoder.
  double? get errorDeg {
    final target = this.target;
    final reached = this.reached;
    if (target == null || reached == null) return null;
    return axisError(target, reached);
  }

  bool get isStalled => kind == MoveOutcomeKind.stalled;
}

/// One entry of the movement history shown in Control OE4 for diagnosis.
class MoveRecord {
  final DateTime startedAt;
  final String command;
  final MotorAngles? from;
  final MotorAngles? target;
  final MotorAngles? reached;
  final MoveOutcomeKind? kind;
  final String? error;
  final Duration duration;

  const MoveRecord({
    required this.startedAt,
    required this.command,
    required this.from,
    required this.target,
    required this.reached,
    required this.kind,
    required this.error,
    required this.duration,
  });
}

/// Decide cuándo un movimiento terminó a partir de lecturas de STATUS.
///
/// El firmware solo informa `Completado` cuando el PID queda dentro de 6
/// pulsos (~0.05°). Con un telescopio pesado eso puede no ocurrir nunca, así
/// que la app considera terminado el movimiento cuando el encoder está dentro
/// de [toleranceDeg] o cuando deja de ACERCARSE al objetivo durante
/// [stallWindow]. Antes de declararlo trabado le da [startGrace] para
/// arrancar: con carga pesada el PID tarda en vencer la fricción estática.
class ArrivalDetector {
  // Igual que la tolerancia del PID del firmware (6 pulsos, ~0.05°).
  static const double defaultToleranceDeg = 0.05;
  static const double defaultStallMotionDeg = 0.05;
  static const Duration defaultStallWindow = Duration(seconds: 2);
  static const Duration defaultStartGrace = Duration(seconds: 5);

  final MotorAngles? target;
  final double toleranceDeg;
  final double stallMotionDeg;
  final Duration stallWindow;
  final Duration startGrace;
  final int requiredInsideSamples;

  final List<({Duration at, double progress})> _samples = [];
  MotorAngles? _first;
  MotorAngles? _last;
  bool _started = false;
  int _insideSamples = 0;

  ArrivalDetector({
    required this.target,
    this.toleranceDeg = defaultToleranceDeg,
    this.stallMotionDeg = defaultStallMotionDeg,
    this.stallWindow = defaultStallWindow,
    this.startGrace = defaultStartGrace,
    this.requiredInsideSamples = 2,
  });

  MotorAngles? get lastPosition => _last;

  /// [elapsed] es el tiempo desde que se envió el movimiento.
  MoveOutcomeKind? addSample(Duration elapsed, MotorAngles position) {
    final first = _first ??= position;
    _last = position;
    if (!_started && axisError(first, position) >= stallMotionDeg) {
      _started = true;
    }

    final target = this.target;
    if (target != null && axisError(target, position) <= toleranceDeg) {
      _insideSamples++;
      return _insideSamples >= requiredInsideSamples
          ? MoveOutcomeKind.arrived
          : null;
    }
    _insideSamples = 0;

    // Progress = remaining distance to the target (lower is better), measured
    // linearly like the firmware PID does: from 0° to 200° it turns through
    // 1°, 2°, 3°… even though the short way round would be 160° backwards.
    // HOME has no known target, so any displacement counts as progress.
    final progress = target != null
        ? _linearDistance(target, position)
        : -axisError(first, position);
    _samples.add((at: elapsed, progress: progress));

    if (!_started && elapsed < startGrace) return null;
    final windowStart = elapsed - stallWindow;
    final reference = _samples.lastIndexWhere((s) => s.at <= windowStart);
    if (reference < 0) return null;
    _samples.removeRange(0, reference);
    final before = _samples.first.progress;
    final advanced = _samples.any((s) => before - s.progress >= stallMotionDeg);
    return advanced ? null : MoveOutcomeKind.stalled;
  }

  static double _linearDistance(MotorAngles a, MotorAngles b) {
    final alt = (a.altitude - b.altitude).abs();
    final az = (a.azimuth - b.azimuth).abs();
    return alt > az ? alt : az;
  }
}
