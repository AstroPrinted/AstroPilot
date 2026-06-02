import 'package:flutter/material.dart';

import '../controllers/calibration_controller.dart';

class CalibrationControls extends StatelessWidget {
  final bool enabled;
  final ValueChanged<CalibrationNudgeDirection> onNudge;

  const CalibrationControls({
    super.key,
    required this.enabled,
    required this.onNudge,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _NudgeButton(
          label: 'Arriba',
          icon: Icons.keyboard_arrow_up_rounded,
          enabled: enabled,
          onPressed: () => onNudge(CalibrationNudgeDirection.up),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _NudgeButton(
                label: 'Izquierda',
                icon: Icons.keyboard_arrow_left_rounded,
                enabled: enabled,
                onPressed: () => onNudge(CalibrationNudgeDirection.left),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NudgeButton(
                label: 'Derecha',
                icon: Icons.keyboard_arrow_right_rounded,
                enabled: enabled,
                onPressed: () => onNudge(CalibrationNudgeDirection.right),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _NudgeButton(
          label: 'Abajo',
          icon: Icons.keyboard_arrow_down_rounded,
          enabled: enabled,
          onPressed: () => onNudge(CalibrationNudgeDirection.down),
        ),
      ],
    );
  }
}

class _NudgeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  const _NudgeButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
