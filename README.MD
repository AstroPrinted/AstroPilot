# AstroPilot — Sistema de Navegación Híbrida para Telescopios

Para preparar la app en iPhone, consultar la [guía de iOS](docs/IOS.md):
configuración incluida, compilación en Mac, firma y pruebas físicas pendientes.

La rama `codex/ios-prototype` requiere actualizar juntos la app y el firmware v3
del ESP32. Incluye un script de preparación para Mac y confirmaciones de comandos.

## Descripción General

AstroPilot es un sistema de	control GoTo para telescopios astronómicos implementado en Flutter/Dart. Conecta un dispositivo móvil mediante Bluetooth Low Energy (BLE) a un microcontrolador ESP32 que controla una	montura ecuatorial o altazimutal. La aplicación calcula coordenadas horizontales (Altitud/Azimut) en tiempo real a partir de coordenadas ecuatoriales J2000, aplica correcciones de precesión, nutación y refracción atmosférica, y	envía comandos de movimiento al hardware.

El sistema está diseñado para operar dentro del territorio chileno (Lat `-56°` a `-17°`, Lon `-75°` a `-66°`) con	fallback manual cuando el GPS no está disponible o las coordenadas quedan fuera de rango.

---

## Arquitectura del Sistema

### Feature-First con Separación de Responsabilidades

El proyecto	organiza su código por **features** (módulos funcionales), cada uno con capas internas siguiendo principios de	domain-driven design:

```
lib/
├── core/theme/                        # Tema global	Material 3
├── features/
│   ├── ble_connection/                # Módulo BLE
│   │   ├── data/models/
│   │   ├── domain/ble_service.dart
│   │   └── presentation/             # Controllers + Screens + Widgets
│   ├── catalog/                       # Módulo Catálogo	Celestial
│   │   ├── data/repository/
│   │   ├── domain/models/
│   │   └── presentation/
│   ├── observation/                   # Módulo Motor de Efemérides
│   │   ├── application/ephemeris_service.dart
│   │   ├── domain/
│   │   │   ├── models/               # EphemerisInput, AltAzResult, ObserverData
│   │   │   ├── services/ephemeris_engine.dart
│   │   │   ├── services/observer_data_provider.dart
│   │   │   └── utils/angle_math.dart
│   │   └── presentation/              # (integrado	vía Provider)
│   └── settings/                     # Módulo Configuración/GPS
│       ├── application/settings_service.dart
│       ├── domain/
│       │   ├── models/observer_state.dart
│       │   └── settings_defaults.dart
│       └── presentation/
│           ├── screens/settings_screen.dart
│           └── widgets/               # Cards, Forms, Chips
```

### Inyección de Dependencias: ObserverDataProvider

El	 **patrón clave** de la arquitectura	es la interfaz `ObserverDataProvider`, que desacopla	el motor matemático de la fuente de datos del observador:

```dart
abstract interface class ObserverDataProvider {
  ObserverData current();
}
```

- `EphemerisService`	depende de `ObserverDataProvider` (no	conoce GPS, ni	preferencias, ni	`shared_preferences`).
- `SettingsService`	implementa	`ObserverDataProvider`	y	funge como Singleton `ChangeNotifier`, siendo la **única fuente de verdad** sobre ubicación y	tiempo.
- Al inyectar `SettingsService` como proveedor, el motor de efemérides	recibe	automáticamente coordenadas GPS o	manuales y	hora de planning mode, sin	modificar una	línea	de su	código interno.

Este	patrón permite	testear el	motor de	efemérides con un	`QuintaNormalObserverDataProvider` hardcodeado (Santiago) y, en producción, el	`SettingsService`.funciona como proveedor real sin	acoplamiento.

---

## Stack Tecnológico

| Componente | Tecnología |
|---|---|
| Framework | Flutter / Dart	(SDK ≥3.9.2) |
| Motor Astronómico | `geoengine`	(Astronomy Engine —	IAU 2006 / VSOP87) |
| Conectividad BLE | `flutter_blue_plus` |
| Geolocalización | `geolocator` |
| Permisos | `permission_handler` |
| Estado + Inyección | `provider`	(ChangeNotifier) |
| Persistencia | `shared_preferences` |
| Catálogo Celestial | JSON estático	en	memory (J2000) |

---

## Gestión de Datos (Sin Base de	Datos)

El	proyecto **NO utiliza bases de datos relacionales**.

