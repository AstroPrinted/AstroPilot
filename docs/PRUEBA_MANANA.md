# Prueba del prototipo en iPhone y montura

Verificación local del 8 de septiembre de 2026: **72 pruebas Flutter aprobadas**,
`flutter analyze --no-pub` sin incidencias, sintaxis del script comprobada con
`bash -n` y firmware compilado para ESP32 Dev Module con BLE activado (84% flash,
12% RAM estática). No se ha compilado en Xcode ni instalado en iPhone, ni se ha
cargado el firmware o medido una montura física desde esta sesión.

La presentación es a las 11:00 y la salida de casa está prevista entre 09:30 y
10:00. La instalación inicial de Xcode/Flutter puede necesitar bastante tiempo:
coordinar con la profesora que la Mac tenga estas herramientas disponibles antes
de la sesión. Si la preparación se extiende, separar la exposición de la prueba técnica.

## Qué llevar y qué preparar

- Presentación v9 y guion/guía oral guardados localmente y en un respaldo.
- Mac con Xcode, SDK de iOS, Flutter y CocoaPods; acceso a Internet para descargar
  dependencias la primera vez. Cuenta Apple para firmar la app.
- iPhone desbloqueado, cable de datos compatible y cargadores/adaptadores.
- ESP32, firmware actualizado, dos 28BYJ-48/ULN2003 y fuente del montaje que
  confirme Ignacio. Confirmar también relación mecánica, sentido de giro y placa.
- Instrumento para comprobar el ángulo físico (transportador/inclinómetro), marcas
  de referencia, libreta y telescopio preparado por quien conoce el montaje.

**Actualizar la app y el firmware juntos.** Esta rama usa confirmaciones del
protocolo v3; con el firmware anterior la app mostrará falta de confirmación.
Ese error no se resuelve reinstalando permisos de iOS.

## 1. Instalar en la Mac y el iPhone

```sh
git clone --branch codex/ios-prototype --single-branch https://github.com/Ascenal2/astropilot-app.git
cd astropilot-app
bash scripts/preparar_ios_macos.sh
```

Si ya tienen el repositorio, entrar en él y ejecutar `git pull --ff-only` estando
en `codex/ios-prototype` antes del script. El script comprueba herramientas,
instala dependencias y compila sin firma. No instala Xcode ni configura la cuenta
Apple por sí mismo. Los pasos completos están en [IOS.md](IOS.md).

En Xcode: abrir `ios/Runner.xcworkspace`, seleccionar Runner, configurar Signing &
Capabilities con Automatically manage signing y el Team disponible. Ajustar el
Bundle Identifier si la cuenta no puede registrarlo. Conectar y confiar en el
iPhone, activar Developer Mode cuando corresponda y seleccionar ese dispositivo.

Para dejar una app que pueda abrirse desde su icono, una vez configurada la firma:

```sh
flutter devices
flutter run --release -d IDENTIFICADOR_DEL_IPHONE
```

Probar abrirla de nuevo desde el icono antes de desconectar la Mac. La firma con
Personal Team es temporal; no es una publicación en App Store.

## 2. Cargar el firmware actualizado con Ignacio

Abrir `firmware/astropilot_motors/astropilot_motors.ino` en Arduino IDE, conservando
`motion_math.h` en esa misma carpeta. Seleccionar la placa y puerto reales.
La comprobación de compilación de esta rama usa ESP32 Dev Module, paquete
`esp32:esp32` 3.3.5 y AccelStepper 1.64. No implica que se haya cargado en el ESP32.

Arduino IDE: Verify y después Upload cuando Ignacio confirme placa, conexiones
y condiciones de la prueba. En monitor serie a 115200 debe aparecer **Firmware v3**
y `protocol=3` en STATUS. Solo entonces usar la app nueva para mover la montura.

## 3. Prueba diurna por etapas

A las 11:00 planificar una demostración de funcionamiento. No usar una fecha
nocturna de planificación para tratar de alinear físicamente durante el día.
La prueba con estrellas queda para un momento con oscuridad y cielo disponible.
Mantener el telescopio lejos del Sol; el apuntado solar permanece bloqueado.

1. **Interfaz:** abrir la app, consultar catálogo y fichas educativas. Resultado:
   la aplicación funciona en el iPhone. Esto todavía no valida BLE ni GoTo físico.
