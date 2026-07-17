class IssPass {
  final DateTime? startTime;
  final DateTime? endTime;
  final Duration? duration;
  final String startDirection;
  final String maxElevation;
  final String endDirection;
  final String visibilityLabel;
  final bool isPotentiallyVisible;
  final bool isPlaceholder;
  final String note;

  const IssPass({
    this.startTime,
    this.endTime,
    this.duration,
    required this.startDirection,
    required this.maxElevation,
    required this.endDirection,
    required this.visibilityLabel,
    required this.isPotentiallyVisible,
    required this.isPlaceholder,
    required this.note,
  });
}

class IssPassResult {
  final List<IssPass> passes;
  final bool hasFreshOrbitalData;
  final String message;

  const IssPassResult({
    required this.passes,
    required this.hasFreshOrbitalData,
    required this.message,
  });
}
