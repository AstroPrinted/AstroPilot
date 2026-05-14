# Spec: Motor de Efemérides y Validación Algorítmica (OE3)

## User Story
Como usuario de AstroPilot, quiero que las coordenadas horizontales (Alt/Az) de cualquier objeto celeste se calculen en tiempo real con precisión sub-grado (< 0.5° de error contra JPL/Stellarium), para que el telescopio apunte correctamente al objetivo seleccionado desde el catálogo.

## Business Rules
- El motor es una **función pura agnóstica**: no conoce la UI, ni BLE, ni el origen de los datos. Solo recibe parámetros crudos (`RA/Dec J2000`, `DateTime UTC`, `Lat/Lon/Height`) y retorna `Alt/Az`.
- **Pipeline obligatorio e inmutable:** Input (J2000) → Precesión + Nutación (JNow) → Conversión Ecuatorial a Horizontal (`geoengine.horizon()`) → Refracción Atmosférica (Meeus, condiciones estándar) → Output (Alt/Az).
- La precesión J2000 → JNow es **no negociable**. Saltarla causa >21 arcmin de error de apuntado.
- Para **cuerpos del sistema solar**, se usa `geoengine.equator(body, date, observer, ofdate: true, aberration: true)` que ya incluye precesión+nutación+aberración internamente.
- Para **objetos de catálogo profundo y estrellas** (coordenadas fijas J2000 desde JSON), se construye un vector cartesiano J2000 y se aplica `geoengine.gyration()` para obtener el vector JNow, luego se convierte a Alt/Az.
- La **refracción atmosférica** usa `RefractionType.normal` de geoengine (condiciones estándar: 1013.25 hPa, 10°C). El output expone tanto Alt/Az con refracción como sin refracción (raw) para debugging.
- **Inyección de ubicación:** Los parámetros del observador (`Lat/Lon/Height`) y la hora (`DateTime`) son provistos por el `SettingsService` (definido en otro spec). El `SettingsService` decide si usa GPS automático o valores manuales del usuario. El motor **NO** consulta GPS ni conoce `SettingsService`; solo recibe los valores como parámetros.
- **El Sol nunca pasa por este motor.** El bloqueo de seguridad del Sol se resuelve a nivel de repositorio/UI antes de invocar el cálculo.
- **Actualización en tiempo real:** El `EphemerisService` expone un `Stream<AltAzResult>` que emite cada 1 segundo. La UI (`CelestialDetailScreen`) se suscribe vía `StreamBuilder`. El timer se pausa cuando la pantalla no está visible.
- **Validación académica (OE3):** Un test automatizado con 500 puntos de Ground Truth (JPL Horizons / Stellarium) debe validar que el error angular máximo sea < 0.5°. Se reportan además RMSE y error medio como métricas secundarias.
- **Condiciones del Ground Truth:** El dataset de validación se genera externamente con condiciones atmosféricas estándar (1013.25 hPa, 10°C) para que la comparación contra `RefractionType.normal` de geoengine sea una validación justa 1 a 1.
- **Cobertura del dataset:** Los 500 puntos incluyen objetos en todas las declinaciones, todas las horas de RA, observadores en diferentes latitudes (incluyendo hemisferio sur), objetos cerca del horizonte (alt < 5°), objetos en el cenit, **objetos bajo el horizonte (alt < 0°)**, y casos límite de azimut cruzando el norte.

---

## Data Model

### Resultado del Motor
```dart
class AltAzResult {
  final double altitudeDeg;       // Altitud con refracción (-90..+90)
  final double azimuthDeg;        // Azimut con refracción (0..360, N=0, E=90)
  final double altitudeRawDeg;    // Altitud sin refracción
  final double azimuthRawDeg;     // Azimut sin refracción
  final DateTime computedAt;      // Timestamp UTC del cálculo

  const AltAzResult({
    required this.altitudeDeg,
    required this.azimuthDeg,
    required this.altitudeRawDeg,
    required this.azimuthRawDeg,
    required this.computedAt,
  });
}
```

