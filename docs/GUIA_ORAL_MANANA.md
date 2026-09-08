# AstroPilot: ideas para presentar mañana

Referencia: `AstroPilot_presentacion_reorganizada_v9.pptx` (17 diapositivas) y
`Guion_presentacion_AstroPilot_10-15_min_v2.docx`. El guion largo menciona v7 en
su portada; esta guía sigue el orden real de la v9, incluida su comparación de referentes.

Tu hilo conductor es: **Chile tiene una oportunidad educativa; hay barreras de
costo y uso; AstroPrinted construye el instrumento; AstroPilot aporta el software;
las pruebas del cálculo están realizadas y falta medir el apuntado físico.**

No necesitas memorizar los párrafos. Mira la diapositiva, recuerda su idea y
explícala con tus palabras. Apunta a 12–14 minutos de exposición, dejando la
demostración aparte si la profesora no la incluye en ese tiempo.

| N.º | Idea que debes entender | Una forma breve de decirla |
|---|---|---|
| 1. AstroPilot | Tu contribución es el software dentro de un proyecto interdisciplinario. | “Soy Axel López y desarrollé AstroPilot, la aplicación que conecta al usuario con el telescopio AstroPrinted y guía su operación.” |
| 2. Chile y acceso desigual | Tener observatorios no significa que todos los estudiantes puedan observar. | “Según la BCN, en el informe de 2025 citado en mi trabajo, Chile concentra más del 40% de la capacidad de observación astronómica global. Esa ventaja no se traduce automáticamente en acceso educativo.” |
| 3. Dos barreras | Hay que resolver tanto el costo del instrumento como la dificultad de usarlo. | “Identificamos una barrera económica y otra técnica. Un telescopio puede ser costoso, pero incluso teniéndolo necesitamos saber operarlo.” |
| 4. AstroPrinted | Atribuye la estructura, óptica, electrónica y montaje al equipo. | “AstroPrinted aborda la construcción de un telescopio educativo replicable mediante impresión 3D y electrónica accesible. Mi trabajo se concentra en la aplicación.” |
| 5. La pieza que faltaba | El teléfono convierte la intención del usuario en instrucciones para el ESP32. | “Faltaba una interfaz que resolviera dónde está el observador, dónde está el objeto y cómo guiar la operación sin escribir comandos manualmente.” |
| 6. Pregunta de investigación | Se pregunta cómo construir software útil para ese contexto educativo. | “La pregunta fue cómo diseñar una aplicación que apoye la calibración y el seguimiento del telescopio y facilite su uso en educación STEM.” |
| 7. Objetivo general | Implementar ese software, no certificar todo el instrumento físico. | “El objetivo general fue diseñar e implementar el software móvil para calibrar y seguir objetos celestes con AstroPrinted.” |
| 8. Objetivos específicos | Divide el objetivo en componentes verificables. | “Organicé el desarrollo en comunicación inalámbrica, aplicación móvil, cálculo de efemérides y automatización mediante alineación, GoTo y seguimiento.” |
| 9. Referentes | PiKon, OpenAstroTech y Stellarium aportan soluciones distintas; tu aporte es integrarlas para este contexto. | “PiKon aporta fabricación accesible, OpenAstroTech trabaja el seguimiento y Stellarium permite explorar el cielo. AstroPilot se enfoca en el control móvil específico de AstroPrinted y el apoyo educativo.” |
| 10. La propuesta | Flutter/Dart, BLE y cálculo local. | “La aplicación reúne el catálogo, el cálculo y los controles en el teléfono. La versión trabajada es Android; estamos preparando y verificando su ejecución en iPhone.” |
| 11. Funcionamiento | Lugar y hora + catálogo → Alt/Az → comando BLE → ESP32 → motores. | “La app calcula la altura y dirección del objeto, transmite esas coordenadas y el ESP32 acciona los motores. Las respuestas permiten supervisar la comunicación y la ejecución.” |
| 12. Experiencia de uso | Alinear establece la referencia; GoTo necesita esa referencia. | “Primero conectamos. Después centramos una estrella conocida y sincronizamos la posición lógica. Luego seleccionamos otro objeto para apuntar y consultamos su información.” |
| 13. Aprendizaje | Contenido implementado no equivale a impacto pedagógico demostrado. | “Además del control, hay fichas y cuestionarios offline. Su efecto en el aprendizaje todavía requiere evaluación con docentes y estudiantes.” |
| 14. Desarrollo | Explica la progresión de las 16 semanas declaradas en la presentación. | “Trabajé mediante prototipos: primero comunicación, luego catálogo y cálculo, después alineación y finalmente integración de controles y documentación.” |
| 15. Resultados | Los números comparan coordenadas del software; no miden dónde terminó mirando el telescopio. | “Se compararon 500 posiciones con referencias generadas mediante Astropy. El promedio de diferencia angular fue aproximadamente 0,219° y el máximo 0,644°. Esto evalúa el cálculo; la precisión física del telescopio debe medirse aparte.” |
| 16. Alcance y siguientes pasos | Presenta un prototipo con módulos implementados y validación física pendiente. | “Queda una base de software integrada. El siguiente paso es medir el apuntado con el montaje real, ajustar la mecánica y ampliar las pruebas de comunicación y uso educativo.” |
| 17. Soberanía del cielo chileno | Autonomía para construir, adaptar, comprender y enseñar tecnología localmente. | “Aquí soberanía significa desarrollar capacidades propias para observar y enseñar: un instrumento replicable, software local y conocimiento que el equipo puede seguir mejorando. Muchas gracias.” |

