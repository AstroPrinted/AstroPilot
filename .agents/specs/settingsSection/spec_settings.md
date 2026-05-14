# Spec: Configuración, Planning Mode y Servicios de Ubicación/Tiempo

## User Story
Como usuario de AstroPilot, quiero configurar mi ubicación (automática vía GPS o manual) y seleccionar la fecha/hora de observación (presente o futura para planificación), para que el motor de efemérides reciba parámetros precisos del observador y calcule correctamente las coordenadas celestes.

## Business Rules
- **`SettingsService` es la única fuente de verdad** sobre "dónde" y "cuándo" está el observador. Ningún otro servicio consulta GPS, permisos, ni el reloj del dispositivo directamente. Todos consumen `SettingsService`.
- **Restricción geográfica estricta (Chile):** Las coordenadas válidas se limitan al territorio nacional:
  - Latitud: `[-56.0, -17.0]`
  - Longitud: `[-75.0, -66.0]`
  - Cualquier coordenada fuera de este rango — sea GPS o manual — se rechaza con fallback al último estado válido (o default Santiago).
- **Modo Automático (GPS) vs Manual:** Un toggle controla la fuente de ubicación. En modo automático, los campos manuales se deshabilitan. En modo manual, el GPS se desactiva para ahorro de batería.
- **Planning Mode:** El usuario puede seleccionar una fecha/hora futura para planificar observaciones. Por defecto se usa `DateTime.now()`. Un toggle "Usar hora actual" restaura el tiempo presente. Internamente todo se convierte a UTC.
- **Persistencia con `shared_preferences`:** La configuración del usuario se guarda y restaura entre sesiones. Si es la primera ejecución, se usan defaults: modo manual, Santiago (-33.4489, -70.6693), altura 0m, hora actual.
- **Permisos:** Se usa `permission_handler` para `Permission.location`. Si el permiso fue denegado permanentemente, se dirige al usuario a Settings del sistema. La app **nunca se bloquea** — siempre hay fallback a modo manual.
- **GPS desactivado a nivel de sistema:** Se detecta `LocationServiceDisabledException` y se hace fallback automático a modo manual con última ubicación válida + SnackBar informativo.
- **Inyección al motor de efemérides:** El `SettingsService` expone un `Observer` (de `geoengine`) construido con los parámetros actuales. El `EphemerisService` consume este `Observer` sin conocer su origen (GPS o manual).
- **Seguridad Solar:** El `SettingsService` no tiene responsabilidad sobre el bloqueo solar. Eso se resuelve a nivel de repositorio/UI antes de invocar efemérides.

---

## Data Model

### Estado del SettingsService
```dart
enum LocationStatus {
  gpsActive,       // GPS habilitado y obteniendo coordenadas
  manual,          // Modo manual activo
  gpsDisabled,     // GPS apagado a nivel de sistema
  permissionDenied, // Permiso de ubicación denegado
  outOfBounds,     // Coordenadas fuera de Chile
}

class ObserverState {
  final bool isAutoMode;
  final double latDeg;
  final double lonDeg;
  final double heightMeters;
  final DateTime observerTime;    // UTC
  final bool isCustomTime;        // true = Planning Mode activo
  final LocationStatus status;
  final String? errorMessage;

  const ObserverState({
    required this.isAutoMode,
    required this.latDeg,
    required this.lonDeg,
    required this.heightMeters,
    required this.observerTime,
    required this.isCustomTime,
    required this.status,
    this.errorMessage,
  });

  /// Construye un Observer de geoengine listo para el motor de efemérides.
  Observer toGeoengineObserver() => Observer(latDeg, lonDeg, heightMeters);

  /// Valida que las coordenadas estén dentro del territorio chileno.
  bool isWithinChileBounds() {
    return latDeg >= -56.0 && latDeg <= -17.0 &&
           lonDeg >= -75.0 && lonDeg <= -66.0;
  }
}
```