### Entrada del Motor
```dart
class EphemerisInput {
  final double raJ2000Hours;      // Right ascension J2000 en horas (0..24)
  final double decJ2000Deg;       // Declination J2000 en grados (-90..+90)
  final DateTime utc;             // Fecha/hora UTC del cálculo
  final double latDeg;            // Latitud del observador (-90..+90)
  final double lonDeg;            // Longitud del observador (-180..+180, Este+)
  final double heightMeters;      // Altura sobre nivel del mar

  const EphemerisInput({
    required this.raJ2000Hours,
    required this.decJ2000Deg,
    required this.utc,
    required this.latDeg,
    required this.lonDeg,
    required this.heightMeters,
  });
}
```

---

## Motor: `EphemerisEngine` (Clase Estática, Función Pura)

```dart
class EphemerisEngine {
  /// Pipeline completo: J2000 → JNow → Alt/Az → Refracción
  /// Función pura: sin estado, sin side-effects, sin dependencias de Flutter.
  static AltAzResult computeAltAz(EphemerisInput input) {
    // 1. Construir Observer de geoengine
    final observer = Observer(input.latDeg, input.lonDeg, input.heightMeters);

    // 2. Construir vector J2000 desde RA/Dec
    final raRad = input.raJ2000Hours * 15.0 * (pi / 180.0);
    final decRad = input.decJ2000Deg * (pi / 180.0);
    final j2000Vector = [
      cos(decRad) * cos(raRad),
      cos(decRad) * sin(raRad),
      sin(decRad),
    ];

    // 3. Precesión + Nutación (J2000 → JNow) vía gyration
    final astroTime = AstroTime(input.utc);
    final jNowVector = gyration(j2000Vector, astroTime, PrecessDirection.From2000);

    // 4. Convertir vector JNow a RA/Dec en horas/grados
    final raJNowRad = atan2(jNowVector[1], jNowVector[0]);
    final decJNowRad = asin(jNowVector[2]);
    final raJNowHours = ((raJNowRad * 180.0 / pi) / 15.0) % 24.0;
    final decJNowDeg = decJNowRad * 180.0 / pi;

    // 5. Conversión a Horizontal con refracción normal
    final withRefraction = HorizontalCoordinates.horizon(
      input.utc,
      observer,
      raJNowHours,
      decJNowDeg,
      RefractionType.normal,
    );

    // 6. Conversión a Horizontal sin refracción
    final withoutRefraction = HorizontalCoordinates.horizon(
      input.utc,
      observer,
      raJNowHours,
      decJNowDeg,
      RefractionType.airless,
    );

    return AltAzResult(
      altitudeDeg: withRefraction.altitude,
      azimuthDeg: withRefraction.azimuth,
      altitudeRawDeg: withoutRefraction.altitude,
      azimuthRawDeg: withoutRefraction.azimuth,
      computedAt: input.utc,
    );
  }

  /// Versión optimizada para cuerpos del sistema solar.
  /// Usa geoengine.equator() directamente (ya incluye precesión+aberración).
  static AltAzResult computeSolarBodyAltAz({
    required Body body,
    required DateTime utc,
    required double latDeg,
    required double lonDeg,
    required double heightMeters,
  }) {
    final observer = Observer(latDeg, lonDeg, heightMeters);
    final eq = equator(body, utc, observer, true, true);

    final withRefraction = HorizontalCoordinates.horizon(
      utc, observer, eq.ra, eq.dec, RefractionType.normal,
    );
    final withoutRefraction = HorizontalCoordinates.horizon(
      utc, observer, eq.ra, eq.dec, RefractionType.airless,
    );

    return AltAzResult(
      altitudeDeg: withRefraction.altitude,
      azimuthDeg: withRefraction.azimuth,
      altitudeRawDeg: withoutRefraction.altitude,
      azimuthRawDeg: withoutRefraction.azimuth,
      computedAt: utc,
    );
  }
}
```

---

## Servicio: `EphemerisService` (Singleton, Lifecycle-Aware)

