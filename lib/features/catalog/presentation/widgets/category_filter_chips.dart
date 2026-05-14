import 'package:flutter/material.dart';

class CategoryFilterChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const CategoryFilterChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    const items = <({String id, String label})>[
      (id: 'all', label: 'Todos'),
      (id: 'solar_system', label: 'Sist. Solar'),
      (id: 'deep_sky', label: 'Cielo Prof.'),
      (id: 'stars', label: 'Estrellas'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: selected == item.id,
                onSelected: (_) => onSelected(item.id),
                label: Text(item.label),
              ),
            ),
        ],
      ),
    );
  }
}
