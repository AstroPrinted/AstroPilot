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
- El watchdog corta el movimiento si pasan más de 1000 ms sin recibir un PING. La app envía un PING cada 300 ms (`Oe4ControlController`). Un PING sin PONG no bloquea el siguiente por más de 600 ms.
- "GOTO Completado" solo llega cuando el PID queda dentro de 6 pulsos (unos 0.05°) con el perfil detenido. Con el telescopio pesado eso puede no pasar nunca. Por eso, mientras hay un movimiento, `MotorCommandService` pide STATUS cada 400 ms y `ArrivalDetector` (`lib/features/oe4_control/domain/telescope_position.dart`) lo da por terminado cuando el encoder queda a 0.05° o menos del objetivo (`arrived`, la misma tolerancia del PID) o deja de ACERCARSE al objetivo durante 2 s (`stalled`, se muestra un aviso). El avance se mide en distancia lineal, como el PID (de 0° a 200° gira por 1°, 2°, …, no por el camino corto). Antes de declararlo trabado, se le dan 5 s al motor para arrancar (`startGrace`), porque con carga pesada el PID tarda en vencer la fricción. No hay límite fijo de tiempo: un movimiento solo falla si el ESP32 deja de responder STATUS durante 10 s. La app no envía STOP: el PID del firmware sigue sosteniendo el objetivo. Que el PID no llegue a la tolerancia es un problema de firmware o mecánica: avisar a electrónica.

### Posición compartida del telescopio

- `MotorCommandService` guarda `targetPosition` (el último objetivo absoluto enviado, que es el mismo que usa el PID) y `motorPosition` (el último STATUS del encoder). Control, Alineación y Catálogo leen esos valores a través de `Oe4ControlController`.
- Todos los movimientos pasan por `Oe4ControlController.moveTo` (GOTO absoluto) o `moveBy` (GOTO calculado desde `motionBase`). La app ya no envía NUDGE: el firmware lo suma sobre su último objetivo, que puede haber quedado de otra pantalla. Ese fue el origen del bug en que el telescopio se movía el doble.
- `motionBase` es el objetivo, salvo cuando el telescopio quedó trabado lejos de él; en ese caso es el encoder.
- Al conectar se pide STATUS. Después de un STOP o un `ALERTA:`, el objetivo se toma del STATUS siguiente. SET_POSITION fija las dos posiciones.
- SET_POSITION (referencia manual y alineación inicial): si el firmware no dijo `Completado` (la app cerró el movimiento a su tolerancia), su PID sigue activo y el firmware rechaza el comando con "motores detenidos". `sendSetPositionCommand` envía STOP antes; si igual lo rechaza, envía STOP y reintenta una vez. Después envía un GOTO a las mismas coordenadas. Ese GOTO salió de una hipótesis que el `.ino` descartó (SET_POSITION sí actualiza el objetivo del PID), así que no corrige nada.

### Compensación de holgura en azimut (leída del `.ino` `astropilot_motorsV2_5_PCNT_y_BLE_en_Core0_V2.ino`)

- El firmware compensa 5° de holgura (`BACKLASH_DEG_AZ`) en azimut. El PID (Core 1) lleva `lastFlankAz`: +1 si el último objetivo de az subió y -1 si bajó, con un umbral de 0.01°. Arranca en -1. En el flanco -1 apunta el encoder 5° por debajo del objetivo, y STATUS informa `encoder + 5°`. Por eso el az de STATUS salta 5° apenas cambia el sentido, antes de que el motor se mueva. La altitud no tiene compensación.
- **Hipótesis sin probar en el telescopio** (el usuario prefirió dejarla de lado por ahora): sería la causa de "se mueve en azimut al fijar 0/0". SET_POSITION pone el encoder en `az` sin descontar la holgura y no actualiza `prevTargetDegAz`. Si después el flanco queda en -1, el PID lleva el motor 5° más abajo; con el engrane ya apoyado en ese flanco, el telescopio se mueve 5° de verdad. Como el flanco arranca en -1, basta con encender y fijar 0/0, sin mover nada antes. Cada SET_POSITION repetido lo mueve otros 5°.
- STOP y `ALERTA:` también fijan el objetivo en la posición física sin actualizar `prevTargetDegAz`. Si el telescopio quedó a más de 0.01° del objetivo, se registra un cambio de sentido y el motor recorre 5° de holgura.
- El arreglo correcto es del firmware (avisar a electrónica). En `setCurrentLogicalPosition`, descontar `BACKLASH_PULSES_AZ` del encoder si `lastFlankAz == -1` y poner `prevTargetDegAz = azDeg`. En `apagarHardwareMotores`, poner `prevTargetDegAz = sharedTargetDegAz`.
- El PID corre siempre, aunque `moving=false`: sostiene el objetivo y es él quien mueve el motor tras SET_POSITION o STOP.

## Estado y pendientes (al 2026-10-01)

