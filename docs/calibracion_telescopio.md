# Calibración del telescopio en AstroPilot

## 1. Objetivo

La calibración relaciona la orientacion física real del telescopio con la posición lógica interna de los motores. Antes de usar GoTo automático, el usuario debe centrar manualmente una estrella conocida y la app debe fijar la posición actual del sistema con la Alt/Az real de esa estrella.

## 2. Flujo implementado

La version actual trabaja solo con calibración de una estrella:

1. El usuario entra a Calibración.
2. La UI muestra 1 estrella como método disponible.
3. Los modos 2 estrellas, 3 estrellas y objeto fijo quedan deshabilitados como Proximamente.
4. La app lista estrellas visibles sobre el horizonte usando fecha, hora y ubicación actuales.
5. El usuario selecciona una estrella de referencia.
6. La app muestra nombre, constelación, magnitud, Alt/Az actual y una guía breve para reconocerla.
7. El usuario mueve manualmente el telescopio con controles `NUDGE`.
8. Cuando la estrella está centrada, presiona Confirmar estrella centrada.
9. La app recalcula la Alt/Az de la estrella en ese instante.
10. La app envía `SET_POSITION(alt,az)` al ESP32.
11. La calibración queda guardada como referencia válida.

## 3. Comandos de firmware

El firmware mantiene `GOTO` para apuntamientos automáticos, pero la calibración usa comandos específicos:

```txt
NUDGE:dAlt,dAz
SET_POSITION:alt,az
```

`NUDGE` mueve los motores de forma relativa desde la posición interna actual. `SET_POSITION` no mueve el telescopio; solo fija la posición lógica interna del firmware para que la posición física centrada corresponda a la Alt/Az real de la estrella.

## 4. Lógica correcta

No se usa regla de 3 ni un offset de una estrella para estimar otros objetos.

La app calcula la Alt/Az real de cada objetivo con fecha, hora y ubicación. Luego envía esa Alt/Az como destino. Como el firmware ya conoce su posición lógica actual gracias a `SET_POSITION`, el movimiento físico sale de la diferencia entre posición actual y objetivo.

## 5. Datos guardados

La app guarda:

- Método usado: `oneStar`.
- Estado de calibración.
- Estrella de referencia.
- RA/Dec J2000 de la estrella.
- Alt/Az real de la estrella al confirmar.
- Posición lógica de motores fijada con `SET_POSITION`.
- Fecha y hora de calibración.
- Advertencias del flujo si existen.

La persistencia usa `SharedPreferences` mediante la feature `calibration`.

## 6. Reglas de seguridad y uso

- GoTo y tracking quedan bloqueados antes de calibrar.
- El movimiento manual sí está permitido antes de calibrar.
- Si la estrella cae bajo el horizonte, no se puede confirmar.
- La Alt/Az se recalcula al momento exacto de confirmar.
- Si no hay ubicación válida, el flujo debe fallar o pedir ubicación manual desde ajustes.
- La calibración de una estrella es una referencia inicial; no corrige errores mecánicos, desnivel del trípode ni desalineación avanzada.

## 7. Pendiente

- Calibración con 2 estrellas.
- Calibración con 3 estrellas.
- Sync local por objeto fijo.
- Estado estructurado JSON desde firmware.
- Modelo multipunto para correcciones mecanicas avanzadas.
