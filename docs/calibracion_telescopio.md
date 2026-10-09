# Calibración del telescopio en AstroPilot

La rama `codex/ios-prototype` usa el protocolo v3 del firmware incluido.

## Alineación inicial

1. Usar ubicación real y “Usar hora actual” en Configuración.
2. Conectar el ESP32 y seleccionar una estrella reconocible sobre 15° de altitud.
3. Centrarla físicamente con el buscador/ocular y ajustes relativos NUDGE.
4. Confirmar la estrella centrada. La app recalcula su Alt/Az y envía SET_POSITION.
5. Solo guardar la alineación después de recibir la confirmación del ESP32.

SET_POSITION asigna coordenadas lógicas a la orientación física existente; no
mueve el telescopio. Luego, GoTo calcula el destino y el firmware mueve los ejes
hacia esa posición. La base debe estar nivelada y la escala y sentidos de los
motores deben coincidir con el montaje. La alineación no mide esas propiedades.

## Correcciones

Después de alinear, están disponibles correcciones con una, dos o tres estrellas.
Para cada referencia: GoTo, esperar finalización, centrar y confirmar. La posición
usada para la corrección procede del STATUS de pasos ejecutados por el ESP32.
Esto es posición lógica de un motor abierto, sin medición de encoder: no detecta
pasos perdidos, holgura ni deslizamiento físico.

Los modos de dos/tres estrellas promedian offsets de altitud/azimut. No constituyen
un modelo geométrico que corrija automáticamente desnivel o errores mecánicos.

## Confirmaciones y vigencia

- Cada comando JSON lleva un `id`; cada respuesta BLE es `@id mensaje\n`.
- Un GATT write exitoso o un PONG no confirma una alineación ni un movimiento.
- GOTO/MOVE, NUDGE y HOME esperan su respuesta de finalización; el firmware envía
  STATUS antes de esa respuesta. ERROR, ALERTA, timeout o desconexión son fallos.
- STOP puede interrumpir un movimiento. No se permite guardar como corrección una
  referencia cuyo último ajuste fue interrumpido o falló.
- SharedPreferences conserva los datos, pero solo se aceptan dentro de la sesión
  actual de app/conexión. Reiniciar o reconectar exige alinear de nuevo.
- Si la base se mueve o la mecánica pierde posición sin una desconexión, el usuario
  debe rehacer la alineación: el sistema no puede detectarlo automáticamente.
- La hora de planificación sirve para consultar el cielo; bloquea alineación y
  GoTo físicos. El apuntado solar permanece bloqueado.

## Movimientos de banco

En **Control OE4 → Calibrar posición actual** se pueden asignar las coordenadas
reales de una orientación conocida sin mover los motores. Primero colocar el
telescopio usando el control manual y esperar a que termine. Por ejemplo, si
queda horizontal cuando el control indica −3° de altitud, dejarlo ahí y fijar
altitud real 0° junto con su azimut real. Altitud 0° significa horizontal y 90°
hacia arriba; azimut 0° significa norte (−3° equivale a 357°).

El botón **Fijar coordenadas actuales** envía SET_POSITION y espera la respuesta
del firmware. Una confirmación válida invalida la alineación y las correcciones
anteriores de la app; para GoTo astronómico hay que alinear nuevamente con una
estrella. Un comando rechazado no muestra éxito. Esta referencia es lógica y no
se restaura automáticamente tras reiniciar el ESP32.

Control permite MOVE sin alineación para comprobar motores en coordenadas lógicas.
Esto no habilita GoTo astronómico. NUDGE conserva el signo al cruzar azimut 0°;
los destinos absolutos de azimut usan el trayecto más corto. HOME vuelve al cero
lógico, no busca un interruptor de origen.

El firmware tiene 4096 medios pasos nominales por revolución. Ignacio debe
comprobar la relación de transmisión externa, pinout, escala física y sentidos
antes de evaluar precisión de apuntado.

## Validación pendiente

El control de objetos recalcula la posición y el destino corregido cada segundo,
incluso con tracking apagado o sin BLE. Usa la hora de Configuración: con una hora
de planificación fija es normal que las coordenadas no avancen. Esta actualización
no envía comandos; el tracking mantiene su intervalo de envío de 15 segundos.
El último comando enviado conserva las coordenadas efectivamente enviadas.

La compilación y las pruebas automatizadas verifican código y manejo de errores.
Siguen pendientes la compilación/firma iOS en Mac, Bluetooth/GPS en iPhone y las
mediciones de apuntado con la montura real.