```dart
class EphemerisService {
  static final EphemerisService _instance = EphemerisService._();
  factory EphemerisService() => _instance;
  EphemerisService._();

  Timer? _timer;
  final _controller = StreamController<AltAzResult>.broadcast();
  Stream<AltAzResult> get stream => _controller.stream;

  CelestialObject? _currentObject;

  void startTracking(CelestialObject object, Observer observer) {
    stopTracking();
    _currentObject = object;
    _emitOnce(observer);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _emitOnce(observer);
    });
  }

  void stopTracking() {
    _timer?.cancel();
    _timer = null;
  }

  void _emitOnce(Observer observer) {
    final object = _currentObject;
    if (object == null) return;

    final utc = DateTime.now().toUtc();
    AltAzResult result;

    if (object is SolarSystemBody) {
      result = EphemerisEngine.computeSolarBodyAltAz(
        body: object.geoengineBody,
        utc: utc,
        latDeg: observer.latitude,
        lonDeg: observer.longitude,
        heightMeters: observer.height,
      );
    } else {
      final raHours = _extractRaHours(object);
      final decDeg = _extractDecDeg(object);
      result = EphemerisEngine.computeAltAz(EphemerisInput(
        raJ2000Hours: raHours,
        decJ2000Deg: decDeg,
        utc: utc,
        latDeg: observer.latitude,
        lonDeg: observer.longitude,
        heightMeters: observer.height,
      ));
    }

    _controller.add(result);
  }

  double _extractRaHours(CelestialObject object) {
    if (object is DeepSkyObject) return object.raJ2000Hours;
    if (object is CalibrationStar) return object.raJ2000Hours;
    throw ArgumentError('Unsupported object type for RA extraction');
  }

  double _extractDecDeg(CelestialObject object) {
    if (object is DeepSkyObject) return object.decJ2000Degrees;
    if (object is CalibrationStar) return object.decJ2000Degrees;
    throw ArgumentError('Unsupported object type for Dec extraction');
  }

  void dispose() {
    stopTracking();
    _controller.close();
  }
}
```

---

## Integración con UI (`CelestialDetailScreen`)

### Flujo de datos
```
SettingsService (GPS o manual)
       │
       ▼ (Observer + DateTime)
EphemerisService.startTracking(object, observer)
       │
       ▼ Stream<AltAzResult> cada 1s
CelestialDetailScreen (StreamBuilder)
       │
       ├── Muestra: Alt = +45.23°, Az = 180.67°
       └── Botón "Apuntar" → envía GOTO:alt,az por BLE
```

### Reglas de Lifecycle
- `initState()` → `EphemerisService.startTracking(object, observerFromSettings)`
- `dispose()` → `EphemerisService.stopTracking()`
- Si el usuario cambia la ubicación en Settings mientras la pantalla está abierta, se reinicia el tracking con el nuevo `Observer`.

---

## Dataset de Validación Académica

### Estructura del archivo `test/fixtures/ephemeris_ground_truth.json`
```json
[
  {
    "id": 1,
    "raJ2000Hours": 5.5875,
    "decJ2000Deg": -5.3911,
    "utcISO": "2026-05-06T04:30:00Z",
    "latDeg": -33.4489,
    "lonDeg": -70.6693,
    "heightMeters": 570,
    "expectedAltDeg": 42.156,
    "expectedAzDeg": 315.823,
    "source": "JPL Horizons"
  }
]
```

- **500 entradas** generadas externamente (Python + JPL Horizons API / Astropy).
- **Condiciones atmosféricas:** Generado con condiciones estándar (1013.25 hPa, 10°C) para equivalencia directa con `RefractionType.normal` de geoengine.
- **Cobertura:** Todas las declinaciones, todas las RA, múltiples latitudes (incluyendo hemisferio sur), objetos cerca del horizonte, en el cenit, **bajo el horizonte (alt < 0°)**, y azimut cruzando el norte.
- **Fuentes:** ~60% JPL Horizons, ~40% Stellarium export.

---

## Happy Paths (Gherkin)

