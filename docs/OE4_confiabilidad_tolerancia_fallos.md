# OE4 - Confiabilidad y tolerancia a fallos

Este documento describe la base de Fase 4 implementada sobre el Prototipo 3. La Fase 3 se mantiene: `GOTO`, `HOME`, `STATUS`, `STOP`, `TEST_ROUTINE`, BLE Notify, Serial y el pinout validado no cambian. Para el flujo de calibracion de una estrella se agregan `NUDGE` y `SET_POSITION`.

## Alcance implementado

- Heartbeat automatico desde Flutter mientras BLE esta conectado: `{"cmd":"PING"}` cada `300 ms`.
- Respuesta del ESP32: `{"status":"OK","msg":"PONG"}`.
- Watchdog manual desde UI: `{"cmd":"ENABLE_WATCHDOG","enabled":true}` o `false`.
- Timeout critico del watchdog: `1000 ms` sin recibir `PING`.
- Accion segura: si watchdog esta activo, hay movimiento y se supera el timeout, el ESP32 detiene ambos motores, cancela rutina activa y emite `ALERTA: conexión perdida. Motores detenidos en X ms` por Serial y BLE Notify.
- Manejo defensivo de comandos corruptos con errores cortos, sin devolver el comando recibido completo.

## Comandos Fase 4

| Comando | Origen | Respuesta esperada |
|---|---|---|
| `{"cmd":"PING"}` | Flutter automatico o Serial JSON | `{"status":"OK","msg":"PONG"}` |
| `{"cmd":"ENABLE_WATCHDOG","enabled":true}` | Switch UI o Serial JSON | `{"status":"OK","watchdog":true}` |
| `{"cmd":"ENABLE_WATCHDOG","enabled":false}` | Switch UI o Serial JSON | `{"status":"OK","watchdog":false}` |
| `{"cmd":"NUDGE","dAlt":0.25,"dAz":0}` | Control manual de calibracion | Movimiento relativo |
| `{"cmd":"SET_POSITION","alt":63.1548,"az":30.4972}` | Confirmar estrella centrada | Fija posicion logica interna |

## Errores defensivos

El firmware responde con mensajes cortos para evitar saturar BLE/Serial:

| Caso | Respuesta |
|---|---|
| Entrada no JSON | `ERROR: JSON invalido` |
| Comando no soportado | `ERROR: comando desconocido` |
| `alt` o `az` no numericos | `ERROR: alt/az no numericos` |
| Altitud fuera de `[-90, 90]` | `ERROR: altitud fuera de rango` |
| Azimut fuera de `[0, 360]` | `ERROR: azimut fuera de rango` |
| Campos requeridos ausentes | `ERROR: campos requeridos ausentes` |
| Comando mayor a 256 caracteres | `ERROR: comando demasiado largo` |

## Como probar watchdog

1. Cargar firmware Fase 4 en ESP32.
2. Abrir monitor Serial a `115200` baudios.
3. Abrir la app y conectar BLE a `AstroPilot-OE4`.
4. Entrar a `Control OE4` y verificar que `Heartbeat` este `Activo` y que `Ultimo PONG recibido` se actualice.
5. Activar el switch `Watchdog activo`.
6. Iniciar un movimiento con `GOTO 90 / 180`, un `GOTO` manual largo o `TEST_ROUTINE`.
7. Durante el movimiento, cortar el heartbeat apagando Bluetooth, cerrando la app o alejando el telefono fuera de cobertura.
8. Verificar que el ESP32 emita `ALERTA: conexión perdida. Motores detenidos en X ms` y que los motores se detengan.
9. Completar `validations/watchdog/plantilla_watchdog.csv` con el tiempo medido y evidencia.

## Como probar fuzzing

1. Usar las entradas de `validations/fuzzing/comandos_corruptos.json`.
2. Enviarlas por Serial o por BLE RX.
3. Verificar que no haya crash, reinicio ni movimiento inesperado.
4. Registrar respuesta observada, medio de envio y evidencia en `validations/fuzzing/plantilla_comandos_corruptos.csv`.

## Evidencia recomendada

- Video donde se ve el movimiento, la interrupcion de BLE y la alerta del watchdog.
- Captura del monitor Serial mostrando `PONG`, activacion de watchdog y alerta final.
- Captura de la tarjeta `Confiabilidad y cobertura` con heartbeat, watchdog, RSSI y ultima alerta.
- Tabla CSV completada despues de la prueba fisica.

## Nota experimental

Las plantillas quedan listas para mediciones reales. Este documento no inventa resultados: los datos fisicos deben medirse y completarse antes del viernes.
