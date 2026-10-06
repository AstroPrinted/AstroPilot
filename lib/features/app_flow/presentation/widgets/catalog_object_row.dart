import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/time_format.dart';
import '../../../../core/widgets/ap_widgets.dart';
import '../../../catalog/domain/models/visible_celestial_object.dart';
import 'object_display.dart';
import 'object_image.dart';

/// Fila de objeto del catálogo con su badge de visibilidad.
class CatalogObjectRow extends StatelessWidget {
  final VisibleCelestialObject item;
  final VoidCallback onTap;

  const CatalogObjectRow({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final object = item.object;
    final sun = ObjectDisplay.isSun(object);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            ObjectThumbnail(object),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    object.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: ApColors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ObjectDisplay.subtitle(object),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ApText.small.copyWith(fontSize: 12.5),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (!sun) visibilityBadge(item),
                      if (sun)
                        const ApBadge(
                          label: 'observación solar bloqueada',
                          icon: Icons.block,
                          color: ApColors.error,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: ApColors.muted, size: 22),
          ],
        ),
      ),
    );
  }

  static Widget visibilityBadge(VisibleCelestialObject item) {
    final alt = item.position?.altitudeDeg;
    if (alt == null) {
      return const ApBadge(
        label: 'Posición no disponible',
        icon: Icons.visibility_off,
        color: ApColors.muted,
      );
    }
    final value = '${alt.toStringAsFixed(1)}°';
    if (!item.isVisible) {
      return ApBadge(
        label: 'Bajo el horizonte · $value',
        icon: Icons.visibility_off,
        color: ApColors.muted,
      );
    }
    if (item.isNearSun) {
      return const ApBadge(
        label: 'Cerca del Sol · GOTO bloqueado',
        icon: Icons.block,
        color: ApColors.error,
      );
    }
    if (item.isNearHorizon) {
      return ApBadge(
        label: 'Cerca del horizonte · $value',
        icon: Icons.warning,
        color: ApColors.warn,
      );
    }
    return ApBadge(
      label: 'Visible · $value',
      icon: Icons.visibility,
      color: ApColors.secondary,
    );
  }
}

/// Chips de categoría (`.ap-chips`).
class CategoryChips extends StatelessWidget {
  final CatalogCategory selected;
  final ValueChanged<CatalogCategory> onSelected;

  const CategoryChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final category in CatalogCategory.values)
          FilterChip(
            label: Text(category.label),
            selected: category == selected,
            showCheckmark: true,
            onSelected: (_) => onSelected(category),
          ),
      ],
    );
  }
}

/// "Ubicación / Hora local" del cálculo de visibilidad.
String visibilityContext(double lat, double lon, DateTime time) {
  return 'Ubicación   ${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}\n'
      'Hora local  ${formatLocalDateTime(time)}';
}
