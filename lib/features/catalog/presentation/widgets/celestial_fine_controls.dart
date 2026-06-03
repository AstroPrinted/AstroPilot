import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/celestial_control_controller.dart';

class CelestialFineControls extends StatelessWidget {
  final bool enabled;
  final Future<void> Function(CelestialFineDirection direction) onNudge;

  const CelestialFineControls({
    super.key,
    required this.enabled,
    required this.onNudge,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FineButton(
          label: 'Arriba',
          icon: Icons.keyboard_arrow_up_rounded,
          enabled: enabled,
          onPressed: () => onNudge(CelestialFineDirection.up),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _FineButton(
                label: 'Izquierda',
                icon: Icons.keyboard_arrow_left_rounded,
                enabled: enabled,
                onPressed: () => onNudge(CelestialFineDirection.left),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _FineButton(
                label: 'Derecha',
                icon: Icons.keyboard_arrow_right_rounded,
                enabled: enabled,
                onPressed: () => onNudge(CelestialFineDirection.right),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _FineButton(
          label: 'Abajo',
          icon: Icons.keyboard_arrow_down_rounded,
          enabled: enabled,
          onPressed: () => onNudge(CelestialFineDirection.down),
        ),
      ],
    );
  }
}

class _FineButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final Future<void> Function() onPressed;

  const _FineButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  @override
  State<_FineButton> createState() => _FineButtonState();
}

class _FineButtonState extends State<_FineButton> {
  static const Duration _repeatInterval = Duration(milliseconds: 250);

  Timer? _repeatTimer;
  bool _isPressed = false;
  bool _isInvoking = false;

  @override
  void didUpdateWidget(covariant _FineButton oldWidget) {
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
    _repeatTimer = Timer.periodic(_repeatInterval, (_) {
      if (!_isPressed || !mounted) return;
      unawaited(_invoke());
    });
  }

  void _stopPress() {
    _isPressed = false;
    _repeatTimer?.cancel();
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