### HP-1: Cálculo de Alt/Az para objeto de cielo profundo
```gherkin
Feature: Deep-Sky Coordinate Computation

  Scenario: Compute horizontal coordinates for a deep-sky object
    Given a DeepSkyObject with RA J2000 = 5.5875h, Dec J2000 = -5.3911°
    And an observer at Lat = -33.4489°, Lon = -70.6693°, Height = 570m
    And UTC time = 2026-05-06T04:30:00Z
    When the app calls EphemerisEngine.computeAltAz() with these parameters
    Then the result contains altitude and azimuth values
    And altitude is in the range [-90, +90] degrees
    And azimuth is in the range [0, 360) degrees
    And altitudeRawDeg and azimuthRawDeg are also populated (without refraction)
    And computedAt equals the input UTC time

  Scenario: Precession is applied before horizontal conversion
    Given a DeepSkyObject with RA J2000 = 5.5875h, Dec J2000 = -5.3911°
    When EphemerisEngine.computeAltAz() is called
    Then geoengine.gyration() is applied to convert J2000 → JNow
    And the JNow coordinates differ from J2000 by the correct precession amount
    And the horizontal conversion uses the JNow coordinates, not J2000

  Scenario: Refraction correction increases altitude near horizon
    Given an object whose raw altitude is 2.0° (near horizon)
    When EphemerisEngine.computeAltAz() is called
    Then altitudeDeg (with refraction) > altitudeRawDeg (without refraction)
    And the difference is approximately 0.5° to 1.0° per Meeus formula
```

### HP-2: Cálculo de Alt/Az para cuerpo del sistema solar
```gherkin
Feature: Solar System Body Coordinate Computation

  Scenario: Compute horizontal coordinates for Mars
    Given a SolarSystemBody with geoengine Body = Mars
    And an observer at Lat = -33.4489°, Lon = -70.6693°, Height = 570m
    And UTC time = 2026-05-06T04:30:00Z
    When the app calls EphemerisEngine.computeSolarBodyAltAz() with these parameters
    Then the result contains altitude and azimuth values
    And the calculation used geoengine.equator() with ofdate=true and aberration=true
    And altitude is in the range [-90, +90] degrees
    And azimuth is in the range [0, 360) degrees
    And altitudeRawDeg and azimuthRawDeg are also populated

  Scenario: Solar system body calculation includes aberration correction
    Given a SolarSystemBody with geoengine Body = Jupiter
    When EphemerisEngine.computeSolarBodyAltAz() is called
    Then geoengine.equator() is called with aberration=true
    And the resulting RA/Dec accounts for light travel time
```

### HP-3: Stream de actualización en tiempo real
```gherkin
Feature: Real-Time Coordinate Streaming

  Scenario: EphemerisService emits coordinates every second
    Given a CelestialObject is selected in CelestialDetailScreen
    And SettingsService provides a valid Observer (from GPS or manual input)
    When EphemerisService.startTracking(object, observer) is called
    Then a Stream<AltAzResult> begins emitting values
    And an initial value is emitted immediately
    And a new value is emitted every 1 second
    And each emission uses DateTime.now().toUtc() as the current time
    And the stream continues until stopTracking() is called

  Scenario: Stream pauses when screen is disposed
    Given EphemerisService is actively tracking an object
    When CelestialDetailScreen is disposed (user navigates away)
    Then EphemerisService.stopTracking() is called
    And the Timer is cancelled
    And no more values are emitted to the stream

  Scenario: Restarting tracking with a different object
    Given EphemerisService is tracking Object A
    When startTracking(Object B, observer) is called
    Then the previous Timer is cancelled
    And a new Timer is started for Object B
    And the stream now emits coordinates for Object B only
```

