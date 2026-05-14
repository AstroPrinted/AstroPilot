# Spec: Celestial Catalog — Data Models & Hybrid Repository

## User Story
Como usuario de AstroPilot, quiero ver un catálogo unificado de objetos celestiales (cielo profundo, estrellas de calibración y cuerpos del sistema solar) para poder explorar, filtrar por categoría, buscar por nombre y seleccionar un objeto como objetivo de observación.

## Business Rules
- El catálogo se carga desde **dos fuentes híbridas**: un archivo JSON estático (cielo profundo + estrellas) y la librería `geoengine` en tiempo real (sistema solar).
- **El Sol aparece en el catálogo** pero la UI debe mostrar un warning de seguridad y bloquear cualquier botón de envío de coordenadas/calibración para este objeto.
- Las coordenadas del JSON están en **epoch J2000** (RA/Dec fijos). Las coordenadas de los cuerpos del sistema solar se calculan dinámicamente vía VSOP87 en `geoengine`.
- La precesión J2000 → JNow es **obligatoria** antes de cualquier cálculo de coordenadas horizontales.
- El repositorio expone una **única lista unificada** de tipo `CelestialObject` (sealed class) para que la UI no necesite conocer el origen del dato.
- **Cero favoritos, cero historial** en esta fase. Solo listar, filtrar por categoría principal y buscar por nombre.
- **Navegación y Selección:** Cada item del catálogo es clickeable (`ListTile` con `onTap`). Al seleccionar un objeto se navega a `CelestialDetailScreen` pasando el objeto como argumento. Esta pantalla es un **cascarón UI** que muestra únicamente metadata estática (Nombre, Tipo, Constelación, Magnitud, Catálogos, RA/Dec J2000). El cálculo matemático continuo en tiempo real (Alt/Az) se definirá en el próximo spec (OE3).
- **Botón "Apuntar" — Envío de coordenadas:** Al presionar el botón "Apuntar" en `CelestialDetailScreen`, **si la capa BLE está implementada y conectada**, se envían las coordenadas horizontales (Azimut y Altitud) en tiempo real al ESP32 usando el protocolo `GOTO:alt,az`. Si BLE no está implementado o no hay conexión activa, el botón muestra un toast informativo: *"Funcionalidad GoTo no disponible aún"*. **El Sol nunca envía coordenadas**, sin excepción.

---

## Data Model (El "Molde")

### Sealed Class: `CelestialObject`
```dart
sealed class CelestialObject {
  final String id;
  final String name;
  final String? magnitude;

  const CelestialObject({required this.id, required this.name, this.magnitude});
}
```

### Subclase: `DeepSkyObject`
```dart
final class DeepSkyObject extends CelestialObject {
  final String objectType;        // "Galaxia (Espiral)", "Nebulosa de Emisión", etc.
  final List<String> constellations;
  final double raJ2000Hours;      // Right ascension en horas (J2000)
  final double decJ2000Degrees;   // Declination en grados (J2000)
  final List<String> catalogs;    // ["M 42", "NGC 1976"]
  final String? notes;

  const DeepSkyObject({
    required super.id,
    required super.name,
    super.magnitude,
    required this.objectType,
    required this.constellations,
    required this.raJ2000Hours,
    required this.decJ2000Degrees,
    required this.catalogs,
    this.notes,
  });
}
```

### Subclase: `CalibrationStar`
```dart
final class CalibrationStar extends CelestialObject {
  final String constellation;
  final String spectralType;      // "A1V", "K5+III", etc.
  final double raJ2000Hours;
  final double decJ2000Degrees;
  final List<String> catalogs;    // ["α CMa", "HR 2491", "HD 48915"]

  const CalibrationStar({
    required super.id,
    required super.name,
    super.magnitude,
    required this.constellation,
    required this.spectralType,
    required this.raJ2000Hours,
    required this.decJ2000Degrees,
    required this.catalogs,
  });
}
```

