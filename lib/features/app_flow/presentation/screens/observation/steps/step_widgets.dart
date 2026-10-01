import 'package:flutter/material.dart';

import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/widgets/ap_widgets.dart';
import '../../../../../calibration/presentation/controllers/calibration_controller.dart';
import '../../../../../oe4_control/domain/telescope_position.dart';
import '../../../widgets/telescope_commands.dart';

/// Lista numerada (`.ap-steps`).
class NumberedSteps extends StatelessWidget {
  final List<String> items;
  const NumberedSteps({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: apSpaced([
        for (var i = 0; i < items.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: ApColors.secondary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ApColors.background,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  items[i],
                  style: const TextStyle(
                    fontSize: 13,
                    height: 19 / 13,
                    color: ApColors.text,
                  ),
                ),
              ),
            ],
          ),
      ], gap: 10),
    );
  }
}

/// Posición del telescopio (y objetivo, si hay) en tiles.
class PositionTiles extends StatelessWidget {
  final MotorAngles? position;
  final double? targetAltitude;
  final double? targetAzimuth;

  const PositionTiles({
    super.key,
    required this.position,
    this.targetAltitude,
    this.targetAzimuth,
  });

  @override
  Widget build(BuildContext context) {
    return ApTiles(
      tiles: [
        ApTile(
          label: 'Posición altitud',
          value: formatDeg(position?.altitude),
        ),
        ApTile(label: 'Posición azimut', value: formatDeg(position?.azimuth)),
        if (targetAltitude != null)
          ApTile(label: 'Objetivo altitud', value: formatDeg(targetAltitude)),
        if (targetAzimuth != null)
          ApTile(label: 'Objetivo azimut', value: formatDeg(targetAzimuth)),
      ],
    );
  }
}

/// Flechas de centrado para la alineación y el ajuste fino.
class CalibrationJoystick extends StatelessWidget {
  final CalibrationController calibration;
  final TelescopeCommands commands;
  final bool enabled;

  const CalibrationJoystick({
    super.key,
    required this.calibration,
    required this.commands,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    Future<void> Function()? move(CalibrationNudgeDirection direction) =>
        enabled ? () => calibration.nudge(direction, commands.moveBy) : null;
    final step = CalibrationController.fineStepDegrees.toStringAsFixed(2);
    return ApJoystick(
      onUp: move(CalibrationNudgeDirection.up),
      onDown: move(CalibrationNudgeDirection.down),
      onLeft: move(CalibrationNudgeDirection.left),
      onRight: move(CalibrationNudgeDirection.right),
      caption: 'Cada toque mueve $step°. Mantén presionado para repetir.',
    );
  }
}

/// "Movimiento directo": lleva el telescopio a una posición absoluta.
class DirectMoveCard extends StatefulWidget {
  final MotorAngles? position;
  final bool enabled;
  final Future<void> Function(double altitude, double azimuth) onMove;

  const DirectMoveCard({
    super.key,
    required this.position,
    required this.onMove,
    this.enabled = true,
  });

  @override
  State<DirectMoveCard> createState() => _DirectMoveCardState();
}

class _DirectMoveCardState extends State<DirectMoveCard> {
  late final TextEditingController _alt;
  late final TextEditingController _az;
  String? _error;

  @override
  void initState() {
    super.initState();
    _alt = TextEditingController(
      text: widget.position?.altitude.toStringAsFixed(2) ?? '',
    );
    _az = TextEditingController(
      text: widget.position?.azimuth.toStringAsFixed(2) ?? '',
    );
  }

  @override
  void dispose() {
    _alt.dispose();
    _az.dispose();
    super.dispose();
  }

  void _submit() {
    final alt = parseApNumber(_alt.text);
    final az = parseApNumber(_az.text);
    if (alt == null || az == null) {
      setState(() => _error = 'Ingresa valores numéricos válidos.');
      return;
    }
    setState(() => _error = null);
    widget.onMove(alt, az);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ApColors.surface2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: apSpaced([
          const Text('Movimiento directo', style: ApText.strong),
          Row(
            children: [
              Expanded(
                child: ApNumberField(controller: _alt, label: 'Altitud (°)'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ApNumberField(controller: _az, label: 'Azimut (°)'),
              ),
            ],
          ),
          Text(_error ?? 'Posición absoluta del telescopio.',
              style: _error == null
                  ? ApText.small
                  : ApText.small.copyWith(color: ApColors.error)),
          ApButton(
            label: 'Mover',
            icon: Icons.open_with,
            kind: ApButtonKind.outlined,
            onPressed: widget.enabled ? _submit : null,
          ),
        ], gap: 10),
      ),
    );
  }
}

/// Aviso con el mensaje de error del controlador.
class ErrorNotice extends StatelessWidget {
  final String message;
  const ErrorNotice(this.message, {super.key});

  @override
  Widget build(BuildContext context) =>
      ApNotice(icon: Icons.error_outline, tone: ApTone.error, text: message);
}