### Defaults
```dart
class SettingsDefaults {
  static const double defaultLat = -33.4489;    // Santiago
  static const double defaultLon = -70.6693;
  static const double defaultHeight = 0.0;
  static const double chileLatMin = -56.0;
  static const double chileLatMax = -17.0;
  static const double chileLonMin = -75.0;
  static const double chileLonMax = -66.0;
}
```

### SharedPreferences Keys
```dart
class SettingsKeys {
  static const String autoMode = 'settings_auto_mode';
  static const String manualLat = 'settings_manual_lat';
  static const String manualLon = 'settings_manual_lon';
  static const String manualHeight = 'settings_manual_height';
  static const String useCustomTime = 'settings_use_custom_time';
  static const String customTimeIso = 'settings_custom_time_iso';
}
```

---

## Servicio: `SettingsService` (Singleton, ChangeNotifier)

```dart
class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._();
  factory SettingsService() => _instance;
  SettingsService._();

  Future<void> init() async { /* carga desde SharedPreferences */ }

  bool get isAutoMode => _state.isAutoMode;
  ObserverState get state => _state;
  Observer get observer => _state.toGeoengineObserver();

  Future<void> toggleAutoMode(bool enabled) async { /* lógica GPS/manual */ }
  Future<void> setManualCoordinates(double lat, double lon, double height) async { /* valida Chile bounds */ }
  Future<void> setCustomTime(DateTime utc) async { /* Planning Mode */ }
  Future<void> resetToCurrentTime() async { /* vuelve a DateTime.now().toUtc() */ }

  /// Obtiene posición GPS, valida bounds Chile, actualiza estado.
  Future<void> _fetchGpsPosition() async { /* geolocator + validación */ }

  /// Stream para que otras pantallas reaccionen a cambios de ubicación.
  Stream<ObserverState> get stateStream => _controller.stream;
}
```

---

## Happy Paths (Gherkin)

### HP-1: Configuración en modo manual con coordenadas válidas (Chile)
```gherkin
Feature: Manual Location Configuration

  Scenario: User enters valid Chile coordinates manually
    Given SettingsService is in manual mode
    And the user enters Lat = -33.4489, Lon = -70.6693, Height = 570
    And these coordinates are within Chile bounds (Lat [-56.0, -17.0], Lon [-75.0, -66.0])
    When the user taps "Guardar"
    Then the coordinates are saved to SharedPreferences
    And SettingsService updates its ObserverState with the new values
    And LocationStatus is set to manual
    And the UI shows a confirmation indicator

  Scenario: User enters valid coordinates for southern Chile (Punta Arenas)
    Given SettingsService is in manual mode
    And the user enters Lat = -53.1638, Lon = -70.9171, Height = 37
    When the user taps "Guardar"
    Then the coordinates are accepted (within Chile bounds)
    And the ObserverState is updated successfully

  Scenario: User enters valid coordinates for northern Chile (Arica)
    Given SettingsService is in manual mode
    And the user enters Lat = -18.4746, Lon = -70.2979, Height = 50
    When the user taps "Guardar"
    Then the coordinates are accepted (within Chile bounds)
    And the ObserverState is updated successfully
```

### HP-2: Modo automático GPS activo con ubicación válida en Chile
```gherkin
Feature: Automatic GPS Location

  Scenario: GPS returns valid Chile coordinates
    Given the user toggles "Ubicación Automática (GPS)" to ON
    And the device has location permission granted
    And GPS is enabled at system level
    When geolocator returns a position at Lat = -33.4489, Lon = -70.6693
    And the coordinates are within Chile bounds
    Then SettingsService updates ObserverState with GPS coordinates
    And LocationStatus is set to gpsActive
    And manual input fields are visually disabled
    And the coordinates are NOT persisted as manual (GPS is live)

  Scenario: GPS position is fetched once (Single Fetch)
    Given SettingsService is in auto mode with valid GPS position
    When the user toggles GPS OFF and then ON again
    And geolocator.getCurrentPosition() is called (single fetch, NO stream)
    Then SettingsService updates ObserverState with the new coordinates
    And no continuous position stream is active (battery saving)
```

