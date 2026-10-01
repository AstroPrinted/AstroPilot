import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/ap_widgets.dart';
import '../../../../catalog/data/repository/celestial_catalog_repository.dart';
import '../../../../catalog/domain/models/celestial_object.dart';
import '../../widgets/object_display.dart';
import 'object_sheet_screen.dart';

/// Búsqueda de objetos del catálogo (sin distinguir tildes ni mayúsculas).
class EducationSearchScreen extends StatefulWidget {
  const EducationSearchScreen({super.key});

  @override
  State<EducationSearchScreen> createState() => _EducationSearchScreenState();
}

class _EducationSearchScreenState extends State<EducationSearchScreen> {
  static const _suggestionCount = 6;
  final _query = TextEditingController();
  List<CelestialObject> _all = const [];

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
    _load();
  }

  Future<void> _load() async {
    final repository = CelestialCatalogRepository();
    await repository.initialize();
    if (!mounted) return;
    setState(() => _all = repository.getAllObjects());
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  static String _normalize(String text) {
    const from = 'áéíóúüñÁÉÍÓÚÜÑ';
    const to = 'aeiouunaeiouun';
    final buffer = StringBuffer();
    for (final char in text.toLowerCase().split('')) {
      final index = from.indexOf(char);
      buffer.write(index < 0 ? char : to[index]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim();
    final results = q.isEmpty
        ? _all.take(_suggestionCount).toList()
        : _all
              .where(
                (o) => _normalize(
                  '${o.name} ${ObjectDisplay.subtitle(o)}',
                ).contains(_normalize(q)),
              )
              .toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: TextField(
          controller: _query,
          autofocus: true,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 18, color: ApColors.text),
          decoration: const InputDecoration(
            hintText: 'Buscar objeto...',
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
        actions: [
          if (q.isNotEmpty)
            IconButton(
              tooltip: 'Limpiar',
              icon: const Icon(Icons.close),
              onPressed: _query.clear,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          ApSectionLabel(q.isEmpty ? 'Sugerencias' : 'Resultados'),
          const SizedBox(height: 8),
          if (q.isNotEmpty && results.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Sin resultados para "$q".',
                textAlign: TextAlign.center,
                style: ApText.body,
              ),
            )
          else
            ApCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              gap: 0,
              children: [
                for (var i = 0; i < results.length; i++) ...[
                  if (i > 0) const ApDivider(),
                  _ResultRow(
                    object: results[i],
                    icon: q.isEmpty ? Icons.history : Icons.search,
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final CelestialObject object;
  final IconData icon;

  const _ResultRow({required this.object, required this.icon});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ObjectSheetScreen(object: object),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: ApColors.muted),
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
                ],
              ),
            ),
            const Icon(Icons.north_west, color: ApColors.muted, size: 22),
          ],
        ),
      ),
    );
  }
}