### Subclase: `SolarSystemBody`
```dart
final class SolarSystemBody extends CelestialObject {
  final Body geoengineBody;       // geoengine Body enum (Sun, Moon, Mars, etc.)

  const SolarSystemBody({
    required super.id,
    required super.name,
    super.magnitude,
    required this.geoengineBody,
  });

  /// Calcula coordenadas ecuatoriales JNow en tiempo real.
  /// Delega en geoengine.equator() con ofdate=true, aberration=true.
  EquatorialCoordinates getCurrentCoordinates(
    DateTime date,
    Observer observer,
  ) {
    return equator(geoengineBody, date, observer, true, true);
  }

  /// Intenta obtener magnitud visual dinámica vía geoengine.
  /// Si no es viable, retorna null y la UI muestra "N/A".
  String? getDynamicMagnitude(DateTime date) {
    // geoengine tiene illumination() que retorna phase y magnitude.
    // Si el cálculo resulta costoso o inestable, retornar null.
    return null; // Placeholder: se resuelve en fase de implementación.
  }
}
```

---

## Fuente de Verdad Híbrida

### JSON (`assets/celestial_catalog.json`)
- **`deep_sky_objects`** (53 entradas) → se mapea a `List<DeepSkyObject>`
- **`calibration_targets`** (25 entradas) → se mapea a `List<CalibrationStar>`
- Se carga **una sola vez** al inicio de la app vía `rootBundle.loadString()`.
- Las coordenadas RA/Dec son **estáticas** (J2000). No se recalculan.

### `geoengine` (VSOP87)
- Los cuerpos del sistema solar se instancian como `SolarSystemBody` wrappers para cada `Body` relevante:
  `Sun`, `Moon`, `Mercury`, `Venus`, `Mars`, `Jupiter`, `Saturn`, `Uranus`, `Neptune`, `Pluto`.
- **NO se almacenan coordenadas fijas** en estos objetos. Se calculan on-demand llamando a `getCurrentCoordinates(date, observer)`.
- El `id` de cada `SolarSystemBody` se genera como `"solar_${body.name.toLowerCase()}"` (ej: `"solar_moon"`, `"solar_jupiter"`).
- **Magnitud:** se intenta calcular dinámicamente vía `geoengine.illumination()` si resulta viable. Si no, se deja como `null` y la UI muestra "N/A". No bloquear el desarrollo por esto.

---

## Repositorio: `CelestialCatalogRepository` (Singleton)

```dart
class CelestialCatalogRepository {
  static final CelestialCatalogRepository _instance = CelestialCatalogRepository._();
  factory CelestialCatalogRepository() => _instance;
  CelestialCatalogRepository._();

  List<CelestialObject>? _catalog;

  /// Carga el JSON y lo fusiona con los cuerpos del sistema solar.
  /// Llamado una vez durante la inicialización de la app.
  Future<void> initialize();

  /// Retorna la lista completa unificada.
  /// Lanza StateError si initialize() no fue llamado.
  List<CelestialObject> getAllObjects();

  /// Filtra por categoría: 'solar_system', 'deep_sky', 'stars'.
  List<CelestialObject> getByCategory(String category);

  /// Búsqueda por nombre (case-insensitive, substring match).
  List<CelestialObject> searchByName(String query);
}
```

### Ordenamiento de la lista unificada
El orden de presentación en la UI sigue esta regla:
1. **Sistema Solar** primero (orden alfabético: Júpiter, Luna, Marte, Mercurio, Neptuno, Plutón, Saturno, Sol, Tierra, Urano, Venus)
2. **Cielo Profundo** segundo (orden alfabético por nombre)
3. **Estrellas de Calibración** tercero (orden alfabético por nombre)

---

## UI Mockup