### HP-3: Planning Mode — Selección de fecha/hora futura
```gherkin
Feature: Planning Mode (Custom Date/Time)

  Scenario: User selects a future date for observation planning
    Given SettingsService is using current time (isCustomTime = false)
    When the user opens the DateTimePicker and selects 2026-12-21T22:00:00 local
    Then SettingsService converts the time to UTC
    And sets isCustomTime = true
    And stores the custom time in SharedPreferences
    And the UI displays "Planificando: 21/12/2026 22:00"
    And the EphemerisService will use this custom time for calculations

  Scenario: User resets to current time
    Given SettingsService is in Planning Mode with a custom future date
    When the user toggles "Usar hora actual"
    Then isCustomTime is set to false
    And observerTime is set to DateTime.now().toUtc()
    And the custom time is cleared from SharedPreferences
    And the UI displays "Hora actual"
```

### HP-4: Persistencia entre sesiones
```gherkin
Feature: Settings Persistence

  Scenario: App restores manual settings on cold start
    Given the user previously saved Lat = -30.0, Lon = -71.0, Height = 100 in manual mode
    And the settings were persisted to SharedPreferences
    When the app is closed and reopened
    Then SettingsService.init() loads the saved values
    And the UI shows the previously saved coordinates
    And isAutoMode is restored to false

  Scenario: App restores Planning Mode custom time on cold start
    Given the user previously set a custom time of 2026-06-21T03:00:00Z
    And isCustomTime was persisted as true
    When the app is reopened
    Then SettingsService restores the custom time from SharedPreferences
    And the UI shows the previously selected date/time
    And Planning Mode remains active

  Scenario: First launch uses Santiago defaults
    Given the app is launched for the first time
    And no settings exist in SharedPreferences
    When SettingsService.init() runs
    Then isAutoMode defaults to false (manual)
    And lat = -33.4489, lon = -70.6693, height = 0.0
    And isCustomTime defaults to false (current time)
    And observerTime = DateTime.now().toUtc()
```

### HP-5: Integración con EphemerisService
```gherkin
Feature: Observer Injection to Ephemeris Engine

  Scenario: EphemerisService receives GPS-based Observer
    Given SettingsService is in auto mode with GPS coordinates Lat = -33.4489, Lon = -70.6693
    When EphemerisService requests the current Observer from SettingsService
    Then it receives an Observer with the GPS-derived coordinates
    And the EphemerisEngine computes Alt/Az using those exact coordinates
    And the engine does NOT call geolocator directly

  Scenario: EphemerisService receives manual Observer
    Given SettingsService is in manual mode with Lat = -30.0, Lon = -71.0
    When EphemerisService requests the current Observer from SettingsService
    Then it receives an Observer with the manual coordinates
    And the EphemerisEngine computes Alt/Az using those exact coordinates
    And the engine does NOT know or care that the values are manual

  Scenario: EphemerisService uses custom Planning Mode time
    Given SettingsService has isCustomTime = true with observerTime = 2026-12-21T22:00:00Z
    When EphemerisService computes coordinates
    Then it uses the custom observerTime instead of DateTime.now().toUtc()
    And the computed Alt/Az reflects the future date/time
```

---

## Sad Paths (Gherkin)

