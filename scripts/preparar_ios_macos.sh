#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Este script debe ejecutarse en una Mac con Xcode."
  exit 1
fi
for tool in flutter pod xcodebuild xcrun; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Falta $tool. Revisa docs/IOS.md antes de continuar."
    exit 1
  fi
done

echo "Comprobando Flutter, Xcode y el SDK de iPhone..."
flutter --version
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
flutter doctor -v

echo "Instalando las dependencias del proyecto..."
flutter pub get
(
  cd ios
  pod install
)

echo "Compilando para iPhone sin firma..."
flutter build ios --release --no-codesign

echo "Compilación terminada. Falta elegir el Team y firmar para instalar."
echo "Abriendo Runner.xcworkspace. Sigue docs/IOS.md."
open ios/Runner.xcworkspace