- **Catálogo Estático:** Objetos de cielo profundo y estrellas de	calibración se cargan desde `assets/celestial_catalog.json` con coordenadas	J2000.
- **Cuerpos Dinámicos:** Sol, Luna y planetas se calculan en tiempo real vía VSOP87.
- **Configuración del Usuario:** Persistida en `shared_preferences` (modo GPS/manual, coordenadas manuales, Planning Mode).

---

## Pipeline de Coordenadas

```
Catálogo J2000 → Precesión + Nutación (Gyration) → JNow
                                                       ↓
                              ObserverData (lat, lon, alt, UTC) → Horizontal (Alt/Az)
                                                       ↓
                                              Refracción Atmosférica (Meeus) → Alt/Az corregido
```

**Corrección de Precesión (Crítico):** Las coordenadas del catálogo están en J2000. Es OBLIGATORIO aplicar la corrección de	precesión y	nutación ("Gyration") para convertirlas a JNow antes de	cualquier cálculo. Si	se omite, el	error de apuntado supera los 21 arcmin.

---

## Estado de los Módulos

| Módulo | Descripción | Estado |
|---|---|---|
| **BLE Connection** | Escaneo, conexión y	envío de comandos al ESP32 | Implementado |
| **Catálogo Celestial** | Búsqueda, filtrado y	vista de	detalle con	busqueda	con debounce | Implementado |
| **Motor de Efemérides** | Cálculo	Alt/Az con precesión J2000→JNow y	refracción | Implementado + Validado (OE3) |
| **Configuración/GPS** | Modo automático GPS, manual (Chile bounds), Planning Mode, persistencia | Implementado |
| **Seguridad Solar** | Bloqueo total de coordenadas solares (sin botón, sin cálculo, sin excepción) | Implementado |

---

## Validación del Motor Matemático (OE3) — Sección Crítica

### Metodología

La validación del	motor de	efemérides	se realizó mediante	una	comparación	cuantitativa contra un	dataset	de	referencia generado con	**Astropy** (Python), una	biblioteca Astronomía Computacional	de	referencia en la comunidad científica. El	procedimiento fue el	siguiente:

1. **Generación del Ground Truth:** Se creó un script Python (`scripts/generate_ground_truth.py`) que utiliza `astropy.coordinates` con	el modelo de refracción estándar para calcular Alt/Az de	referencia. Se generaron **500 puntos celestes** con	distribución	aleatoria	en:
   - **Coordenadas de	origen:** 10 ubicaciones distribuidas a lo largo del territorio chileno (Arica a Punta Arenas, altitudes de 5 a 800 m).
   - **Época de observación:** Distribuidas entre 2025 y 2027 UTC.
   - **Coordenadas ecuatoriales:** RA	(0–24 h) y	Dec (-90° a +90°) con distribución ponderada para cubrir objetos circumpolares,ecuatoriales y	boreales	visibles desde Chile.

2. **Comparación con el Motor de	Flutter:** El	test `test/ephemeris/accuracy_validation_test.dart`	itera los 500	puntos	y	ejecuta `EphemerisEngine.computeAltAz()` para cada uno,	que	aplica la	corrección de	precesión (+nutación) vía `gyration()` de	geoengine y	luego transforma a	coordenadas horizontales con	refracción tipo Meeus.

3. **Métrica de Comparación:** Seutilizó la	fórmula de	**distancia angular esférica** para cuantificar la	diferencia entre pares (Alt, Az) calculados y	esperados, lo	que evita falsos positivos por	la circularidad del	azimut	(ej. 359° vs 1°):

   ```
   cos(d) = sin(alt1)·sin(alt2) + cos(alt1)·cos(alt2)·cos(az1 − az2)
   d = arccos(clamp(cos(d), −1, +1))
   ```

### Resultados