2. **Datos:** en Config, activar Usar hora actual. Comprobar ubicación GPS; si falla,
   ingresar coordenadas manuales reales del lugar. No usar Santiago por defecto
   cuando estén en otro lugar.
3. **Conexión:** conectar a AstroPilot-OE4. En Control, solicitar STATUS y comprobar
   respuestas/PONG. Registrar si el enlace se corta y a qué distancia estaban.
4. **Banco:** con motores detenidos, consultar STATUS y marcar la posición física
   inicial. El campo Alt/Az de Control es una posición lógica de banco, no una
   alineación astronómica. Tras arrancar en cero, ordenar primero Alt=0/Az=1 y
   volver a 0/0. Después probar 0/10 y 0/0. Medir cuánto giró realmente.
5. **Sentido contrario:** desde cero, 0/350 debe equivaler a aproximadamente 10°
   hacia el otro lado, no 350° de recorrido. Probar después altitud en un rango
   que Ignacio confirme libre de topes. Si gira en sentido o magnitud incorrectos,
   detener y corregir el montaje/configuración antes de seguir.
6. **STOP:** durante un movimiento permitido de banco, pulsar STOP. Debe detenerse;
   la operación cancelada no debe contabilizarse como movimiento terminado.
7. **Reconexión:** desconectar/reconectar. La app debe pedir una nueva alineación
   antes de GoTo astronómico. Reiniciar el ESP32 también debe dejarlo desalineado.

No empezar por los botones de 90°/180° ni por TEST_ROUTINE: primero verificar
movimientos pequeños, espacio disponible, cables y sentidos de giro.
No confirmar “estrella centrada” si no han identificado y centrado una estrella.

Una referencia terrestre distante puede servir para revisar enfoque óptico y
repetibilidad de movimiento con Ignacio; **no valida las efemérides ni sustituye
la alineación con estrellas**. La app orienta, el enfoque óptico se ajusta en el telescopio.

## 4. Prueba nocturna del apuntado

1. Nivelar/estabilizar la base y comprobar el buscador con Ignacio. Verificar hora
   y ubicación reales. Mantener la app en primer plano y el teléfono cerca.
2. Entrar a Calibración, iniciar alineación y seleccionar una estrella reconocible
   de la lista sobre 15° de altitud. Evitar empezar cerca del cenit.
3. Centrarla con el buscador/ocular y los movimientos controlados. Esperar a que
   termine cada movimiento. Usar valores pequeños en el ajuste cuando haga falta.
4. Confirmar estrella centrada. Debe recibirse `SET_POSITION OK` antes de guardar
   la alineación. Error, desconexión o timeout requieren corregir la causa y repetir.
5. Elegir una segunda estrella visible desde Catálogo, ejecutar GoTo y observar
   dónde termina el telescopio. No guardar aún correcciones: primero medir la base.
6. Registrar si aparece en buscador/ocular, cuánto ajuste requiere, tiempo de giro
   y si se repite el resultado al volver a la primera estrella.
7. Probar seguimiento después de lograr un GoTo útil. El prototipo actual envía
   actualizaciones cada 15 segundos; medir deriva y no prometer astrofotografía.

La corrección de 2/3 estrellas sigue siendo un promedio de offsets; no compensa
por sí sola desnivel, holgura ni una relación de transmisión incorrecta.
Rehacer alineación si se mueve la base, se pierde posición mecánica o se reconecta.

## Registro mínimo

| Prueba | Resultado observado | Qué demuestra |
|---|---|---|
| Abre en iPhone | Pendiente | Instalación y arranque |
| STATUS/PONG | Pendiente | Comunicación con firmware v3 |
| +1°, −1°, +10°, −10° | Pendiente | Sentido y escala real de los ejes |
| STOP durante movimiento | Pendiente | Interrupción del movimiento |
| Reinicio/reconexión | Pendiente | Invalidación de la referencia anterior |
| Alineación con estrella A | Pendiente nocturno | Referencia inicial aceptada |
| GoTo a estrella B | Pendiente nocturno | Error de apuntado observado |

Si falla una etapa, mostrar y explicar las etapas anteriores que sí se verificaron.
No presentar una simulación del catálogo como un éxito de apuntado físico.
