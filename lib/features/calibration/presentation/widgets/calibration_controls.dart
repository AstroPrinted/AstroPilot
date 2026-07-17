import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/calibration_controller.dart';

class CalibrationControls extends StatelessWidget {
  final bool enabled;
  final double? adjustedAltitude;
  final double? adjustedAzimuth;
  final Future<void> Function(CalibrationNudgeDirection direction) onNudge;
  final Future<void> Function(double altitude, double azimuth)
  onMoveToAdjustment;

  const CalibrationControls({
    super.key,
    required this.enabled,
    required this.adjustedAltitude,
    required this.adjustedAzimuth,
    required this.onNudge,
    required this.onMoveToAdjustment,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ManualAdjustmentForm(
          enabled: enabled,
          adjustedAltitude: adjustedAltitude,
          adjustedAzimuth: adjustedAzimuth,
          onMoveToAdjustment: onMoveToAdjustment,
        ),
        const SizedBox(height: 12),
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

class _ManualAdjustmentForm extends StatefulWidget {
  final bool enabled;
  final double? adjustedAltitude;
  final double? adjustedAzimuth;
  final Future<void> Function(double altitude, double azimuth)
  onMoveToAdjustment;

  const _ManualAdjustmentForm({
    required this.enabled,
    required this.adjustedAltitude,
    required this.adjustedAzimuth,
    required this.onMoveToAdjustment,
  });

  @override
  State<_ManualAdjustmentForm> createState() => _ManualAdjustmentFormState();
}

class _ManualAdjustmentFormState extends State<_ManualAdjustmentForm> {
  final TextEditingController _altitudeController = TextEditingController();
  final TextEditingController _azimuthController = TextEditingController();
  final FocusNode _altitudeFocus = FocusNode();
  final FocusNode _azimuthFocus = FocusNode();

  double? _lastSyncedAltitude;
  double? _lastSyncedAzimuth;
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _syncControllers(force: true);
  }

  @override
  void didUpdateWidget(covariant _ManualAdjustmentForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllers();
    if (!widget.enabled && oldWidget.enabled) {
      _errorText = null;
    }
  }

  @override
  void dispose() {
    _altitudeController.dispose();
    _azimuthController.dispose();
    _altitudeFocus.dispose();
    _azimuthFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!widget.enabled || _isSubmitting) return;

    final altitude = _parseDegrees(_altitudeController.text);
    final azimuth = _parseDegrees(_azimuthController.text);

    if (altitude == null || azimuth == null) {
      setState(() => _errorText = 'Ingresa valores numéricos.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await widget.onMoveToAdjustment(altitude, azimuth);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _syncControllers({bool force = false}) {
    final altitudeChanged =
        force || widget.adjustedAltitude != _lastSyncedAltitude;
    final azimuthChanged =
        force || widget.adjustedAzimuth != _lastSyncedAzimuth;

    if (altitudeChanged && (force || !_altitudeFocus.hasFocus)) {
      _setControllerText(
        _altitudeController,
        _formatInput(widget.adjustedAltitude),
      );
      _lastSyncedAltitude = widget.adjustedAltitude;
    }
    if (azimuthChanged && (force || !_azimuthFocus.hasFocus)) {
      _setControllerText(
        _azimuthController,
        _formatInput(widget.adjustedAzimuth),
      );
      _lastSyncedAzimuth = widget.adjustedAzimuth;
    }
  }

  void _setControllerText(TextEditingController controller, String text) {
    if (controller.text == text) return;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  double? _parseDegrees(String rawValue) {
    final normalized = rawValue.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    final parsed = double.tryParse(normalized);
    if (parsed == null || !parsed.isFinite) return null;
    return parsed;
  }

  String _formatInput(double? value) => (value ?? 0.0).toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final inputFormatters = [
      FilteringTextInputFormatter.allow(RegExp(r'[-+0-9.,]')),
    ];
    final inputEnabled = widget.enabled && !_isSubmitting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Movimiento directo',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                enabled: inputEnabled,
                controller: _altitudeController,
                focusNode: _altitudeFocus,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                textInputAction: TextInputAction.next,
                inputFormatters: inputFormatters,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Altitud',
                  suffixText: 'deg',
                ),
                onSubmitted: (_) => _azimuthFocus.requestFocus(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                enabled: inputEnabled,
                controller: _azimuthController,
                focusNode: _azimuthFocus,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                textInputAction: TextInputAction.done,
                inputFormatters: inputFormatters,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Azimut',
                  suffixText: 'deg',
                ),
                onSubmitted: (_) => unawaited(_submit()),
              ),
            ),
          ],
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            _errorText!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: inputEnabled ? () => unawaited(_submit()) : null,
          icon: const Icon(Icons.near_me_rounded),
          label: const Text('Mover'),
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
  static const Duration _repeatInterval = Duration(milliseconds: 250);

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
