# AstroPilot

App Flutter (Android + iOS) que controla por BLE un telescopio alt-az motorizado (ESP32, "OE4"). Rama de trabajo: `codex/ios-prototype`. UI y mensajes en español.

## Firmware real: el del equipo de electrónica

- **No modificar el firmware del equipo de electrónica.** La app se adapta a él.
- `firmware/astropilot_motors/` es un firmware VIEJO de motores paso a paso (AccelStepper, protocolo "v3" con `@<id> msg\n`). **No es el que corre en el telescopio. No cargarlo en el ESP32 ni usarlo como referencia del protocolo.**
- El firmware real usa motores DC con encoders (PCNT), un PID a 100 Hz en el Core 1 y BLE/Serial en el Core 0. Si cambia, pedir al usuario el `.ino` actualizado.

### Protocolo BLE (firmware real)

- Nombre anunciado: `AstroPilot-OE4`. Servicio NUS `6e400001-b5a3-f393-e0a9-e50e24dcca9e`, RX write `6e400002-…`, TX notify `6e400003-…`.
- Comandos: JSON en una sola escritura, máximo 256 bytes. `cmd` es obligatorio; las claves desconocidas se ignoran.
  - `GOTO {alt, az}`: alt entre -90 y 90, az entre -360 y 360. Sin chequeo de alineación. Si llega un GOTO durante un movimiento, simplemente cambia el objetivo.
  - `NUDGE {dAlt, dAz}`: relativo al último objetivo (no a la posición del encoder); el azimut se normaliza a 0–360.
  - `SET_POSITION {alt, az}`: fija la posición lógica; da error si hay movimiento en curso.
  - `HOME`, `STATUS`, `STOP`, `PING`, `ENABLE_WATCHDOG {enabled}`, `TEST_ROUTINE`.
  - **No existe `MOVE`** (responde `ERROR: comando desconocido`).
- Respuestas: **texto plano, un mensaje por notificación, sin id ni `\n`**. Se asocian al comando por su texto (`lib/features/oe4_control/domain/motor_reply_protocol.dart`):
  - `Comando: GOTO …` (acuse), luego `GOTO Completado` / `NUDGE Completado` / `HOME Completado` al terminar.
  - `SET_POSITION OK -> …` seguido de un STATUS.
  - `STATUS -> posicion interna actual: alt=<int> pulsos (<deg> deg), az=<float> pulsos (<deg> deg), moving=…, watchdog=…`
  - `STOP Completado -> movimiento detenido`, `{"status":"OK","msg":"PONG"}`, `{"status":"OK","watchdog":true|false}`.
  - `ERROR: …` es la respuesta síncrona al comando recién escrito. `ALERTA: …` indica que el watchdog detuvo los motores.
- El firmware no envía STATUS al terminar un movimiento, así que `MotorCommandService` lo pide después de cada GOTO, NUDGE o HOME, porque la calibración necesita la posición final.
- El watchdog corta el movimiento si pasan más de 1000 ms sin recibir un PING. La app envía un PING cada 300 ms (`Oe4ControlController`).
- "GOTO Completado" solo llega cuando el PID queda dentro de 6 pulsos (unos 0.05°) con el perfil detenido. Si el motor no llega a esa tolerancia, la app agota el tiempo de espera (60 s) aunque el telescopio se haya movido. Esto es del lado del firmware: avisar a electrónica.

## Historial relevante

- El commit `761f767` rompió la comunicación al exigir el protocolo v3. Lo corrigió `8ab8354`. Si "se conecta pero el telescopio no recibe nada", revisar primero que el parser coincida con los mensajes reales. Los logs del monitor serie del ESP32 muestran `BLE RX: …` para cada comando recibido.
- Al escanear, el telescopio se ordena primero (por UUID de servicio o por el nombre "AstroPilot"), usando `sortDevicesForTelescope`.

## Comandos

```
flutter pub get
flutter analyze lib test
flutter test
flutter build apk --release   # -> build/app/outputs/flutter-apk/app-release.apk
```

iOS (Mac): `cd ios && pod install`, abrir `ios/Runner.xcworkspace`, elegir el equipo de firma (Apple ID) y `flutter run`. Ver `docs/IOS.md` y `scripts/preparar_ios_macos.sh`.

## Estructura

- `lib/features/ble_connection/`: escaneo, conexión y permisos.
- `lib/features/oe4_control/`: `MotorCommandService` (GATT y comandos), `MotorReplyProtocol` (asocia las respuestas a los comandos) y la pantalla de control manual.
- `lib/features/calibration/`: alineación con una estrella y corrección.
- `lib/features/catalog/`: catálogo, GoTo astronómico y tracking lógico (reenvía GOTO cada 15 s).
- `lib/features/observation/`: efemérides (Alt/Az).
- `test/oe4_control/motor_reply_protocol_test.dart`: tests del protocolo con los mensajes reales del firmware. Actualizarlos si el firmware cambia sus textos.