### SP-1: Coordenadas manuales fuera de Chile
```gherkin
Feature: Manual Input Validation (Chile Bounds)

  Scenario: User enters latitude outside Chile (too far north)
    Given SettingsService is in manual mode
    And the user enters Lat = -15.0 (north of Chile border at -17.0)
    When the input is validated
    Then the TextField shows errorText: "Ubicación fuera del territorio nacional (Chile)"
    And the "Guardar" button is disabled
    And the ObserverState is NOT updated

  Scenario: User enters latitude outside Chile (too far south)
    Given SettingsService is in manual mode
    And the user enters Lat = -58.0 (south of Chile border at -56.0)
    When the input is validated
    Then the TextField shows errorText: "Ubicación fuera del territorio nacional (Chile)"
    And the "Guardar" button is disabled

  Scenario: User enters longitude outside Chile (too far east)
    Given SettingsService is in manual mode
    And the user enters Lon = -60.0 (east of Chile border at -66.0)
    When the input is validated
    Then the TextField shows errorText: "Ubicación fuera del territorio nacional (Chile)"
    And the "Guardar" button is disabled

  Scenario: User enters longitude outside Chile (too far west)
    Given SettingsService is in manual mode
    And the user enters Lon = -80.0 (west of Chile border at -75.0)
    When the input is validated
    Then the TextField shows errorText: "Ubicación fuera del territorio nacional (Chile)"
    And the "Guardar" button is disabled

  Scenario: User enters completely invalid latitude (e.g., 150°)
    Given SettingsService is in manual mode
    And the user enters Lat = 150.0
    When the input is validated
    Then the TextField shows errorText: "Ubicación fuera del territorio nacional (Chile)"
    And the "Guardar" button is disabled
    And no exception is thrown (graceful validation)

  Scenario: User enters boundary values exactly at Chile limits
    Given SettingsService is in manual mode
    And the user enters Lat = -17.0, Lon = -66.0 (northeast corner)
    When the input is validated
    Then the coordinates are accepted (boundary is inclusive)
    And the "Guardar" button is enabled

  Scenario: User enters Lat = -56.0, Lon = -75.0 (southwest corner)
    Given SettingsService is in manual mode
    And the user enters these exact boundary values
    When the input is validated
    Then the coordinates are accepted (boundary is inclusive)
```

### SP-2: GPS devuelve ubicación fuera de Chile
```gherkin
Feature: GPS Out-of-Bounds Handling

  Scenario: GPS returns coordinates outside Chile territory
    Given SettingsService is in auto mode
    And geolocator returns Lat = 40.7128, Lon = -74.0060 (New York, USA)
    When the position is validated against Chile bounds
    Then the coordinates are rejected
    And SettingsService falls back to the last valid manual coordinates (or Santiago defaults)
    And LocationStatus is set to outOfBounds
    And a SnackBar displays: "Ubicación GPS fuera de Chile — usando ubicación manual"
    And the app automatically switches to manual mode

  Scenario: GPS returns coordinates just outside Chile border
    Given SettingsService is in auto mode
    And geolocator returns Lat = -16.5, Lon = -69.0 (just north of Arica, in Bolivia)
    When the position is validated against Chile bounds
    Then the coordinates are rejected
    And SettingsService falls back to the last valid coordinates
    And LocationStatus is set to outOfBounds
    And the user is notified via SnackBar
```

### SP-3: GPS desactivado a nivel de sistema
```gherkin
Feature: GPS System-Level Disabled

  Scenario: User toggles GPS mode but device GPS is off
    Given SettingsService is in manual mode
    When the user toggles "Ubicación Automática (GPS)" to ON
    And geolocator throws LocationServiceDisabledException
    Then SettingsService catches the exception
    And LocationStatus is set to gpsDisabled
    And the app falls back to manual mode with last valid coordinates
    And a SnackBar displays: "GPS no disponible — usando ubicación manual"
    And the toggle visually reverts to OFF

  Scenario: GPS was active but user disables it at system level while app is running
    Given SettingsService is in auto mode with a previously fetched GPS position
    When the user disables location services at the OS level
    And the user toggles GPS OFF and then ON to force a new fetch
    And geolocator.getCurrentPosition() throws LocationServiceDisabledException
    Then SettingsService detects the service disable
    And falls back to manual mode with last valid coordinates
    And LocationStatus is set to gpsDisabled
    And the UI updates to reflect the status change
```

