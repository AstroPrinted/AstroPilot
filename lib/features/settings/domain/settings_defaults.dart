class SettingsDefaults {
  static const double defaultLat = -33.4489;
  static const double defaultLon = -70.6693;
  static const double defaultHeight = 0.0;

  static const double chileLatMin = -56.0;
  static const double chileLatMax = -17.0;
  static const double chileLonMin = -75.0;
  static const double chileLonMax = -66.0;

  static final DateTime minPlanningDate = DateTime(1900);
  static final DateTime maxPlanningDate = DateTime(2100, 12, 31, 23, 59);
}

class SettingsKeys {
  static const String autoMode = 'settings_auto_mode';
  static const String manualLat = 'settings_manual_lat';
  static const String manualLon = 'settings_manual_lon';
  static const String manualHeight = 'settings_manual_height';
  static const String useCustomTime = 'settings_use_custom_time';
  static const String customTimeIso = 'settings_custom_time_iso';
}
