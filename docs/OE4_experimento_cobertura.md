# OE4 - Experimento de cobertura RSSI

Este documento define como medir cobertura BLE y estabilidad del heartbeat en Fase 4. Los umbrales actuales son preventivos iniciales y se ajustaran con mediciones reales.

## Datos a medir

- RSSI actual en dBm desde la app Flutter.
- Estado visual mostrado por la app: `OK`, `Riesgo`, `Crítico` o `Desconectado`.
- Distancia aproximada entre telefono y ESP32.
- Obstaculos entre telefono y ESP32.
- Si `Ultimo PONG recibido` sigue actualizandose.
- Si los comandos `STATUS`, `GOTO`, `NUDGE` y `SET_POSITION` siguen funcionando.
- Evidencia en captura, video o monitor Serial.

## Umbrales preliminares

| Estado visual | Rango RSSI inicial |
|---|---|
| OK | `>= -70 dBm` |
| Riesgo | `-71` a `-85 dBm` |
| Crítico | `< -85 dBm` |
| Desconectado | Sin conexion BLE |

Estos rangos no son conclusiones finales. Son una guia visual para detectar riesgo durante la demo y ordenar la toma de datos.

## Procedimiento

1. Cargar firmware Fase 4 en ESP32.
2. Conectar la app por BLE.
3. Abrir `Control OE4` y ubicar la tarjeta `Confiabilidad y cobertura`.
4. Confirmar que el heartbeat este activo y que llegue `PONG`.
5. Tomar mediciones en varios puntos:
   - Cerca del ESP32.
   - Distancia media sin obstaculos.
   - Distancia alta sin obstaculos.
   - Con una pared u obstaculo liviano.
   - Cerca del limite de desconexion.
6. En cada punto registrar RSSI, estado visual, estabilidad de `PONG`, comandos probados y evidencia.
7. Completar `validations/cobertura/plantilla_rssi.csv`.

## Prueba de desconexion controlada

1. Conectar BLE y verificar heartbeat activo.
2. Activar watchdog solo si se esta probando tolerancia a fallos.
3. Iniciar movimiento.
4. Alejar telefono o apagar Bluetooth.
5. Registrar si el watchdog detuvo motores y cuanto tiempo reporto la alerta.
6. Registrar resultados en `validations/watchdog/plantilla_watchdog.csv`.

## Capturas sugeridas

- Tarjeta OE4 mostrando `RSSI actual`, `Estado RSSI`, `Heartbeat` y `Ultimo PONG recibido`.
- Tarjeta OE4 con `Watchdog activo` antes de cortar conexion.
- Monitor Serial con `ALERTA: conexión perdida. Motores detenidos en X ms`.
- Foto o video del montaje fisico durante medicion de distancia.

## Nota experimental

No se agregan resultados medidos en este documento. Las mediciones fisicas reales deben completarse en las plantillas antes del viernes.
