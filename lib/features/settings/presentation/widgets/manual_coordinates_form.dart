import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/observer_state.dart';
import '../../domain/settings_defaults.dart';

class ManualCoordinatesForm extends StatefulWidget {
  final ObserverState state;
  final ValueChanged<ManualCoordinatesInput> onSave;

  const ManualCoordinatesForm({
    super.key,
    required this.state,
    required this.onSave,
  });

  @override
  State<ManualCoordinatesForm> createState() => _ManualCoordinatesFormState();
}

class _ManualCoordinatesFormState extends State<ManualCoordinatesForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _latController;
  late final TextEditingController _lonController;
  late final TextEditingController _heightController;
  bool _isValid = true;

  bool get _enabled =>
      !widget.state.isAutoMode && !widget.state.isLoadingLocation;

  @override
  void initState() {
    super.initState();
    _latController = TextEditingController(
      text: _formatCoordinate(widget.state.latDeg),
    );
    _lonController = TextEditingController(
      text: _formatCoordinate(widget.state.lonDeg),
    );
    _heightController = TextEditingController(
      text: widget.state.heightMeters.toStringAsFixed(0),
    );
  }

  @override
  void didUpdateWidget(covariant ManualCoordinatesForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.latDeg != widget.state.latDeg) {
      _latController.text = _formatCoordinate(widget.state.latDeg);
    }
    if (oldWidget.state.lonDeg != widget.state.lonDeg) {
      _lonController.text = _formatCoordinate(widget.state.lonDeg);
    }
    if (oldWidget.state.heightMeters != widget.state.heightMeters) {
      _heightController.text = widget.state.heightMeters.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      onChanged: _validateSilently,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rango permitido: Lat ${SettingsDefaults.chileLatMin.toStringAsFixed(0)} a ${SettingsDefaults.chileLatMax.toStringAsFixed(0)}, Lon ${SettingsDefaults.chileLonMin.toStringAsFixed(0)} a ${SettingsDefaults.chileLonMax.toStringAsFixed(0)}.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  controller: _latController,
                  enabled: _enabled,
                  label: 'Latitud',
                  suffix: 'deg',
                  validator: _validateLatitude,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NumberField(
                  controller: _lonController,
                  enabled: _enabled,
                  label: 'Longitud',
                  suffix: 'deg',
                  validator: _validateLongitude,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _NumberField(
            controller: _heightController,
            enabled: _enabled,
            label: 'Altura',
            suffix: 'm',
            validator: _validateHeight,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _enabled && _isValid ? _submit : null,
            icon: const Icon(Icons.save_rounded),
            label: const Text('Guardar ubicación manual'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }

  void _validateSilently() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (valid != _isValid) {
      setState(() => _isValid = valid);
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onSave(
      ManualCoordinatesInput(
        latDeg: double.parse(_latController.text.trim()),
        lonDeg: double.parse(_lonController.text.trim()),
        heightMeters: double.parse(_heightController.text.trim()),
      ),
    );
  }

  String? _validateLatitude(String? value) {
    final number = double.tryParse(value?.trim() ?? '');
    if (number == null) return 'Ingresa un número válido';
    if (number < SettingsDefaults.chileLatMin ||
        number > SettingsDefaults.chileLatMax) {
      return 'Ubicación fuera del territorio nacional (Chile)';
    }
    return null;
  }

  String? _validateLongitude(String? value) {
    final number = double.tryParse(value?.trim() ?? '');
    if (number == null) return 'Ingresa un número válido';
    if (number < SettingsDefaults.chileLonMin ||
        number > SettingsDefaults.chileLonMax) {
      return 'Ubicación fuera del territorio nacional (Chile)';
    }
    return null;
  }

  String? _validateHeight(String? value) {
    final number = double.tryParse(value?.trim() ?? '');
    if (number == null) return 'Ingresa un número válido';
    if (number < 0) return 'La altura debe ser un valor positivo';
    return null;
  }

  static String _formatCoordinate(double value) {
    return value
        .toStringAsFixed(5)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

class ManualCoordinatesInput {
  final double latDeg;
  final double lonDeg;
  final double heightMeters;

  const ManualCoordinatesInput({
    required this.latDeg,
    required this.lonDeg,
    required this.heightMeters,
  });
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final String label;
  final String suffix;
  final String? Function(String?) validator;

  const _NumberField({
    required this.controller,
    required this.enabled,
    required this.label,
    required this.suffix,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      validator: validator,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
