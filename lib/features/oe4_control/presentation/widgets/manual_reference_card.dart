import 'package:flutter/material.dart';

/// Coordinates assigned to the existing physical orientation, without motion.
class ManualReferenceCard extends StatefulWidget {
  final bool enabled;
  final Future<void> Function(double altitude, double azimuth) onSetReference;

  const ManualReferenceCard({
    super.key,
    required this.enabled,
    required this.onSetReference,
  });

  @override
  State<ManualReferenceCard> createState() => _ManualReferenceCardState();
}

class _ManualReferenceCardState extends State<ManualReferenceCard> {
  final _formKey = GlobalKey<FormState>();
  final _altitude = TextEditingController(text: '0');
  final _azimuth = TextEditingController(text: '0');
  bool _saving = false;
  String? _message;
  bool _failed = false;

  @override
  void dispose() {
    _altitude.dispose();
    _azimuth.dispose();
    super.dispose();
  }

  double? _parse(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  String? _validate(String? value, double min, double max) {
    final number = _parse(value ?? '');
    if (number == null || !number.isFinite) return 'Ingresa un número válido';
    if (number < min || number > max) return 'Rango: $min a $max°';
    return null;
  }

  Future<void> _save() async {
    if (!widget.enabled || _saving || !_formKey.currentState!.validate()) {
      return;
    }
    final alt = _parse(_altitude.text)!;
    final az = _parse(_azimuth.text)!;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await widget.onSetReference(alt, az);
      if (!mounted) return;
      setState(() {
        _failed = false;
        _message =
            'Referencia confirmada: altitud $alt°, azimut ${az == 360 ? 0 : az}°. '
            'Para apuntar a objetos, realiza la alineación con una estrella.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _message = error is StateError ? error.message : error.toString();
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !_saving;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Calibrar posición actual',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              const Text(
                'Coloca el telescopio en una orientación conocida usando el control manual. '
                'Luego asigna aquí sus coordenadas reales. Si el firmware todavía '
                'mantiene un movimiento activo, la app envía STOP antes de fijar '
                'la referencia.',
              ),
              const SizedBox(height: 8),
              const Text(
                'Altitud 0° = horizontal; 90° = hacia arriba. Azimut 0° = norte. '
                'Si queda horizontal al indicar −3°, fija esa posición como altitud 0°. '
                'Introduce también el azimut real.',
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _altitude,
                enabled: enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Altitud real (°)',
                  helperText: '−90 a 90°',
                ),
                validator: (value) => _validate(value, -90, 90),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _azimuth,
                enabled: enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Azimut real (°)',
                  helperText: '0 a 360°; −3° equivale a 357°',
                ),
                validator: (value) => _validate(value, 0, 360),
              ),
              const SizedBox(height: 12),
              const Text(
                'Reemplaza la referencia anterior y sus correcciones. '
                'Repite este ajuste si reinicias el ESP32 o se pierde la posición física.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: enabled ? _save : null,
                icon: const Icon(Icons.my_location_rounded),
                label: Text(
                  _saving
                      ? 'Esperando confirmación…'
                      : 'Fijar coordenadas actuales',
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(
                  _message!,
                  style: TextStyle(
                    color: _failed ? Theme.of(context).colorScheme.error : null,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
