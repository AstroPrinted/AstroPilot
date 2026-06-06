# Calibracion del telescopio en AstroPilot

## 1. Objetivo

La calibracion relaciona la orientacion fisica real del telescopio con la posicion logica interna de los motores. Antes de usar GoTo automatico, el usuario debe centrar manualmente una estrella conocida y la app debe fijar la posicion actual del sistema con la Alt/Az real de esa estrella.

## 2. Flujo implementado

La version actual trabaja solo con calibracion de una estrella:

1. El usuario entra a Calibracion.
2. La UI muestra 1 estrella como metodo disponible.
3. Los modos 2 estrellas, 3 estrellas y objeto fijo quedan deshabilitados como Proximamente.
4. La app lista estrellas visibles sobre el horizonte usando fecha, hora y ubicacion actuales.
5. El usuario selecciona una estrella de referencia.
6. La app muestra nombre, constelacion, magnitud, Alt/Az actual y una guia breve para reconocerla.
7. El usuario mueve manualmente el telescopio con controles `NUDGE`.
8. Cuando la estrella esta centrada, presiona Confirmar estrella centrada.
9. La app recalcula la Alt/Az de la estrella en ese instante.
10. La app envia `SET_POSITION(alt,az)` al ESP32.
11. La calibracion queda guardada como referencia valida.

## 3. Comandos de firmware

El firmware mantiene `GOTO` para apuntamientos automaticos, pero la calibracion usa comandos especificos:

```txt
NUDGE:dAlt,dAz
SET_POSITION:alt,az
```

`NUDGE` mueve los motores de forma relativa desde la posicion interna actual. `SET_POSITION` no mueve el telescopio; solo fija la posicion logica interna del firmware para que la posicion fisica centrada corresponda a la Alt/Az real de la estrella.

## 4. Logica correcta

No se usa regla de 3 ni un offset de una estrella para estimar otros objetos.

La app calcula la Alt/Az real de cada objetivo con fecha, hora y ubicacion. Luego envia esa Alt/Az como destino. Como el firmware ya conoce su posicion logica actual gracias a `SET_POSITION`, el movimiento fisico sale de la diferencia entre posicion actual y objetivo.

## 5. Datos guardados

La app guarda:

- Metodo usado: `oneStar`.
- Estado de calibracion.
- Estrella de referencia.
- RA/Dec J2000 de la estrella.
- Alt/Az real de la estrella al confirmar.
- Posicion logica de motores fijada con `SET_POSITION`.
- Fecha y hora de calibracion.
- Advertencias del flujo si existen.

La persistencia usa `SharedPreferences` mediante la feature `calibration`.

## 6. Reglas de seguridad y uso

- GoTo y tracking quedan bloqueados antes de calibrar.
- El movimiento manual si esta permitido antes de calibrar.
- Si la estrella cae bajo el horizonte, no se puede confirmar.
- La Alt/Az se recalcula al momento exacto de confirmar.
- Si no hay ubicacion valida, el flujo debe fallar o pedir ubicacion manual desde ajustes.
- La calibracion de una estrella es una referencia inicial; no corrige errores mecanicos, desnivel del tripode ni desalineacion avanzada.

## 7. Pendiente

- Calibracion con 2 estrellas.
- Calibracion con 3 estrellas.
- Sync local por objeto fijo.
- Estado estructurado JSON desde firmware.
- Modelo multipunto para correcciones mecanicas avanzadas.
