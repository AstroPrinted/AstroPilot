import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/ap_widgets.dart';
import '../../../../calibration/domain/services/astronomy_position_service.dart';
import '../../../../catalog/application/visible_objects_service.dart';
import '../../../../catalog/data/repository/celestial_catalog_repository.dart';
import '../../../../catalog/domain/models/visible_celestial_object.dart';
import '../../../../settings/application/settings_service.dart';
import '../../widgets/catalog_object_row.dart';
import '../../widgets/mode_scaffold.dart';
import '../../widgets/object_display.dart';
import 'education_search_screen.dart';
import 'object_sheet_screen.dart';

/// Catálogo del modo Educativo: completo o solo objetos visibles.
class EducationCatalogScreen extends StatefulWidget {
  const EducationCatalogScreen({super.key});

  @override
  State<EducationCatalogScreen> createState() => _EducationCatalogScreenState();
}

class _EducationCatalogScreenState extends State<EducationCatalogScreen> {
  bool _visibleOnly = false;
  CatalogCategory _category = CatalogCategory.all;
  List<VisibleCelestialObject> _objects = const [];
  DateTime? _computedAt;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final category = _category;
    final visibleOnly = _visibleOnly;
    if (!_loading) setState(() => _loading = true);
    try {
      final objects = await VisibleObjectsService(
        catalogRepository: CelestialCatalogRepository(),
        observerDataProvider: context.read<SettingsService>(),
        astronomyPositionService: const AstronomyPositionService(),
      ).loadObjects(category: category.key, visibleOnly: visibleOnly);
      if (!mounted || category != _category || visibleOnly != _visibleOnly) {
        return;
      }
      setState(() {
        _objects = objects;
        _computedAt = DateTime.now().toUtc();
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el catálogo: $error';
        _loading = false;
      });
    }
  }

  void _open(VisibleCelestialObject item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ObjectSheetScreen(object: item.object),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>().state;
    return Scaffold(
      appBar: ModeAppBar(
        title: _visibleOnly ? 'Objetos visibles' : 'Catálogo Celestial',
        showConnection: false,
        actions: [
          IconButton(
            tooltip: 'Buscar',
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const EducationSearchScreen(),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Recalcular',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: ModeBody(
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Catálogo completo')),
              ButtonSegment(value: true, label: Text('Objetos visibles')),
            ],
            selected: {_visibleOnly},
            onSelectionChanged: (value) {
              setState(() => _visibleOnly = value.first);
              unawaited(_refresh());
            },
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: ApColors.primary.withValues(alpha: 0.25),
              selectedForegroundColor: ApColors.text,
              foregroundColor: ApColors.text,
              side: const BorderSide(color: ApColors.outline),
            ),
          ),
          CategoryChips(
            selected: _category,
            onSelected: (category) {
              setState(() => _category = category);
              unawaited(_refresh());
            },
          ),
          const ApInfoLine(
            icon: Icons.explore,
            text:
                'Catálogo curado principalmente para objetos observables desde '
                'el hemisferio sur.',
          ),
          if (_visibleOnly)
            ApCard(
              children: [
                const ApCardHead(
                  icon: Icons.visibility,
                  title: 'Objetos visibles ahora',
                ),
                const Text(
                  'Visible = altitud >= 0°. Advertencia si está entre 0° y 5°.',
                  style: ApText.body,
                ),
                ApMonoBlock(
                  text: visibilityContext(
                    settings.latDeg,
                    settings.lonDeg,
                    _computedAt ?? settings.effectiveUtc,
                  ),
                ),
              ],
            ),
          if (_error != null)
            ApNotice(icon: Icons.error_outline, tone: ApTone.error, text: _error!)
          else if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_objects.isEmpty)
            const ApCard(
              children: [
                Text(
                  'No hay objetos para mostrar con estos filtros.',
                  textAlign: TextAlign.center,
                  style: ApText.body,
                ),
              ],
            )
          else
            ApCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              gap: 0,
              children: [
                for (var i = 0; i < _objects.length; i++) ...[
                  if (i > 0) const ApDivider(),
                  CatalogObjectRow(
                    item: _objects[i],
                    onTap: () => _open(_objects[i]),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