### HP-4: Integración con SettingsService
```gherkin
Feature: Observer Parameter Injection

  Scenario: Motor receives GPS-based observer coordinates
    Given SettingsService is configured to use automatic GPS
    And geolocator returns Lat = -33.4489°, Lon = -70.6693°, Height = 570m
    When SettingsService constructs an Observer for the EphemerisService
    Then the Observer contains the GPS-derived coordinates
    And the EphemerisEngine computes Alt/Az using those exact coordinates
    And the engine does NOT call geolocator directly

  Scenario: Motor receives manual observer coordinates
    Given SettingsService is configured to use manual input
    And the user entered Lat = -30.0000°, Lon = -71.0000°, Height = 100m
    When SettingsService constructs an Observer for the EphemerisService
    Then the Observer contains the manual coordinates
    And the EphemerisEngine computes Alt/Az using those exact coordinates
    And the engine does NOT know or care that the values are manual

  Scenario: Motor receives observer from SettingsService without knowing source
    Given SettingsService provides an Observer with any valid coordinates
    When the Observer is passed to EphemerisEngine
    Then the engine treats it identically regardless of GPS or manual origin
    And the computation depends ONLY on the numeric values in the Observer
```

### HP-5: Refracción atmosférica aplicada
```gherkin
Feature: Atmospheric Refraction Correction

  Scenario: Refraction affects altitude more near the horizon
    Given an object at altitude raw = 2.0° (near horizon)
    When EphemerisEngine.computeAltAz() is called
    Then altitudeDeg (with refraction) > altitudeRawDeg (without refraction)
    And the difference is approximately 0.5° to 1.0° (Meeus formula at low altitude)

  Scenario: Refraction is negligible at zenith
    Given an object at altitude raw = 85.0° (near zenith)
    When EphemerisEngine.computeAltAz() is called
    Then altitudeDeg ≈ altitudeRawDeg (difference < 0.01°)

  Scenario: Both refracted and raw values are always available
    Given any valid EphemerisInput
    When EphemerisEngine.computeAltAz() is called
    Then altitudeDeg and azimuthDeg contain refracted values
    And altitudeRawDeg and azimuthRawDeg contain airless values
    And both pairs are populated regardless of object position
```

---

## Sad Paths (Gherkin)

### SP-1: Coordenadas de entrada fuera de rango
```gherkin
Feature: Input Validation

  Scenario: RA outside valid range is normalized
    Given an EphemerisInput with raJ2000Hours = 25.0 (invalid, max is 24)
    When EphemerisEngine.computeAltAz() is called
    Then the RA is normalized to 1.0 (modulo 24)
    And the computation proceeds without error

  Scenario: RA negative value is normalized
    Given an EphemerisInput with raJ2000Hours = -1.0
    When EphemerisEngine.computeAltAz() is called
    Then the RA is normalized to 23.0 (modulo 24)
    And the computation proceeds without error

  Scenario: Dec outside valid range throws error
    Given an EphemerisInput with decJ2000Deg = 95.0 (invalid, max is 90)
    When EphemerisEngine.computeAltAz() is called
    Then an ArgumentError is thrown with message "Dec must be in range [-90, +90]"

  Scenario: Dec at exact boundary is accepted
    Given an EphemerisInput with decJ2000Deg = 90.0 (North celestial pole)
    When EphemerisEngine.computeAltAz() is called
    Then the computation proceeds without error

  Scenario: Latitude outside valid range throws error
    Given an EphemerisInput with latDeg = 100.0 (invalid, max is 90)
    When EphemerisEngine.computeAltAz() is called
    Then an ArgumentError is thrown with message "Lat must be in range [-90, +90]"

  Scenario: Longitude outside valid range throws error
    Given an EphemerisInput with lonDeg = 200.0 (invalid, range is -180..+180)
    When EphemerisEngine.computeAltAz() is called
    Then an ArgumentError is thrown with message "Lon must be in range [-180, +180]"
```

### SP-2: Objeto bajo el horizonte
```gherkin
Feature: Object Below Horizon

  Scenario: Object is below the observer's horizon
    Given an object whose computed altitude = -15.3°
    When EphemerisEngine.computeAltAz() completes
    Then the result is returned normally (negative altitude is valid)
    And the UI layer is responsible for indicating "not visible"
    And the engine does NOT filter or reject below-horizon results

  Scenario: Object at exact horizon (altitude = 0°)
    Given an object whose computed altitude = 0.0°
    When EphemerisEngine.computeAltAz() completes
    Then the result is returned normally
    And refraction still applies (lifts apparent altitude slightly above 0°)
```

