import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/calibration_controller.dart';

class CalibrationControls extends StatelessWidget {
  final bool enabled;
  final Future<void> Function(CalibrationNudgeDirection direction) onNudge;

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

class _NudgeButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final Future<void> Function() onPressed;

  const _NudgeButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  @override
  State<_NudgeButton> createState() => _NudgeButtonState();
}

class _NudgeButtonState extends State<_NudgeButton> {
  static const Duration _initialRepeatDelay = Duration(milliseconds: 350);
  static const Duration _repeatInterval = Duration(milliseconds: 220);

  Timer? _initialRepeatTimer;
  Timer? _repeatTimer;
  bool _isPressed = false;
  bool _isInvoking = false;

  @override
  void didUpdateWidget(covariant _NudgeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _stopPress();
  }

  @override
  void dispose() {
    _stopPress();
    super.dispose();
  }

  void _startPress() {
    if (!widget.enabled || _isPressed) return;

    _isPressed = true;
    unawaited(_invoke());

    _initialRepeatTimer = Timer(_initialRepeatDelay, () {
      if (!_isPressed || !mounted) return;
      _repeatTimer = Timer.periodic(_repeatInterval, (_) {
        unawaited(_invoke());
      });
    });
  }

  void _stopPress() {
    _isPressed = false;
    _initialRepeatTimer?.cancel();
    _repeatTimer?.cancel();
    _initialRepeatTimer = null;
    _repeatTimer = null;
  }

  Future<void> _invoke() async {
    if (!widget.enabled || _isInvoking) return;

    _isInvoking = true;
    try {
      await widget.onPressed();
    } finally {
      _isInvoking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.label,
      onTap: widget.enabled ? () => unawaited(_invoke()) : null,
      child: Listener(
        onPointerDown: widget.enabled ? (_) => _startPress() : null,
        onPointerUp: (_) => _stopPress(),
        onPointerCancel: (_) => _stopPress(),
        child: ExcludeSemantics(
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.enabled ? () {} : null,
              icon: Icon(widget.icon),
              label: Text(widget.label),
            ),
          ),
        ),
      ),
    );
  }
}