### SP-4: Permiso de ubicación denegado
```gherkin
Feature: Location Permission Handling

  Scenario: User denies location permission on first request
    Given the user toggles GPS mode for the first time
    And the system shows the permission dialog
    When the user taps "Deny"
    Then SettingsService receives PermissionStatus.denied
    And LocationStatus is set to permissionDenied
    And the app falls back to manual mode
    And a SnackBar displays: "Permiso de ubicación denegado — usa coordenadas manuales"

  Scenario: User permanently denies location permission
    Given the user has previously denied location permission multiple times
    When the user toggles GPS mode
    And permission_handler returns PermissionStatus.permanentlyDenied
    Then SettingsService shows an AlertDialog explaining why location is needed
    And the dialog offers "Abrir Configuración" to open system settings
    And if the user declines, the app stays in manual mode
    And the app does NOT crash or block functionality

  Scenario: User grants permission after initially denying
    Given the user previously denied location permission
    And is now in manual mode
    When the user toggles GPS mode again
    And grants the permission this time
    And geolocator returns a valid Chile position
    Then SettingsService switches to auto mode
    And LocationStatus is set to gpsActive
    And the ObserverState updates with GPS coordinates
```

### SP-5: Altura negativa o inválida
```gherkin
Feature: Height Validation

  Scenario: User enters negative height
    Given SettingsService is in manual mode
    And the user enters Height = -50
    When the input is validated
    Then the TextField shows errorText: "La altura debe ser un valor positivo"
    And the "Guardar" button is disabled

  Scenario: User enters non-numeric height
    Given SettingsService is in manual mode
    And the user enters Height = "abc"
    When the input is validated
    Then the TextField shows errorText: "Ingresa un número válido"
    And the "Guardar" button is disabled

  Scenario: User enters height = 0 (sea level)
    Given SettingsService is in manual mode
    And the user enters Height = 0
    When the input is validated
    Then the value is accepted (sea level is valid)
    And the "Guardar" button is enabled
```

### SP-6: Planning Mode con fecha inválida
```gherkin
Feature: Planning Mode Time Validation

  Scenario: User selects a date too far in the past
    Given SettingsService is in Planning Mode
    When the user selects a date before 1900-01-01
    Then the DateTimePicker does not allow selection before 1900
    And the earliest selectable date is 1900-01-01

  Scenario: User selects a date too far in the future
    Given SettingsService is in Planning Mode
    When the user selects a date after 2100-12-31
    Then the DateTimePicker does not allow selection after 2100
    And the latest selectable date is 2100-12-31
```

---

## Estructura de Archivos

```
lib/
├── services/
│   └── settings_service.dart           # Singleton ChangeNotifier + SharedPreferences
├── models/
│   └── observer_state.dart             # ObserverState, LocationStatus, SettingsDefaults
└── screens/
    └── settings_screen.dart            # UI: toggles, TextFields, DateTimePicker, status chip

test/
├── settings/
│   ├── settings_service_test.dart      # Tests unitarios del servicio (persistencia, validación)
│   ├── observer_state_test.dart        # Tests de Chile bounds validation
│   └── settings_screen_test.dart       # Widget tests de la UI
└── fixtures/
    └── (no fixtures needed for this module)
```

---

## Preguntas de Clarificación
*(Resueltas — spec cerrado)*

1. **Zona horaria en la UI:** La UI muestra siempre la hora local de Chile (GMT-3/GMT-4 según horario de verano). Internamente, `SettingsService` convierte y entrega siempre `DateTime` en UTC al motor de efemérides.
2. **Altitud por GPS:** Se extrae la altitud de `geolocator.Position.altitude`. Si viene `null` o es imprecisa, se usa `0` metros como fallback. No es crítico para apuntado amateur.
3. **Frecuencia del GPS (Single Fetch):** NO hay stream de posición. El GPS se consulta **una sola vez** (`geolocator.getCurrentPosition()`) cuando el usuario activa el toggle a ON, o al abrir la app con el toggle ya activado. Si el usuario viaja, debe apagar y encender el toggle para forzar una nueva lectura. Esto ahorra batería significativamente.
