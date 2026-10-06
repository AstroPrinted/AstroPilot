import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ap_widgets.dart';
import '../widgets/mode_scaffold.dart';
import '../widgets/telescope_icon.dart';

/// De dónde viene AstroPilot: el telescopio AstroPrinted y la historia del
/// proyecto.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: ModeAppBar(
        title: 'Sobre el proyecto',
        back: true,
        showConnection: false,
      ),
      body: ModeBody(
        children: [
          Column(
            children: [
              AppLogo(size: 60),
              SizedBox(height: 10),
              Text(
                'AstroPilot',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: ApColors.text,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'La aplicación del telescopio AstroPrinted',
                style: ApText.small,
              ),
            ],
          ),
          ApCard(
            children: [
              ApCardHead(icon: Icons.public, title: 'El punto de partida'),
              Text(
                'Chile concentra más del 40 % de la capacidad de observación '
                'astronómica del mundo, según un informe de 2025 de la '
                'Biblioteca del Congreso Nacional. Pero tener grandes '
                'observatorios no significa que cada estudiante pueda mirar '
                'el cielo.',
                style: ApText.body,
              ),
              Text(
                'Hay dos barreras: lo que cuesta un telescopio y lo difícil '
                'que es aprender a usarlo.',
                style: ApText.body,
              ),
            ],
          ),
          ApCard(
            children: [
              ApCardHead(
                icon: Icons.view_in_ar,
                title: 'AstroPrinted: el telescopio',
              ),
              Text(
                'AstroPrinted es un telescopio educativo pensado para que '
                'otros puedan construirlo: su estructura se fabrica con '
                'impresión 3D y usa electrónica accesible.',
                style: ApText.body,
              ),
              Text(
                'Es un proyecto interdisciplinario. Un equipo se encarga de '
                'la estructura, la óptica, la electrónica y el montaje.',
                style: ApText.body,
              ),
            ],
          ),
          ApCard(
            children: [
              ApCardHead(
                icon: Icons.smartphone,
                title: 'AstroPilot: la aplicación',
              ),
              Text(
                'AstroPilot nace como la pieza que faltaba: una forma de '
                'manejar el telescopio desde el teléfono, sin escribir '
                'comandos a mano.',
                style: ApText.body,
              ),
              _Flow(
                steps: [
                  'Toma tu ubicación, la hora y el catálogo de objetos.',
                  'Calcula a qué altura y en qué dirección está cada objeto.',
                  'Envía esas coordenadas al telescopio por Bluetooth.',
                  'El telescopio mueve sus motores hasta apuntar.',
                ],
              ),
              Text(
                'Además del control, incluye fichas de los objetos, la '
                'sección de satélites y un quiz, todo sin internet.',
                style: ApText.body,
              ),
            ],
          ),
          ApCard(
            children: [
              ApCardHead(icon: Icons.timeline, title: 'Cómo se construyó'),
              Text(
                'Se desarrolló por prototipos: primero la comunicación con '
                'el telescopio, después el catálogo y el cálculo de '
                'posiciones, luego la alineación y, al final, la integración '
                'de los controles y del contenido educativo.',
                style: ApText.body,
              ),
              Text(
                'Para comprobar el cálculo se compararon 500 posiciones con '
                'referencias generadas con Astropy: la diferencia promedio '
                'fue de unos 0,22° y la máxima de 0,64°.',
                style: ApText.body,
              ),
            ],
          ),
          ApCard(
            children: [
              ApCardHead(icon: Icons.flag, title: 'Lo que viene'),
              Text(
                'El siguiente paso es medir el apuntado con el telescopio '
                'real, ajustar la mecánica y probar la aplicación con '
                'docentes y estudiantes.',
                style: ApText.body,
              ),
              Text(
                'La idea de fondo es la soberanía del cielo chileno: contar '
                'con un instrumento que se puede replicar, software propio y '
                'conocimiento que el equipo puede seguir mejorando.',
                style: ApText.body,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pasos numerados de cómo la app llega del catálogo a los motores.
class _Flow extends StatelessWidget {
  final List<String> steps;

  const _Flow({required this.steps});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: apSpaced([
        for (var i = 0; i < steps.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ApColors.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ApColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(steps[i], style: ApText.body)),
            ],
          ),
      ], gap: 8),
    );
  }
}