- **Motor de azimut sin corriente.** Después de guardar y trasladar el telescopio, el motor de az no gira ni hace ruido; el encoder se queda fijo, mientras que la altitud funciona. Es un problema de hardware (cable, driver o alimentación del canal az, pines 18/19), no de la app. Mientras no se arregle, cualquier movimiento en az termina como "Se detuvo" (unos 7 s) y aparece el aviso de movimiento trabado.
- **La altitud no llega exacto a 0:** quedó en 0.35° en un GOTO 0/0. Está pendiente de revisar cuando vuelva el az.
- **El parche de holgura** (sección anterior) no se le ha propuesto a electrónica (Ignacio): primero hay que probarlo.
- **Pantallas viejas sin uso** (siguen en el código, pero nadie navega a ellas): `ConnectionScreen`, `CatalogScreen`, `CelestialDetailScreen`, `CelestialControlScreen`, `CalibrationScreen` con sus widgets, `BottomNavShell` y el hub de `StudentModeScreen`. Se pueden borrar si el usuario lo confirma. Quiz y Satélites reutilizan las pantallas viejas, a las que solo se les cambió la barra superior; falta darles el estilo nuevo.
- **Lo que no se implementó del diseño:**
  - "Curiosidades" y "Visible hoy a las HH:MM", porque el catálogo no tiene esos datos.
  - El nombre de la ciudad en la ubicación.
  - El método "Objeto fijo" del ajuste fino (queda como "Próximamente").

## Historial relevante

- **Sesión 2026-10-01:**
  - Se leyó el firmware real.
  - Se rehízo la navegación según el diseño (`lib/features/app_flow/`).
  - La alineación inicial ahora hace un GOTO aproximado desde 0/0. Si falla o se detiene, el usuario igual puede centrar a mano.
  - Las flechas mueven 0.25° y repiten mientras se mantienen presionadas. Los avisos van debajo de las flechas para no correrlas bajo el dedo.
  - "Guardar esta corrección" en Observar guarda una corrección de 1 estrella (`CalibrationController.saveObjectCorrection`) y reemplaza la anterior.
  - "Antes de empezar" (Conexión) abre Configuración al tocar Ubicación u Hora.
  - La app pasó a llamarse AstroPilot (`cl.astropilot.app`) y se firma con una llave propia.

- El commit `761f767` rompió la comunicación al exigir el protocolo v3. Lo corrigió `8ab8354`. Si "se conecta pero el telescopio no recibe nada", revisar primero que el parser coincida con los mensajes reales. Los logs del monitor serie del ESP32 muestran `BLE RX: …` para cada comando recibido.
- Al escanear, el telescopio se ordena primero (por UUID de servicio o por el nombre "AstroPilot"), usando `sortDevicesForTelescope`.

## Comandos

```
flutter pub get
flutter analyze lib test
flutter test
flutter build apk --release   # -> build/app/outputs/flutter-apk/app-release.apk
```

Android: id `cl.astropilot.app`, nombre "AstroPilot". El APK release se firma con `android/app/astropilot-release.jks` (alias `astropilot`), con las claves en `android/key.properties`. Ninguno de los dos va al repositorio. Hay que respaldarlos: sin esa llave, los APK nuevos no pueden instalarse encima de los anteriores. Si `key.properties` no existe, el release se firma con la llave de debug.

iOS (Mac): `cd ios && pod install`, abrir `ios/Runner.xcworkspace`, elegir el equipo de firma (Apple ID) y `flutter run`. Ver `docs/IOS.md` y `scripts/preparar_ios_macos.sh`.

## Estructura

- Navegación (diseño "AstroPilot" en claude.ai/artifact/85PCubJGvAuTeubhXDLb6c): Bienvenida y permisos (solo la primera vez) → Inicio → modo Observación o Educativo. Está en `lib/features/app_flow/`. `AppFlowState` guarda el paso del tutorial, el 0/0 fijado, el ajuste fino saltado, el objeto pendiente que viene de Educativo y si se perdió la alineación al desconectarse. Las pantallas reutilizan los controladores de cada feature.
- Observación: un tutorial de 5 pasos con indicador (Conexión, Nivelación con SET_POSITION 0/0, Alineación con estrella, Ajuste fino opcional y Catálogo). Las pestañas son Conexión (solo sin conexión), Alineación, Catálogo y Técnico (`Oe4ControlScreen`). La alineación con estrella hace primero un GOTO aproximado desde el 0/0; después el usuario centra la estrella y confirma, y la app envía SET_POSITION con las coordenadas de la estrella.
- Componentes visuales del diseño: `lib/core/widgets/ap_widgets.dart` y `lib/core/theme/app_colors.dart`.
- `lib/features/ble_connection/`: escaneo, conexión y permisos.
- `lib/features/oe4_control/`: `MotorCommandService` (GATT y comandos), `MotorReplyProtocol` (asocia las respuestas a los comandos) y la pantalla de control manual.
- `lib/features/calibration/`: alineación con una estrella y corrección.
- `lib/features/catalog/`: catálogo, GoTo astronómico y tracking lógico (reenvía GOTO cada 15 s).
- `lib/features/observation/`: efemérides (Alt/Az).
- `test/oe4_control/motor_reply_protocol_test.dart`: tests del protocolo con los mensajes reales del firmware. Actualizarlos si el firmware cambia sus textos.
