import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/settings_service.dart';
import '../../domain/models/observer_state.dart';
import '../widgets/location_status_chip.dart';
import '../widgets/manual_coordinates_form.dart';
import '../widgets/planning_time_card.dart';
import '../widgets/settings_section_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final state = settings.state;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsSectionCard(
            title: 'Observador',
            icon: Icons.my_location_rounded,
            accent: colorScheme.secondary,
            children: [
              Row(
                children: [
                  LocationStatusChip(state: state),
                  const Spacer(),
                  Text(
                    '${state.latDeg.toStringAsFixed(4)}, ${state.lonDeg.toStringAsFixed(4)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                  ),
                ],
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 12),
                _InlineError(message: state.errorMessage!),
              ],
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ubicación automática GPS'),
                subtitle: const Text('Lectura única para ahorrar batería'),
                value: state.isAutoMode,
                onChanged: state.isLoadingLocation
                    ? null
                    : (enabled) => _toggleAutoMode(context, settings, enabled),
              ),
              const SizedBox(height: 8),
              ManualCoordinatesForm(
                state: state,
                onSave: (input) =>
                    _saveManualCoordinates(context, settings, input),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SettingsSectionCard(
            title: 'Planning Mode',
            icon: Icons.nights_stay_rounded,
            accent: colorScheme.primary,
            children: [
              PlanningTimeCard(
                state: state,
                onUseCurrentTimeChanged: (useCurrent) => useCurrent
                    ? _resetTime(context, settings)
                    : _selectPlanningTime(
                        context,
                        settings,
                        state.effectiveUtc.toLocal(),
                      ),
                onCustomTimeSelected: (dateTime) =>
                    _setPlanningTime(context, settings, dateTime),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAutoMode(
    BuildContext context,
    SettingsService settings,
    bool enabled,
  ) async {
    await settings.toggleAutoMode(enabled);
    if (!context.mounted) return;
    final state = settings.state;
    if (state.errorMessage != null) {
      _showSnackBar(context, state.errorMessage!);
    }
    if (state.status == LocationStatus.permissionDenied &&
        state.errorMessage?.contains('permanentemente') == true) {
      await _showPermissionDialog(context, settings);
    }
  }

  Future<void> _saveManualCoordinates(
    BuildContext context,
    SettingsService settings,
    ManualCoordinatesInput input,
  ) async {
    await settings.setManualCoordinates(
      input.latDeg,
      input.lonDeg,
      input.heightMeters,
    );
    if (!context.mounted) return;
    _showSnackBar(
      context,
      settings.state.errorMessage ?? 'Ubicación manual guardada.',
    );
  }

  Future<void> _resetTime(
    BuildContext context,
    SettingsService settings,
  ) async {
    await settings.resetToCurrentTime();
    if (context.mounted) _showSnackBar(context, 'Usando hora actual.');
  }

  Future<void> _setPlanningTime(
    BuildContext context,
    SettingsService settings,
    DateTime dateTime,
  ) async {
    await settings.setCustomTime(dateTime);
    if (context.mounted) _showSnackBar(context, 'Planning Mode actualizado.');
  }

  Future<void> _selectPlanningTime(
    BuildContext context,
    SettingsService settings,
    DateTime initial,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !context.mounted) return;
    await _setPlanningTime(
      context,
      settings,
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  Future<void> _showPermissionDialog(
    BuildContext context,
    SettingsService settings,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permiso de ubicación'),
        content: const Text(
          'AstroPilot necesita ubicación para calcular coordenadas Alt/Az desde tu posición real. Puedes seguir usando coordenadas manuales.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await settings.openSystemSettings();
            },
            child: const Text('Abrir configuración'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _InlineError extends StatelessWidget {
  final String message;

  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.34)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