### SP-3: DateTime en el pasado lejano
```gherkin
Feature: Historical Date Computation

  Scenario: Computing coordinates for a date 50 years ago
    Given an EphemerisInput with utc = 1976-01-01T00:00:00Z
    When EphemerisEngine.computeAltAz() is called
    Then the computation succeeds
    And precession correctly accounts for the 50-year difference from J2000
    And the result is mathematically valid

  Scenario: Computing coordinates far in the future
    Given an EphemerisInput with utc = 2100-01-01T00:00:00Z
    When EphemerisEngine.computeAltAz() is called
    Then the computation succeeds
    And precession correctly accounts for the ~100-year difference from J2000
```

### SP-4: geoengine lanza excepción interna
```gherkin
Feature: Geoengine Internal Error

  Scenario: geoengine.horizon() throws during computation
    Given valid EphemerisInput parameters
    When geoengine.horizon() throws an exception internally
    Then the exception propagates to the caller
    And EphemerisEngine does NOT swallow or hide the exception
    And the calling layer (EphemerisService or UI) handles the error gracefully
```

---

## Validación Académica Automatizada (OE3)

### AT-1: Test de 500 coordenadas contra Ground Truth
```gherkin
Feature: Ephemeris Accuracy Validation (OE3)

  Scenario: Run 500-point accuracy test against JPL/Stellarium ground truth
    Given the file test/fixtures/ephemeris_ground_truth.json exists with 500 entries
    And each entry contains: raJ2000Hours, decJ2000Deg, utcISO, latDeg, lonDeg, heightMeters, expectedAltDeg, expectedAzDeg, source
    And the ground truth was generated with standard atmospheric conditions (1013.25 hPa, 10°C)
    When the test reads all 500 entries using dart:io File('test/fixtures/ephemeris_ground_truth.json')
    And for each entry:
      | Step | Action |
      | 1    | Parse utcISO into DateTime UTC |
      | 2    | Construct EphemerisInput with the entry's parameters |
      | 3    | Call EphemerisEngine.computeAltAz(input) |
      | 4    | Calculate spherical angular distance between (result.alt, result.az) and (expectedAlt, expectedAz) |
    Then for ALL 500 entries, the angular distance error < 0.5°
    And the RMSE (Root Mean Square Error) across all 500 points is reported in test output
    And the maximum individual error is reported in test output
    And the mean error is reported in test output
    And the test prints a summary table:
      | Metric              | Value    |
      |---------------------|----------|
      | Total test points   | 500      |
      | Max angular error   | X.XXXX°  |
      | RMSE                | X.XXXX°  |
      | Mean angular error  | X.XXXX°  |
      | Pass threshold      | < 0.5°   |
      | Result              | PASS/FAIL|

  Scenario: Test includes objects below horizon
    Given the ground truth dataset contains entries with expectedAltDeg < 0°
    When the accuracy test processes those entries
    Then the angular distance is calculated normally
    And negative altitude does not cause any special handling or exclusion
    And those entries count toward the overall RMSE and max error

  Scenario: Test fails when any single point exceeds threshold
    Given one entry in the dataset has an angular error of 0.6°
    When the accuracy test completes
    Then the test fails with a clear message indicating which entry exceeded the threshold
    And all metrics (RMSE, mean, max) are still printed before the failure
```