| Métrica | Valor |
|---|---|
| Puntos evaluados | 500 |
| Puntos sobre 5° de altitud | 270 |
| **RMSE global** | **0.3138°** |
| **RMSE (Alt > 5°)** | **0.0455°** |
| Error máximo en Altitud | 0.6442° (punto #255) |
| Error máximo en Azimut | 0.1411° (punto #426) |
| Error angular máximo global | 0.6442° |

### Umbrales de Aceptación

| Condición | Umbral | Resultado |
|---|---|---|
| Objetos sobre 5° de altitud | < 0.5° | 0.0455° RMSE **(pasa con margen 11x)** |
| Todos los objetos (incl. bajo horizonte) | < 1.5° | 0.6442° máximo **(pasa)** |

### Análisis de Fuentes de Error

Las discrepancias observadas	se explican por	dos fuentes identificadas y	documentadas:

1. **Divergencia en modelos de refracción atmosférica cerca del horizonte:** Los objetos con altitud próxima a 0° exhiben los errores más grandes. Esto es esperable porque la	modelización de la	refracción atmosférica es	extremadamente sensible al	ángulo de incidencia cerca del horizonte. Geoengine	utiliza la	correción de Meeus con	un	taper	lineal por debajo de 1°	para	estabilizar valores, mientras que Astropy	utiliza un	modelo	Saastamoinen améliioré. Las diferencias de hasta ~0.6° en esta región son consistentes con la	literatura	técnica sobre el tema.

2. **Aberración anual:** Astropy	incluye por defecto la corrección por aberración estelar anual	(~20.5 arcsec), mientras que `gyration()` en geoengine no la incorpora. Esta diferencia constante de ~0.006° es despreciable para el propósito de apuntado amateur pero se manifiesta como un offset sistemático medible.

### Conclusión

El	motor de	efemérides de	AstroPilot supera	con holgura los requisitos de precisión para	un	control GoTo	amateur. Para objetos sobre 5° de altitud — la	zona Operationalmente relevante para	la observación	astronómica — el RMSE	de **0.0455°** (equivalente a **2.7 arcmin**) es más que suficiente para apuntar un telescopio con campo visual típico de 30-60 arcmin. Los errores	observados cerca del horizonte	son inherentes a la	modelización de la refracción y	no afectan la	operación real del	sistema.

---

## Formato de Coordenadas en la	UI

Siguiendo las convenciones astronómicas estándar (Stellarium):

| Coordenada | Formato | Ejemplo |
|---|---|---|
| Ascensión Recta (RA) | Sexagesimal de tiempo: `HHh MMm SSs` | `05h 35m 17s` |
| Declinación (Dec) | Sexagesimal de arco: `±DD° MM' SS"` | `-05° 23' 28"` |
| Altitud | Sexagesimal de arco con signo: `±DD° MM' SS.s"` | `+45° 14' 36.8"` |
| Azimut | Sexagesimal de arco	sin signo: `DDD° MM' SS.s"` | `315° 40' 12.3"` |

---

## Seguridad Solar

El **bloqueo solar es una restricción de seguridad hard-coded** a nivel de repositorio y	motor de	efemérides. No existe botón, no se calculan coordenadas, no se muestran datos. La restricción está implementada en `EphemerisService`: si el objeto es el Sol, se lanza un `StateError`	y la	UI	muestra un	banner de advertencia.

---

## Instrucciones para Agentes de I	A (Spec-Driven Development)

Este proyecto se rige por la metodología **SDD**. Bajo ninguna circunstancia se debe generar código sin antes producir un `spec_[modulo].md`	validado	por el	usuario. Ver `AGENTS.md` para el flujo completo.

---

## Ejecución de Tests

```bash
# Test de smoke de la app
flutter test

# Test de validación OE3 del motor de efemérides
flutter test test/ephemeris/accuracy_validation_test.dart

# Regenerar ground truth (requiere Python	3.10+ con astropy)
pip install numpy astropy
python scripts/generate_ground_truth.py
```

El test OE3 exporta automáticamente el archivo `test/fixtures/resultados_validacion_oe3.csv` con los 500 puntos comparados	individualmente.

---

## Estructura del Repositorio

```
├── .agents/                        # Specs de desarrollo (SDD)
│   ├── AGENTS.md
│   └── specs/
│       ├── bluetoothSection/
│       ├── catalogSection/
│       ├── ephemerisSection/
│       └── settingsSection/
├── assets/
│   └── celestial_catalog.json      # Catálogo J2000
├── lib/
│   ├── core/theme/
│   ├── features/
│   │   ├── ble_connection/
│   │   ├── catalog/
│   │   ├── observation/
│   │   └── settings/
│   └── main.dart
├── scripts/
│   └── generate_ground_truth.py   # Generador de ground truth con Astropy
├── test/
│   ├── ephemeris/
│   │   └── accuracy_validation_test.dart
│   ├── fixtures/
│   │   ├── ephemeris_ground_truth.json
│   │   └── resultados_validacion_oe3.csv
│   └── widget_test.dart
└── pubspec.yaml
```
