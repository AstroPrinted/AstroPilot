# Protocolo de medicion OE4 - Fase 4

Este protocolo prepara las pruebas de confiabilidad, tolerancia a fallos, cobertura RSSI y limites fisicos del sistema OE4. No contiene resultados medidos; las tablas se completan con datos reales durante las pruebas fisicas.

## Objetivos

- Verificar que el heartbeat `PING`/`PONG` se mantiene estable por BLE.
- Verificar que el watchdog detiene motores si se pierde el heartbeat durante movimiento.
- Registrar RSSI en distintos escenarios de distancia y obstaculos.
- Rechazar comandos corruptos sin crash, sin movimiento inesperado y con errores cortos.
- Mantener funcionando los comandos de Fase 3: `GOTO`, `HOME`, `STATUS`, `STOP`, `TEST_ROUTINE`.

## Preparacion

- Cargar en el ESP32 el firmware `firmware/astropilot_motors/astropilot_motors.ino`.
- Instalar la app Flutter en modo debug.
- Conectar los motores 28BYJ-48 y drivers ULN2003 con el pinout validado de Fase 3.
- Abrir monitor Serial a `115200` baudios para evidencia paralela a BLE Notify.
- Abrir la pantalla `Control OE4` y verificar la tarjeta `Confiabilidad y cobertura`.

## Prueba watchdog

- Conectar por BLE al ESP32.
- Confirmar que `Heartbeat` aparece `Activo` y que `Ultimo PONG recibido` se actualiza.
- Activar el switch `Watchdog activo`.
- Ejecutar un movimiento suficientemente largo con `GOTO` o `TEST_ROUTINE`.
- Interrumpir el heartbeat durante el movimiento: apagar Bluetooth del telefono, alejarse fuera de cobertura o cerrar la app.
- Registrar si el ESP32 imprime y notifica: `ALERTA: conexión perdida. Motores detenidos en X ms`.
- Completar `validations/watchdog/plantilla_watchdog.csv` con el tiempo real observado, evidencia y observaciones.

## Prueba de comandos corruptos

- Enviar cada entrada definida en `validations/fuzzing/comandos_corruptos.json` por Serial o BLE.
- Confirmar que el firmware responde con errores cortos y no mueve motores de forma inesperada.
- Completar `validations/fuzzing/plantilla_comandos_corruptos.csv`.

## Prueba RSSI y cobertura

- Conectar por BLE y observar `RSSI actual` en la tarjeta OE4.
- Medir en varios puntos: cerca, distancia media, distancia maxima visible y con obstaculos.
- Registrar distancia, obstaculos, RSSI, estado visual y estabilidad de `PONG`.
- Completar `validations/cobertura/plantilla_rssi.csv`.
- Los umbrales actuales son preventivos iniciales: `OK >= -70 dBm`, `Riesgo -71 a -85 dBm`, `Crítico < -85 dBm`. No son umbrales definitivos hasta completar mediciones reales.

## Prueba de limites fisicos

- Mantener los limites logicos actuales: altitud `[-90, 90]`, azimut `[0, 360]`.
- Ejecutar movimientos controlados y registrar si hay bloqueo mecanico, cableado tenso, vibracion, perdida de pasos o zonas inseguras.
- Completar `validations/limites_fisicos/plantilla_limites_fisicos.csv`.

## Evidencia minima

- Captura o video de la tarjeta `Confiabilidad y cobertura` con RSSI, heartbeat y ultimo PONG.
- Video de prueba watchdog mostrando movimiento, interrupcion y alerta.
- Captura de monitor Serial con `PONG`, activacion de watchdog y alerta.
- Captura de fuzzing con errores cortos y sin crash.
- Foto o video de prueba de cobertura con distancia/obstaculo identificable.