### AT-2: Normalización circular del azimut
```gherkin
Feature: Azimuth Circular Normalization

  Scenario: Azimuth error across the North boundary (0°/360°)
    Given a computed azimuth = 359.9°
    And a ground truth azimuth = 0.1°
    When the angular distance is calculated
    Then the azimuth difference = 0.2° (NOT 359.8°)
    And the normalization formula used is: min(|a - b|, 360 - |a - b|)

  Scenario: Normalization function handles all edge cases
    Given the following azimuth pairs:
      | computed | expected | expected_diff |
      | 359.9    | 0.1      | 0.2           |
      | 0.0      | 359.5    | 0.5           |
      | 180.0    | 180.0    | 0.0           |
      | 90.0     | 270.0    | 180.0         |
      | 0.0      | 0.0      | 0.0           |
      | 359.0    | 1.0      | 2.0           |
      | 1.0      | 359.0    | 2.0           |
    When circularAzimuthDiff(computed, expected) is called for each pair
    Then the returned difference matches expected_diff in all cases

  Scenario: Normalization is applied within spherical distance calculation
    Given the sphericalAngularDistance function computes az1 - az2
    When the azimuth difference crosses the 0°/360° boundary
    Then the cosine term cos(az1 - az2) naturally handles the wraparound
    And no explicit normalization is needed inside arccos (cos is periodic)
```

### AT-3: Métrica de Distancia Angular Esférica
```gherkin
Feature: Spherical Angular Distance Calculation

  Scenario: Compute angular distance between two Alt/Az pairs
    Given point A: alt = 45.0°, az = 180.0°
    And point B: alt = 45.5°, az = 180.0°
    When sphericalAngularDistance(A, B) is computed
    Then the result = 0.5° (pure altitude difference)

  Scenario: Angular distance with both alt and az difference
    Given point A: alt = 30.0°, az = 90.0°
    And point B: alt = 30.0°, az = 91.0°
    When sphericalAngularDistance(A, B) is computed
    Then the result ≈ 1.0° × cos(30°) ≈ 0.866° (azimuth difference scaled by cos(alt))

  Scenario: Angular distance formula implementation
    Given the formula:
      d = arccos(sin(alt1)·sin(alt2) + cos(alt1)·cos(alt2)·cos(az1 - az2))
    When implemented as sphericalAngularDistance(alt1, az1, alt2, az2)
    Then it correctly handles:
      - Both points in the same hemisphere
      - Points across the horizon boundary (positive and negative altitude)
      - Points near the zenith (alt ≈ 90°)
      - Points near the nadir (alt ≈ -90°)
      - Points with azimuth crossing the North boundary

  Scenario: Angular distance returns zero for identical points
    Given point A: alt = 42.156°, az = 315.823°
    And point B: alt = 42.156°, az = 315.823°
    When sphericalAngularDistance(A, B) is computed
    Then the result = 0.0° (within floating-point tolerance of 1e-10)
```

---

## Estructura de Archivos del Test

```
test/
├── ephemeris/
│   ├── ephemeris_engine_test.dart          # Tests unitarios del motor puro
│   ├── ephemeris_service_test.dart         # Tests del servicio (stream, timer)
│   ├── azimuth_normalization_test.dart     # Tests de normalización circular
│   ├── angular_distance_test.dart          # Tests de distancia esférica
│   └── accuracy_validation_test.dart       # Test OE3: 500 puntos vs Ground Truth
└── fixtures/
    └── ephemeris_ground_truth.json          # Dataset de 500 puntos (JPL/Stellarium)
```

