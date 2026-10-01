import 'package:flutter/material.dart';

import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/widgets/ap_widgets.dart';
import '../../../../../calibration/presentation/controllers/calibration_controller.dart';
import '../../../../../catalog/domain/models/celestial_object.dart';

/// Lista de estrellas de referencia: las visibles se eligen con un radio y
/// las demás aparecen deshabilitadas. El botón envía el GOTO.
class StarPicker extends StatefulWidget {
  final List<CalibrationStarOption> options;
  final String Function(CalibrationStar star)? guideFor;
  final bool busy;
  final String actionLabel;
  final Future<void> Function(CalibrationStarOption option) onGo;

  const StarPicker({
    super.key,
    required this.options,
    required this.busy,
    required this.actionLabel,
    required this.onGo,
    this.guideFor,
  });

  @override
  State<StarPicker> createState() => _StarPickerState();
}

class _StarPickerState extends State<StarPicker> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final visible = widget.options.where((o) => o.isVisible).toList();
    final hidden = widget.options.where((o) => !o.isVisible).toList();
    final selected = visible
        .where((o) => o.star.id == _selectedId && o.isSelectable)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: apSpaced([
        if (visible.isNotEmpty) ...[
          const ApSectionLabel('Recomendadas · visibles ahora'),
          for (final option in visible)
            ApOption(
              selected: option.star.id == _selectedId,
              enabled: option.isSelectable && !widget.busy,
              icon: option.isAlreadySelected ? Icons.check : null,
              onTap: () => setState(() => _selectedId = option.star.id),
              child: _StarLabel(
                option: option,
                tip: option.isAlreadySelected
                    ? null
                    : option.isTooCloseToReference
                    ? 'Muy cerca de una referencia anterior.'
                    : widget.guideFor?.call(option.star),
              ),
            ),
        ],
        if (hidden.isNotEmpty) ...[
          const ApSectionLabel('No visibles'),
          for (final option in hidden)
            ApOption(
              enabled: false,
              child: _StarLabel(option: option),
            ),
        ],
        ApButton(
          label: widget.actionLabel,
          icon: Icons.near_me,
          large: true,
          busy: widget.busy,
          onPressed: selected == null ? null : () => widget.onGo(selected),
        ),
      ], gap: 10),
    );
  }
}

class _StarLabel extends StatelessWidget {
  final CalibrationStarOption option;
  final String? tip;

  const _StarLabel({required this.option, this.tip});

  @override
  Widget build(BuildContext context) {
    final name = option.isAlreadySelected
        ? '${option.star.name} · usada'
        : option.star.name;
    final position = option.position;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: ApColors.text,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Alt ${position.altitudeDeg.toStringAsFixed(1)}° · '
              'Az ${position.azimuthDeg.toStringAsFixed(1)}°',
              style: ApText.small.merge(ApText.number),
            ),
          ],
        ),
        if (tip != null) ...[
          const SizedBox(height: 3),
          Text(tip!, style: ApText.small),
        ],
      ],
    );
  }
}