## Cinco conceptos que te conviene poder explicar

- **Altitud:** ángulo hacia arriba desde el horizonte. **Azimut:** dirección
  horizontal, medida desde el norte hacia el este.
- **Efemérides:** cálculo de la posición de un objeto para un lugar y un instante.
  No basta con saber el nombre de la estrella; también importan ubicación y hora.
- **Alineación:** centrar una referencia conocida y decir al sistema “esta posición
  de los motores corresponde a esta orientación del cielo”. No hace que un
  trípode desnivelado o una transmisión mal ajustada se corrijan automáticamente.
- **GoTo:** mover hacia la posición calculada. **Seguimiento:** actualizar esa
  posición con el tiempo. El prototipo envía actualizaciones periódicas; no debes
  presentarlo como seguimiento óptico continuo de precisión ya demostrado.
- **BLE/GATT:** comunicación inalámbrica con un servicio y características de
  escritura/notificación. **PONG confirma comunicación**, no demuestra por sí solo
  que un motor haya terminado o que el objeto esté centrado.

## Frases del material original que conviene matizar al hablar

- “Cualquier smartphone”: di “teléfonos compatibles”; iOS aún requiere prueba en
  el equipo disponible mañana. No digas que ya está validado en iPhone.
- “Motores de precisión” y “completamente funcional”: explica que son componentes
  del prototipo y que el desempeño óptico final está pendiente de medición.
- “Base de datos interna”: el catálogo está en archivos JSON locales; no hay un
  servidor ni una base de datos relacional.
- “Enlace seguro/estable”: describe las medidas y las pruebas realizadas; evita
  prometer ausencia de desconexiones o cifrado/autenticación que no se ha validado.
- “Altísima precisión”: usa los valores medidos y su alcance. El umbral 0,75°
  pertenece al resultado presentado; las aserciones del test automatizado actual
  distinguen objetos sobre 5° (<0,5°) y el conjunto completo (<1,5°).
- El generador Astropy del repositorio no activa refracción atmosférica y la app
  sí: las diferencias comparadas incluyen esa diferencia de configuración. No
  interpretes el promedio como error óptico certificado.
- $1.419.648 CLP es el costo referencial de las alternativas revisadas en tu
  trabajo, no una cotización de hoy ni el costo final de AstroPrinted.
- El guion largo menciona motores JGY370 en un apoyo: no memorices ese modelo para
  esta demostración. La referencia de software actual es 28BYJ-48/ULN2003, pendiente
  de confirmar con Ignacio en el montaje físico.

## Respuestas breves a preguntas probables

**¿Ya apunta con precisión a las estrellas?**
“El cálculo está contrastado con referencias. Estamos verificando la integración
física; para afirmar una precisión de apuntado debemos medir la desviación en el
telescopio ensamblado.”

**¿Por qué no basta con Stellarium?**
“Es un referente útil. Mi aporte es una interfaz móvil adaptada al protocolo y
al flujo educativo de AstroPrinted; no pretendo reemplazar todas sus funciones.”

**¿Qué pasa sin Internet?**
“El catálogo, los cálculos y los contenidos principales son locales. La conexión
con el telescopio es Bluetooth. Si no hay GPS, se ingresan coordenadas manuales.”

**¿Qué aporta usar varias estrellas?**
“La versión actual promedia correcciones de coordenadas. Un modelo geométrico que
compense desnivel y errores de los ejes requiere un desarrollo y validación posteriores.”

**¿Por qué una demostración diurna no encuentra estrellas?**
“Hoy podemos verificar instalación, conexión, motores y operación del software.
La prueba de centrar estrellas y medir GoTo se programa con oscuridad y cielo disponible.”

## Ensayo de esta noche y mañana

1. Dedica unos 20 minutos a leer esta guía con la v9 abierta. En cada diapositiva,
   tapa el texto y explica su idea central en una o dos frases.
2. Haz un ensayo de 12–15 minutos en voz alta. Si te trabas, continúa; anota solo
   los tres puntos que necesites repasar. No reinicies toda la exposición.
3. Dedica 10 minutos a esos puntos, especialmente diapositivas 11, 12, 15 y 16.
4. Ensaya la apertura y el cierre una vez más y deja los archivos y cables listos.
   Reserva el resto de la noche para descansar.
5. Mañana, si te acomoda, haz un repaso de 15 minutos alrededor de las 08:30 y
   revisa los archivos antes de las 09:15. Planifica la salida a las 09:30, con
   margen respecto de la presentación de las 11:00.

Si te quedas en blanco: “La idea principal de esta diapositiva es…” y vuelve a
explicar el problema o el resultado. Puedes mirar tus notas; no es una prueba de memoria literal.
