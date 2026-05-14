import '../settings_defaults.dart';

enum LocationStatus {
  gpsActive,
  manual,
  gpsDisabled,
  permissionDenied,
  outOfBounds,
}

class ObserverState {
  final bool isAutoMode;
  final double latDeg;
  final double lonDeg;
  final double heightMeters;
  final DateTime observerTime;
  final bool isCustomTime;
  final LocationStatus status;
  final String? errorMessage;
  final bool isLoadingLocation;

  const ObserverState({
    required this.isAutoMode,
    required this.latDeg,
    required this.lonDeg,
    required this.heightMeters,
    required this.observerTime,
    required this.isCustomTime,
    required this.status,
    this.errorMessage,
    this.isLoadingLocation = false,
  });

  factory ObserverState.defaults() {
    return ObserverState(
      isAutoMode: false,
      latDeg: SettingsDefaults.defaultLat,
      lonDeg: SettingsDefaults.defaultLon,
      heightMeters: SettingsDefaults.defaultHeight,
      observerTime: DateTime.now().toUtc(),
      isCustomTime: false,
      status: LocationStatus.manual,
    );
  }

  bool get isWithinChileBounds => isWithinChile(latDeg, lonDeg);

  DateTime get effectiveUtc =>
      isCustomTime ? observerTime : DateTime.now().toUtc();

  ObserverState copyWith({
    bool? isAutoMode,
    double? latDeg,
    double? lonDeg,
    double? heightMeters,
    DateTime? observerTime,
    bool? isCustomTime,
    LocationStatus? status,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? isLoadingLocation,
  }) {
    return ObserverState(
      isAutoMode: isAutoMode ?? this.isAutoMode,
      latDeg: latDeg ?? this.latDeg,
      lonDeg: lonDeg ?? this.lonDeg,
      heightMeters: heightMeters ?? this.heightMeters,
      observerTime: observerTime ?? this.observerTime,
      isCustomTime: isCustomTime ?? this.isCustomTime,
      status: status ?? this.status,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      isLoadingLocation: isLoadingLocation ?? this.isLoadingLocation,
    );
  }

  static bool isWithinChile(double latDeg, double lonDeg) {
    return latDeg >= SettingsDefaults.chileLatMin &&
        latDeg <= SettingsDefaults.chileLatMax &&
        lonDeg >= SettingsDefaults.chileLonMin &&
        lonDeg <= SettingsDefaults.chileLonMax;
  }
}