### Patrón de lectura del dataset en el test
```dart
// accuracy_validation_test.dart
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:astropilot/core/ephemeris/ephemeris_engine.dart';

void main() {
  test('OE3: 500-point accuracy validation against ground truth', () {
    // Leer archivo con dart:io (NO rootBundle)
    final file = File('test/fixtures/ephemeris_ground_truth.json');
    expect(file.existsSync(), isTrue, reason: 'Ground truth file must exist');

    final jsonString = file.readAsStringSync();
    final List<dynamic> jsonData = jsonDecode(jsonString);
    expect(jsonData.length, 500, reason: 'Dataset must contain exactly 500 entries');

    final errors = <double>[];
    final failedEntries = <Map<String, dynamic>>[];

    for (final entry in jsonData) {
      final input = EphemerisInput(
        raJ2000Hours: (entry['raJ2000Hours'] as num).toDouble(),
        decJ2000Deg: (entry['decJ2000Deg'] as num).toDouble(),
        utc: DateTime.parse(entry['utcISO'] as String),
        latDeg: (entry['latDeg'] as num).toDouble(),
        lonDeg: (entry['lonDeg'] as num).toDouble(),
        heightMeters: (entry['heightMeters'] as num).toDouble(),
      );

      final result = EphemerisEngine.computeAltAz(input);

      final error = sphericalAngularDistance(
        result.altitudeDeg, result.azimuthDeg,
        (entry['expectedAltDeg'] as num).toDouble(),
        (entry['expectedAzDeg'] as num).toDouble(),
      );
      errors.add(error);

      if (error >= 0.5) {
        failedEntries.add({
          'id': entry['id'],
          'source': entry['source'],
          'error': error,
          'expectedAlt': entry['expectedAltDeg'],
          'expectedAz': entry['expectedAzDeg'],
          'computedAlt': result.altitudeDeg,
          'computedAz': result.azimuthDeg,
        });
      }
    }

    final maxError = errors.reduce((a, b) => a > b ? a : b);
    final rmse = sqrt(errors.map((e) => e * e).reduce((a, b) => a + b) / errors.length);
    final meanError = errors.reduce((a, b) => a + b) / errors.length;

    print('');
    print('=== OE3 Accuracy Validation ===');
    print('Total test points:   ${jsonData.length}');
    print('Max angular error:   ${maxError.toStringAsFixed(4)}°');
    print('RMSE:                ${rmse.toStringAsFixed(4)}°');
    print('Mean angular error:  ${meanError.toStringAsFixed(4)}°');
    print('Pass threshold:      < 0.5°');

    if (failedEntries.isNotEmpty) {
      print('');
      print('FAILED ENTRIES (${failedEntries.length}):');
      for (final f in failedEntries) {
        print('  ID=${f['id']} source=${f['source']} error=${(f['error'] as double).toStringAsFixed(4)}°');
        print('    Expected: alt=${f['expectedAlt']}°, az=${f['expectedAz']}°');
        print('    Computed: alt=${(f['computedAlt'] as double).toStringAsFixed(4)}°, az=${(f['computedAz'] as double).toStringAsFixed(4)}°');
      }
    }

    print('');
    print('Result: ${maxError < 0.5 ? "PASS" : "FAIL"}');
    print('=============================');

    expect(maxError, lessThan(0.5),
        reason: 'Max angular error ${maxError.toStringAsFixed(4)}° exceeds 0.5° threshold. '
            '${failedEntries.length} entries failed.');
  });
}
```

---

## Funciones Auxiliares de Validación

### Normalización circular de azimut
```dart
double circularAzimuthDiff(double a, double b) {
  final diff = (a - b).abs();
  return diff < 180.0 ? diff : 360.0 - diff;
}
```

### Distancia angular esférica
```dart
double sphericalAngularDistance(double alt1Deg, double az1Deg, double alt2Deg, double az2Deg) {
  final alt1 = alt1Deg * pi / 180.0;
  final alt2 = alt2Deg * pi / 180.0;
  final az1 = az1Deg * pi / 180.0;
  final az2 = az2Deg * pi / 180.0;

  final cosD = sin(alt1) * sin(alt2) + cos(alt1) * cos(alt2) * cos(az1 - az2);

  // Clamp to [-1, 1] to handle floating-point errors near boundaries
  final clamped = cosD.clamp(-1.0, 1.0);
  return acos(clamped) * 180.0 / pi;
}
```

---

## Preguntas de Clarificación
*(Resueltas — spec cerrado)*

1. **Generación del dataset:** Generado externamente por el autor con Python + JPL Horizons API / Astropy. El spec asume que `ephemeris_ground_truth.json` existirá en la ruta especificada con la estructura definida.
2. **Condiciones atmosféricas del Ground Truth:** Se asume generación con condiciones estándar (1013.25 hPa, 10°C) para equivalencia directa con `RefractionType.normal` de geoengine.
3. **Objetos bajo el horizonte en el test:** Incluidos. El dataset contiene entradas con `expectedAltDeg < 0°` para validar robustez en toda la esfera celeste. El cálculo de distancia angular funciona normalmente con altitudes negativas.