### Catálogo Principal (sin filtro)
```
┌──────────────────────────────────────┐
│  ←  Catálogo Celestial        [🔍]   │
├──────────────────────────────────────┤
│  [Todos] [Sist. Solar] [Cielo Prof.] │
│          [Estrellas]                 │
├──────────────────────────────────────┤
│                                      │
│  🪐 Júpiter                          │
│     Sistema Solar                    │
│                                      │
│  🌙 Luna                             │
│     Sistema Solar                    │
│                                      │
│  ☀️ Sol ⚠️                           │
│     Sistema Solar                    │
│     ⚠️ Observación solar bloqueada   │
│                                      │
│  ────────────────────────────────    │
│                                      │
│  🔭 47 Tucanae                       │
│     NGC 104 · Mag: 4.0              │
│     Cúmulo Globular · Tucana         │
│                                      │
│  🔭 Centaurus A                      │
│     NGC 5128 · Mag: 6.8             │
│     Galaxia (Lenticular) · Centaurus │
│                                      │
│  ────────────────────────────────    │
│                                      │
│  ⭐ Achernar                         │
│     α Eri · Mag: 0.45               │
│     B6Vpe · Eridanus                 │
│                                      │
│  ⭐ Sirio                            │
│     α CMa · Mag: -1.46              │
│     A1V · Canis Major                │
│                                      │
├──────────────────────────────────────┤
│                                      │
│   📡         🌌         ⚙️          │
│ Conexión   Catálogo   Config        │
│                                      │
└──────────────────────────────────────┘
```

### Detalle de Objeto Deep Sky (cascarón estático)
```
┌──────────────────────────────────────┐
│  ←  Nebulosa de Orión                │
├──────────────────────────────────────┤
│                                      │
│  Tipo: Nebulosa de Emisión           │
│  Constelación: Orion                 │
│  Magnitud: 4.0                       │
│  Catálogos: M 42, NGC 1976          │
│  RA (J2000): 05h 35m 17s            │
│  Dec (J2000): -05° 23' 28"          │
│                                      │
│  ┌────────────────────────────────┐  │
│  │        🎯  Apuntar             │  │
│  └────────────────────────────────┘  │
│                                      │
│  (Alt/Az en tiempo real: próximamente)│
│                                      │
└──────────────────────────────────────┘
```

### Detalle del Sol (con bloqueo)
```
┌──────────────────────────────────────┐
│  ←  Sol                              │
├──────────────────────────────────────┤
│                                      │
│  ⚠️  ADVERTENCIA DE SEGURIDAD        │
│  Nunca apuntes el telescopio         │
│  directamente al Sol sin filtros     │
│  solares certificados.               │
│                                      │
│  Tipo: Sistema Solar                 │
│  Magnitud: -26.7                     │
│                                      │
│  ┌────────────────────────────────┐  │
│  │        🚫  Apuntar (Bloqueado) │  │
│  └────────────────────────────────┘  │
│                                      │
└──────────────────────────────────────┘
```

### AppBar con Search (Material 3)
```
Estado normal:                    Estado búsqueda activa:
┌──────────────────────────┐      ┌──────────────────────────┐
│  ←  Catálogo      [🔍]  │  →   │  [🔍 Buscar objeto...] [X]│
└──────────────────────────┘      └──────────────────────────┘
```

---

## Estructura de Navegación
- **3 tabs en `BottomNavigationBar`:**
  - 📡 **Conexión** — BLE scan, connect, disconnect
  - 🌌 **Catálogo** — Lista unificada de objetos celestiales (esta spec)
  - ⚙️ **Config** — Settings de la app

### Flujo de navegación del catálogo
```
CatalogScreen (lista con filtros + search en AppBar)
       │
       ├─ onTap(DeepSkyObject) ──→ CelestialDetailScreen(objeto)
       ├─ onTap(CalibrationStar) ─→ CelestialDetailScreen(objeto)
       └─ onTap(SolarSystemBody) ─→ CelestialDetailScreen(objeto)
                                        │
                                         ├─ Si es Sol → botón bloqueado
                                         └─ Si no es Sol → botón "Apuntar" activo
                                              ├─ Si BLE conectado → envía GOTO:alt,az
                                              └─ Si BLE no conectado → toast "GoTo no disponible"
```

---

## Happy Paths (Gherkin)

### HP-1: Carga inicial del catálogo unificado
```gherkin
Feature: Catalog Loading

  Scenario: App loads the complete celestial catalog on startup
    Given the file `assets/celestial_catalog.json` exists and is valid
    And the `geoengine` library is available with VSOP87 support
    When the app calls `CelestialCatalogRepository.initialize()`
    Then the JSON is parsed into DeepSkyObject and CalibrationStar instances
    And 10 SolarSystemBody wrappers are created (Sun, Moon, Mercury..Pluto)
    And `getAllObjects()` returns a unified list of all objects
    And each object has a unique `id` field
    And no exceptions are thrown during initialization
```

