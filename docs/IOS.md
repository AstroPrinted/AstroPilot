# AstroPilot en iPhone

El proyecto tiene configurado un mínimo de iOS 13.0. La configuración nativa y
el flujo de permisos están preparados para iOS; la compilación con Xcode y la
validación de Bluetooth/GPS en un iPhone físico siguen pendientes.

Esta versión debe usarse con el firmware v3 incluido en la rama.
En una Mac con las herramientas ya instaladas, `bash scripts/preparar_ios_macos.sh`
realiza la preparación y compilación sin firma descritas más abajo.

## Configuración incluida

- Nombre visible: AstroPilot.
- Identificador base: `cl.astropilot.app`, con `cl.astropilot.app.RunnerTests`
  para las pruebas. Su disponibilidad en la cuenta de Apple no se ha verificado;
  si ya está registrado por otra cuenta, reemplazarlo por un identificador propio
  en Debug, Profile y Release de ambos targets.
- CocoaPods: `ios/Podfile` integra los plugins y habilita los permisos nativos de
  Bluetooth y ubicación durante el uso. Los archivos `.xcconfig` incluyen Pods.
- iPhone solicita `Permission.bluetooth` para BLE. La ubicación se solicita
  solamente al activar GPS en Configuración. Negar GPS permite usar coordenadas
  manuales y seguir conectándose por Bluetooth.
- La app espera a que CoreBluetooth termine de inicializarse, muestra también
  dispositivos sin nombre y permite reintentar si falla el escaneo.
- No se habilita ubicación ni control de la montura en segundo plano.

## Preparar y compilar en una Mac

Clonar la rama del prototipo, que contiene la app completa y los cambios de iOS:

```sh
git clone --branch codex/ios-prototype --single-branch https://github.com/Ascenal2/astropilot-app.git
cd astropilot-app
```

Instalar Xcode, sus herramientas de línea de comandos, CocoaPods y Flutter.
La versión del SDK usada para la verificación local de este cambio es
Flutter 3.35.7 / Dart 3.9.2. Usar inicialmente esa misma versión para reproducir
el entorno; al actualizar Flutter, revisar de nuevo el mínimo de iOS admitido.

Si la Mac aún no está preparada, seguir la [instalación oficial de Flutter para
iOS](https://docs.flutter.dev/platform-integration/ios/setup). Xcode debe soportar
la versión de iOS del teléfono. Abrir Xcode una vez, instalar sus componentes y
añadir la cuenta Apple en Xcode → Settings → Accounts. Si `flutter doctor` indica
que está seleccionada solamente Command Line Tools, ejecutar en la Mac:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
xcodebuild -downloadPlatform iOS
```

Revisar y aceptar la licencia de Xcode cuando se solicite. Para una prueba local
puede usarse un Personal Team gratuito; no hace falta publicar en TestFlight.
Al terminar la instalación, si el iPhone indica “desarrollador no confiable”,
ir a Ajustes → General → VPN y gestión de dispositivos y confiar en la cuenta.
La guía oficial enlazada detalla estos pasos. Si Xcode no puede soportar el iOS
del teléfono en esa Mac, hará falta un teléfono compatible o actualizar la Mac.

Desde la raíz del proyecto:

```sh
flutter doctor -v
flutter pub get
cd ios
pod install
cd ..
flutter build ios --release --no-codesign
open ios/Runner.xcworkspace
```

`flutter pub get` debe ejecutarse en la Mac para regenerar las rutas locales de
Flutter. No copiar `Pods`, `.symlinks`, `.dart_tool`, `build` ni los archivos
generados de Windows. `pod install` genera la integración de Xcode y
`ios/Podfile.lock`; conservar este último en el repositorio después de una
instalación exitosa. Abrir el archivo **xcworkspace** para incluir los plugins.

La compilación con `--no-codesign` verifica el código nativo, pero no produce una
app instalable sin firma. En Xcode, seleccionar Runner → Signing & Capabilities,
activar Automatically manage signing y elegir el Team de la cuenta de Apple.
Revisar el Bundle Identifier y seleccionar el iPhone conectado. Si se usa
RunnerTests, asignar también su Team. Habilitar Developer Mode en el iPhone si
su versión de iOS lo solicita y ejecutar Run, o usar:

```sh
flutter devices
flutter run --release -d IDENTIFICADOR_DEL_IPHONE
```

Para distribuir mediante TestFlight/App Store se requiere la membresía del
Apple Developer Program y configurar la distribución en esa cuenta. No hay
certificados ni un Team personal guardados en este proyecto.

## Prueba física pendiente

1. Abrir la app, permitir Bluetooth y buscar `AstroPilot-OE4` con el ESP32
   encendido y el firmware BLE OE4 cargado.
2. Conectar y verificar una respuesta a `PING` o `STATUS`. Validar después los
   controles y `STOP` con la montura preparada para la prueba.
3. Desconectar, volver a conectar y apagar/encender Bluetooth en Ajustes.
4. Negar Bluetooth: debe aparecer el botón para abrir la configuración de la
   app. Autorizarlo allí, volver y pulsar Solicitar permisos.
5. Activar GPS en Configuración y permitir ubicación durante el uso. Probar
   también permiso denegado y servicios de ubicación desactivados: deben seguir
   disponibles las coordenadas manuales. La restricción existente a Chile
   continúa aplicándose; fuera de Chile se usa el modo manual.

Los UUID de servicio/características BLE son los mismos que en Android. El
identificador del dispositivo en iOS es un UUID del sistema, no una dirección
MAC. El simulador sirve para revisar la interfaz; no valida la conexión real
con la montura. Mantener la app en primer plano durante estas pruebas.

Referencias: [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus),
[permission_handler](https://pub.dev/packages/permission_handler) y
[geolocator](https://pub.dev/packages/geolocator).
