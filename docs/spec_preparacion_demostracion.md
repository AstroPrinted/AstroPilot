# Preparación de la demostración de AstroPilot

Alcance autorizado por Axel en esta conversación: preparar instalación en iOS,
corregir los bloqueos críticos detectados y entregar una prueba por etapas,
además de una guía oral basada en la presentación v9.

## Historia de usuario

Como operador del prototipo quiero que una alineación se considere válida solo
si el ESP32 confirma la sincronización, y que los movimientos pequeños respeten
su sentido, para poder probar la montura de forma controlada.

## Reglas

- Las respuestas del firmware llevan un identificador de comando y delimitación
  para reconstruirse incluso si BLE las fragmenta. Error, desconexión o tiempo
  agotado no equivalen a éxito. Una respuesta de PING no confirma un movimiento.
- GOTO/NUDGE esperan fin de movimiento; SET_POSITION espera aceptación explícita.
  STOP permanece disponible durante un movimiento y cancela su espera.
- Una nueva conexión, desconexión o ejecución de la app requiere realineación.
  Una operación de alineación en curso no puede guardar éxito en otra sesión.
- El firmware arranca desalineado y rechaza apuntado astronómico hasta recibir
  SET_POSITION. Los movimientos de banco siguen siendo posibles sin estrellas.
- El azimut lógico se normaliza para coordenadas; los pasos del motor conservan
  continuidad. GOTO toma el recorrido angular corto y NUDGE conserva el signo.
- Alineación y apuntado astronómico usan la hora actual; la hora de planificación
  solo se permite para consulta. Los movimientos manuales no usan efemérides.
- Se conserva el bloqueo solar. No se implementa un modelo geométrico multipunto
  nuevo ni se certifica precisión óptica sin medir el montaje real.

## Casos satisfactorios

Conectar, STATUS/PING, mover ±1°/±10° en banco, STOP, centrar estrella de noche,
confirmar SET_POSITION, apuntar a segunda estrella y registrar error observado.

## Casos de fallo

Fallo BLE, respuesta ERROR, respuesta tardía de otro comando, GPS apagado,
reconexión, reinicio del ESP32, fecha planificada, confirmación durante movimiento,
cruce de azimut 0°/360° y límites de altitud. Mantener coordenadas manuales como
alternativa cuando no hay GPS.

## Aclaraciones

Se toma como referencia el firmware del repositorio para ESP32 + 28BYJ-48/ULN2003;
Ignacio debe confirmar el hardware y cargar el firmware actualizado. La Mac y el
iPhone estarán disponibles mañana: la compilación nativa y firma quedan pendientes
de esos equipos. Presentación de referencia: v9, confirmada tentativamente por Axel.