### HP-2: Ordenamiento correcto de la lista unificada
```gherkin
Feature: List Ordering

  Scenario: Unified list is ordered by category then alphabetically
    Given the catalog is fully loaded
    When `getAllObjects()` is called
    Then the first group contains only SolarSystemBody objects sorted alphabetically
    And the second group contains only DeepSkyObject objects sorted alphabetically
    And the third group contains only CalibrationStar objects sorted alphabetically
```

### HP-3: Filtrado por categoría
```gherkin
Feature: Category Filtering

  Scenario: User filters to show only solar system bodies
    Given the catalog is fully loaded
    When the user selects the "Sistema Solar" filter
    Then only SolarSystemBody instances are displayed
    And the list includes Sun, Moon, and all planets (Mercury through Pluto)
    And the total count is exactly 10
    And objects are sorted alphabetically by name

  Scenario: User filters to show only deep-sky objects
    Given the catalog is fully loaded
    When the user selects the "Cielo Profundo" filter
    Then only DeepSkyObject instances are displayed
    And the count matches the 53 entries in `deep_sky_objects`
    And objects are sorted alphabetically by name

  Scenario: User filters to show only calibration stars
    Given the catalog is fully loaded
    When the user selects the "Estrellas" filter
    Then only CalibrationStar instances are displayed
    And the count matches the 25 entries in `calibration_targets`
    And objects are sorted alphabetically by name

  Scenario: User selects "Todos" to see the full catalog
    Given a category filter is currently active
    When the user selects the "Todos" filter
    Then all objects from all three categories are displayed
    And the order is: Solar System → Deep Sky → Stars (alphabetical within each)
```

### HP-4: Búsqueda por nombre
```gherkin
Feature: Name Search

  Scenario: User searches for a deep-sky object by partial name
    Given the catalog is fully loaded
    When the user types "Orión" in the AppBar search field
    Then "Nebulosa de Orión" appears in the results
    And the search is case-insensitive
    And the search matches substrings (not just exact matches)

  Scenario: User searches for a solar system body
    Given the catalog is fully loaded
    When the user types "jupi"
    Then "Júpiter" appears in the results

  Scenario: User searches for a calibration star
    Given the catalog is fully loaded
    When the user types "sir"
    Then "Sirio" appears in the results

  Scenario: Search returns no results
    Given the catalog is fully loaded
    When the user types "xyznonexistent"
    Then an empty state message is shown: "No se encontraron objetos"

  Scenario: User clears the search field
    Given the user has performed a search with results
    When the user clears the search field (empty string)
    Then the full catalog is displayed again with current filter applied
```

### HP-5: Navegación al detalle de un objeto
```gherkin
Feature: Object Detail Navigation

  Scenario: User taps on a deep-sky object
    Given the catalog is displayed
    When the user taps on "Nebulosa de Orión"
    Then the app navigates to CelestialDetailScreen
    And the screen displays:
      | Field         | Value                        |
      | Nombre        | Nebulosa de Orión            |
      | Tipo          | Nebulosa de Emisión          |
      | Constelación  | Orion                        |
      | Magnitud      | 4.0                          |
      | Catálogos     | M 42, NGC 1976              |
      | RA (J2000)    | 05h 35m 17s                 |
      | Dec (J2000)   | -05° 23' 28"                |
    And the "Apuntar" button is visible and enabled
    And if BLE is connected, tapping it sends GOTO:alt,az coordinates to the ESP32
    And if BLE is not connected, tapping it shows a toast "GoTo no disponible"

  Scenario: User taps on a calibration star
    Given the catalog is displayed
    When the user taps on "Sirio"
    Then the app navigates to CelestialDetailScreen
    And the screen displays:
      | Field         | Value                        |
      | Nombre        | Sirio                        |
      | Tipo          | Estrella de Calibración      |
      | Constelación  | Canis Major                  |
      | Magnitud      | -1.46                        |
      | Tipo Espectral| A1V                          |
      | Catálogos     | α CMa, HR 2491, HD 48915    |
      | RA (J2000)    | 06h 45m 08s                 |
      | Dec (J2000)   | -16° 42' 58"                |
    And the "Apuntar" button is visible and enabled
    And if BLE is connected, tapping it sends GOTO:alt,az coordinates to the ESP32
    And if BLE is not connected, tapping it shows a toast "GoTo no disponible"

  Scenario: User taps on a solar system body (not Sun)
    Given the catalog is displayed
    When the user taps on "Júpiter"
    Then the app navigates to CelestialDetailScreen
    And the screen displays the body name, type "Sistema Solar", and available metadata
    And the "Apuntar" button is visible and enabled
    And if BLE is connected, tapping it sends GOTO:alt,az coordinates to the ESP32
    And if BLE is not connected, tapping it shows a toast "GoTo no disponible"
```

