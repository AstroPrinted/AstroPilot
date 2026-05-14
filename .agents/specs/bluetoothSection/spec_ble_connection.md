# Spec: BLE Connection & Telescope State Management

## User Story
Como usuario de AstroPilot, quiero poder buscar dispositivos BLE cercanos, conectar mi ESP32 y ver el estado de conexión (Conectado/Desconectado) para poder controlar mi telescopio de forma segura.

## Business Rules
- El escaneo BLE se activa/desactiva con un botón toggle.
- La lista de dispositivos se llena dinámicamente durante el escaneo.
- El estado de conexión se muestra como `Conectado` o `Desconectado`.
- Se requieren permisos de ubicación y Bluetooth para funcionar.
---

## UI Mockup

### Estado inicial / Escaneando
```
┌──────────────────────────────────────┐
│             AstroPilot          ⚙️   │
├──────────────────────────────────────┤
│                                      │
│   ┌──────────────────────────────┐   │
│   │  🔴  Desconectado            │   │
│   └──────────────────────────────┘   │
│                                      │
│   ┌──────────────────────────────┐   │
│   │  🔍  Buscar dispositivos     │   │
│   └──────────────────────────────┘   │
│                                      │
│   ─── Dispositivos encontrados ───   │
│                                      │
│   ┌──────────────────────────────┐   │
│   │  📶 AstroPilot-ESP32         │   │
│   │     RSSI: -45 dBm  [Conectar]│   │
│   └──────────────────────────────┘   │
│                                      │
│   ┌──────────────────────────────┐   │
│   │  📶 ESP32-Tracker            │   │
│   │     RSSI: -62 dBm  [Conectar]│   │
│   └──────────────────────────────┘   │
│                                      │
│                                      │
├──────────────────────────────────────┤
│                                      │
│   📡         🌌         ⚙️          │
│ Conexión   Catálogo   Config        │
│                                      │
└──────────────────────────────────────┘
```

### Conectado
```
┌──────────────────────────────────────┐
│             AstroPilot          ⚙️   │
├──────────────────────────────────────┤
│                                      │
│   ┌──────────────────────────────┐   │
│   │  🟢  Conectado               │   │
│   └──────────────────────────────┘   │
│                                      │
│   ┌──────────────────────────────┐   │
│   │  🔌  Desconectar             │   │
│   └──────────────────────────────┘   │
│                                      │
│                                      │
│        Dispositivo conectado         │
│                                      │
├──────────────────────────────────────┤
│                                      │
│   📡         🌌         ⚙️          │
│ Conexión   Catálogo   Config        │
│                                      │
└──────────────────────────────────────┘
```

### Error (BLE apagado)
```
┌──────────────────────────────────────┐
│             AstroPilot          ⚙️   │
├──────────────────────────────────────┤
│                                      │
│   ┌──────────────────────────────┐   │
│   │  🔴  Desconectado            │   │
│   └──────────────────────────────┘   │
│                                      │
│   ┌──────────────────────────────┐   │
│   │  ⚠️  Bluetooth está          │   │
│   │     desactivado. Habilítalo  │   │
│   │     para continuar.          │   │
│   └──────────────────────────────┘   │
│                                      │
├──────────────────────────────────────┤
│                                      │
│   📡         🌌         ⚙️          │
│ Conexión   Catálogo   Config        │
│                                      │
└──────────────────────────────────────┘
```

### Estructura de Navegación
- **3 tabs en `BottomNavigationBar`:**
  - 📡 **Conexión** — BLE scan, connect, disconnect (pantalla actual)
  - 🌌 **Catálogo** — Objetos de cielo profundo, estrellas, planetas
  - ⚙️ **Config** — Settings de la app

---

## Happy Paths (Gherkin)

### HP-1: Escaneo exitoso de dispositivos BLE
```gherkin
Feature: BLE Device Scanning

  Scenario: User starts scanning and discovers devices
    Given the app is open on the Connection tab
    And Bluetooth is enabled on the device
    And required permissions are granted
    When the user taps the "Buscar dispositivos" button
    Then the button text changes to "Detener búsqueda"
    And a loading spinner appears
    And discovered BLE devices appear in a list with name and RSSI
    And each device has a "Conectar" button

  Scenario: User stops scanning
    Given the user is currently scanning for devices
    When the user taps the "Detener búsqueda" button
    Then the scanning stops
    And the button text changes back to "Buscar dispositivos"
    And the loading spinner disappears
    And the previously discovered devices remain in the list
```

### HP-2: Conexión exitosa al ESP32
```gherkin
Feature: BLE Connection

  Scenario: User connects to a discovered device
    Given the user has discovered BLE devices in the list
    When the user taps "Conectar" on a device
    Then a loading indicator appears for that device
    And the connection is established within 15 seconds
    Then the UI shows "Conectado" status
    And the device list is hidden or disabled
    And a "Desconectar" button becomes visible
```

### HP-3: Desconexión manual
```gherkin
Feature: BLE Disconnection

  Scenario: User disconnects from the telescope
    Given the user is connected to a device
    When the user taps the "Desconectar" button
    Then the device disconnects
    And the UI shows "Desconectado" status
    And the device list becomes available again
    And the "Desconectar" button is hidden
```

---

## Sad Paths (Gherkin)

### SP-1: Bluetooth apagado
```gherkin
Feature: Bluetooth Disabled

  Scenario: User tries to scan with Bluetooth off
    Given Bluetooth is disabled on the device
    When the user taps "Buscar dispositivos"
    Then a message is shown: "Bluetooth está desactivado. Habilítalo para continuar."
    And no scanning occurs
    And the button remains as "Buscar dispositivos"
```

### SP-2: Permiso denegado
```gherkin
Feature: Permission Denied

  Scenario: User denies location/Bluetooth permissions
    Given the app requests required permissions
    When the user denies the permission
    Then a message is shown explaining why the permission is needed
    And a button to open device settings is offered
    And scanning is not available
```

### SP-3: Timeout de conexión
```gherkin
Feature: Connection Timeout

  Scenario: Connection takes too long
    Given the user taps "Conectar" on a device
    When 15 seconds pass without a successful connection
    Then the connection attempt is cancelled
    And an error message is shown: "No se pudo conectar. Intenta de nuevo."
    And the device list remains available for retry
```

### SP-4: Desconexión inesperada
```gherkin
Feature: Unexpected Disconnection

  Scenario: Device disconnects unexpectedly
    Given the user is connected to a device
    When the device disconnects (out of range, powered off, etc.)
    Then the UI updates to "Desconectado"
    And a message is shown: "El dispositivo se desconectó."
    And the "Desconectar" button is hidden
    And the device list becomes available again
```

---

## Preguntas de Clarificación
1. ¿El ESP32 tiene un nombre BLE específico que debamos filtrar? (ej. `AstroPilot-ESP32`)
Si tiene nombre, que es el que mencionas ahi, pero el nombre es irrelevante. Dado que deberia poder escanear todos los dispositivos BLE disponibles.
2. ¿Queremos persistir la última conexión para reconexión automática?
No, ya que la conexión debe ser establecida cada vez que se requiere.
3. ¿El timeout de 15s es adecuado o preferimos otro valor?
No, el timeout de 15s es adecuado para la mayoría de los casos. Si la conexión tarda más de 15s, se cancela y se muestra un mensaje de error.
