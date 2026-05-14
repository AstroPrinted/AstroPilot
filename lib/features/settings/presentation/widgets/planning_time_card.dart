import 'package:flutter/material.dart';

import '../../domain/models/observer_state.dart';
import '../../domain/settings_defaults.dart';

class PlanningTimeCard extends StatelessWidget {
  final ObserverState state;
  final ValueChanged<bool> onUseCurrentTimeChanged;
  final ValueChanged<DateTime> onCustomTimeSelected;

  const PlanningTimeCard({
    super.key,
    required this.state,
    required this.onUseCurrentTimeChanged,
    required this.onCustomTimeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final localTime = state.effectiveUtc.toLocal();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Usar hora actual'),
          subtitle: Text(
            state.isCustomTime
                ? 'Desactivado: Planning Mode activo'
                : 'Alt/Az se recalcula con el reloj del dispositivo',
          ),
          value: !state.isCustomTime,
          onChanged: onUseCurrentTimeChanged,
        ),
        const SizedBox(height: 8),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: state.isCustomTime ? 1 : 0.64,
          child: OutlinedButton.icon(
            onPressed: () => _selectDateTime(context, localTime),
            icon: const Icon(Icons.event_rounded),
            label: Text(
              state.isCustomTime
                  ? 'Planificando: ${_formatDateTime(localTime)}'
                  : 'Elegir fecha/hora de planificación',
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'UTC efectivo: ${state.effectiveUtc.toIso8601String()}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
        ),
      ],
    );
  }

  Future<void> _selectDateTime(BuildContext context, DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(SettingsDefaults.minPlanningDate)
          ? DateTime.now()
          : initial,
      firstDate: SettingsDefaults.minPlanningDate,
      lastDate: SettingsDefaults.maxPlanningDate,
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;

    onCustomTimeSelected(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  static String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }
}
