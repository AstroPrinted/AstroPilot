# Calibracion del telescopio en AstroPilot

## 1. Que es la calibracion en AstroPilot

La calibracion en AstroPilot busca relacionar dos sistemas de referencia:

- La posicion astronomica calculada por la app para un objeto del cielo, expresada en altitud y azimut.
- La posicion interna estimada de los motores del prototipo, tambien expresada en altitud y azimut.

En una version completa, esta relacion deberia validarse observando una estrella en el ocular o mediante una camara. En el estado actual del prototipo, la app todavia no puede comprobar opticamente si el telescopio apunta exactamente al objeto.

## 2. Que implementa actualmente la Fase 1

La Fase 1 implementa un flujo funcional de calibracion logica y demostrativa:

1. El usuario inicia una correccion con 1 estrella.
2. La app permite enviar `HOME` al ESP32.
3. El usuario selecciona una estrella del catalogo existente.
4. La app calcula la posicion Alt/Az usando `EphemerisEngine`.
5. La app envia `GOTO(alt,az)` usando los servicios BLE existentes.
6. El usuario puede realizar ajustes finos con comandos `GOTO` incrementales.
7. La app registra la posicion ajustada como referencia estimada de motores.
8. La app calcula un offset simple entre posicion calculada y posicion ajustada.
9. La app guarda la correccion estimada en `SharedPreferences`.

Esta fase no modifica firmware, no agrega comandos nuevos y no aplica la correccion a los GoTo globales.

## 3. Por que la calibracion actual es logica/demostrativa

El sistema actual trabaja en lazo abierto. Esto significa que la app envia comandos al ESP32 y mantiene una estimacion local de la posicion objetivo, pero no recibe una confirmacion optica del apuntado real.

La app puede mover motores y registrar una referencia ajustada por el usuario, pero no puede afirmar que una estrella fue verificada visualmente. Por eso la UI usa terminos como:

- Correccion estimada.
- Posicion ajustada.
- Referencia de motores.
- Ajuste manual registrado.

## 4. Que significa correccion estimada

Una correccion estimada es un offset calculado entre:

- La altitud y el azimut calculados astronomicamente para una estrella.
- La altitud y el azimut ajustados manualmente por el usuario en la app.

Esta correccion sirve para demostrar el flujo de calibracion del prototipo, pero no certifica precision astronomica real.

## 5. Que datos se guardan

La app guarda localmente:

- Metodo usado, por ahora `1 estrella`.
- Fecha y hora de creacion.
- Objeto usado como referencia.
- Altitud calculada.
- Azimut calculado.
- Altitud ajustada.
- Azimut ajustado.
- Offset estimado de altitud.
- Offset estimado de azimut.
- Diferencia estimada del MVP.
- Estado de la correccion estimada.

La persistencia actual usa `SharedPreferences` mediante la feature `calibration`.

## 6. Como se calcula el offset

Para la Fase 1, el offset se calcula de forma simple:

```txt
offsetAltitud = altitudCalculada - altitudAjustada
offsetAzimut = azimutCalculado - azimutAjustado
```

El signo del offset debe validarse mas adelante con pruebas fisicas y observacion real. En esta fase se guarda como una correccion logica estimada.

## 7. Limitaciones actuales

- No existe validacion optica con ocular o camara.
- La app no detecta estrellas automaticamente.
- La app no puede asegurar precision astronomica real.
- El ajuste fino usa `GOTO` incremental, no comandos dedicados como `NUDGE`.
- El firmware actual no entrega `STATUS` estructurado en JSON para reconstruir posicion real desde la app.
- La correccion guardada no se aplica todavia a todos los GoTo globales.
- La calibracion con 2 y 3 estrellas solo esta preparada conceptualmente.
- El sync local todavia no esta implementado.

## 8. Fases futuras

Las siguientes fases deberian agregar:

- Validacion optica real con ocular o camara.
- Calibracion con 2 estrellas.
- Calibracion con 3 estrellas.
- Sync local por objeto o region del cielo.
- Parseo estructurado de `STATUS` desde el ESP32.
- Aplicacion de la correccion estimada a los GoTo globales.
- Validacion del signo del offset con pruebas fisicas.
- Modelo multipunto o interpolacion por zona del cielo.