### HP-6: Visualización del Sol con warning de seguridad
```gherkin
Feature: Solar Safety Warning

  Scenario: User views the Sun in the catalog list
    Given the catalog is fully loaded
    And the user is viewing "Todos" or "Sistema Solar"
    Then the Sun appears in the list with a ⚠️ safety indicator
    And the Sun is NOT hidden or filtered from the repository

  Scenario: User opens the detail view of the Sun
    Given the user taps on the Sun in the catalog
    Then the app navigates to CelestialDetailScreen
    And the detail screen shows a prominent safety warning banner
    And the "Apuntar" (GoTo) button is disabled/grayed out
    And the button text reads "Apuntar (Bloqueado)"
    And no coordinates can be sent to the ESP32 from this screen under any circumstances
```

---

## Sad Paths (Gherkin)

### SP-1: Archivo JSON no encontrado o corrupto
```gherkin
Feature: Missing or Corrupt Catalog

  Scenario: celestial_catalog.json is missing from assets
    Given the file `assets/celestial_catalog.json` does not exist
    When the app calls `CelestialCatalogRepository.initialize()`
    Then a FileSystemException is caught
    And the repository stores an empty list for JSON-sourced objects
    And only SolarSystemBody objects (from geoengine) are available via getAllObjects()
    And a log error is written for debugging

  Scenario: JSON file has invalid syntax
    Given the file `assets/celestial_catalog.json` contains malformed JSON
    When the app calls `CelestialCatalogRepository.initialize()`
    Then a FormatException is caught
    And the repository stores an empty list for JSON-sourced objects
    And only SolarSystemBody objects (from geoengine) are available via getAllObjects()
    And a log error is written for debugging
```

### SP-2: geoengine no disponible para coordenadas solares
```gherkin
Feature: Geoengine Unavailable

  Scenario: Solar system body coordinates fail to compute
    Given a SolarSystemBody detail screen is open
    When `getCurrentCoordinates()` throws an exception
    Then the UI shows "Coordenadas no disponibles" for that body
    And the rest of the catalog remains functional
    And the error is logged
```

### SP-3: getAllObjects llamado antes de initialize
```gherkin
Feature: Repository Not Initialized

  Scenario: UI requests catalog before initialization
    Given CelestialCatalogRepository.initialize() has not been called
    When the UI calls getAllObjects()
    Then a StateError is thrown with message "Repository not initialized"
    And the UI shows a loading or error state
```

---

## Preguntas de Clarificación
*(Resueltas — spec cerrado)*

1. **Orden de lista**: Sistema Solar → Cielo Profundo → Estrellas, alfabético dentro de cada grupo. ✅
2. **Subtítulos**: Catálogos alternativos (ej: "M 42, NGC 1976") en el `subtitle` del ListTile. ✅
3. **Magnitud Sistema Solar**: Intentar `geoengine.illumination()` si viable; si no, `null` → UI muestra "N/A". ✅
4. **Search Bar**: Integrado en AppBar (Material 3 estándar). ✅
5. **Botón Apuntar**: Envía `GOTO:alt,az` si BLE conectado; toast "GoTo no disponible" si no. Sol siempre bloqueado. ✅
