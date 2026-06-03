import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../calibration/domain/services/astronomy_position_service.dart';
import '../../../settings/application/settings_service.dart';
import '../../application/visible_objects_service.dart';
import '../../data/repository/celestial_catalog_repository.dart';
import '../../domain/models/celestial_object.dart';
import '../../domain/models/visible_celestial_object.dart';
import '../widgets/category_filter_chips.dart';
import '../widgets/celestial_list_tile.dart';
import 'celestial_detail_screen.dart';

class CatalogScreen extends StatefulWidget {
  final bool initialVisibleOnly;

  const CatalogScreen({super.key, this.initialVisibleOnly = false});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final CelestialCatalogRepository _repository = CelestialCatalogRepository();
  late bool _visibleOnly;
  String _category = 'all';
  String _query = '';
  bool _loading = true;
  String? _error;
  List<VisibleCelestialObject> _visibleObjects = const [];
  bool _visibleLoading = false;
  String? _visibleError;
  DateTime? _visibleComputedAt;

  @override
  void initState() {
    super.initState();
    _visibleOnly = widget.initialVisibleOnly;
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      await _repository.initialize();
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      if (_visibleOnly) {
        unawaited(_refreshVisibleObjects());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _refreshVisibleObjects() async {
    if (!mounted) return;
    setState(() {
      _visibleLoading = true;
      _visibleError = null;
    });

    try {
      final service = VisibleObjectsService(
        catalogRepository: _repository,
        observerDataProvider: context.read<SettingsService>(),
        astronomyPositionService: const AstronomyPositionService(),
      );
      final objects = await service.loadObjects(
        category: _category,
        query: _query,
        visibleOnly: true,
      );
      if (!mounted) return;
      setState(() {
        _visibleObjects = objects;
        _visibleComputedAt = DateTime.now().toUtc();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _visibleError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _visibleLoading = false;
        });
      }
    }
  }

  void _setVisibleOnly(bool value) {
    if (_visibleOnly == value) return;
    setState(() {
      _visibleOnly = value;
    });
    if (value) {
      unawaited(_refreshVisibleObjects());
    }
  }

  void _setCategory(String value) {
    setState(() => _category = value);
    if (_visibleOnly) {
      unawaited(_refreshVisibleObjects());
    }
  }

  void _setQuery(String value) {
    setState(() => _query = value);
    if (_visibleOnly) {
      unawaited(_refreshVisibleObjects());
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _loading
        ? const <CelestialObject>[]
        : _repository.searchByName(_query, category: _category);
    final settings = context.watch<SettingsService>();
    final observer = settings.current();

    return Scaffold(
      appBar: AppBar(
        title: Text(_visibleOnly ? 'Objetos visibles' : 'Catalogo Celestial'),
        actions: [
          if (_visibleOnly)
            IconButton(
              tooltip: 'Recalcular visibles',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _visibleLoading ? null : _refreshVisibleObjects,
            ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () async {
              final value = await showSearch<String?>(
                context: context,
                delegate: _CatalogSearchDelegate(
                  initialQuery: _query,
                  repository: _repository,
                  category: _category,
                ),
              );
              if (value == null) return;
              _setQuery(value);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 12),
            _CatalogModeSelector(
              visibleOnly: _visibleOnly,
              onChanged: _setVisibleOnly,
            ),
            const SizedBox(height: 10),
            CategoryFilterChips(selected: _category, onSelected: _setCategory),
            const SizedBox(height: 8),
            if (_visibleOnly) ...[
              _VisibleModeInfo(
                count: _visibleObjects.length,
                loading: _visibleLoading,
                computedAt: _visibleComputedAt,
                latDeg: observer.latDeg,
                lonDeg: observer.lonDeg,
                utc: observer.utc,
                onRefresh: _refreshVisibleObjects,
              ),
              const SizedBox(height: 8),
            ],
            if (_query.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _setQuery(''),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: Text('Busqueda: "$_query"'),
                ),
              ),
            const SizedBox(height: 4),
            Expanded(
              child: _visibleOnly
                  ? _buildVisibleBody(_visibleObjects)
                  : _buildBody(results),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<CelestialObject> objects) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Error al cargar catalogo: $_error'));
    }
    if (objects.isEmpty) {
      return const Center(child: Text('No se encontraron objetos'));
    }

    return ListView.separated(
      itemCount: objects.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final object = objects[index];
        return CelestialListTile(
          object: object,
          onTap: () => _openDetail(object),
        );
      },
    );
  }

  Widget _buildVisibleBody(List<VisibleCelestialObject> objects) {
    if (_loading || _visibleLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Error al cargar catalogo: $_error'));
    }
    if (_visibleError != null) {
      return Center(
        child: Text('Error al calcular objetos visibles: $_visibleError'),
      );
    }
    if (objects.isEmpty) {
      return const Center(
        child: Text(
          'No hay objetos visibles con la ubicacion, fecha y hora actuales.',
        ),
      );
    }

    return ListView.separated(
      itemCount: objects.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final info = objects[index];
        return CelestialListTile(
          object: info.object,
          visibleInfo: info,
          onTap: () => _openDetail(info.object),
        );
      },
    );
  }

  void _openDetail(CelestialObject object) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CelestialDetailScreen(object: object)),
    );
  }
}

class _CatalogModeSelector extends StatelessWidget {
  final bool visibleOnly;
  final ValueChanged<bool> onChanged;

  const _CatalogModeSelector({
    required this.visibleOnly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ChoiceChip(
            selected: !visibleOnly,
            label: const Center(child: Text('Catalogo completo')),
            onSelected: (_) => onChanged(false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ChoiceChip(
            selected: visibleOnly,
            label: const Center(child: Text('Objetos visibles')),
            onSelected: (_) => onChanged(true),
          ),
        ),
      ],
    );
  }
}

class _VisibleModeInfo extends StatelessWidget {
  final int count;
  final bool loading;
  final DateTime? computedAt;
  final double latDeg;
  final double lonDeg;
  final DateTime utc;
  final VoidCallback onRefresh;

  const _VisibleModeInfo({
    required this.count,
    required this.loading,
    required this.computedAt,
    required this.latDeg,
    required this.lonDeg,
    required this.utc,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final timestamp = computedAt ?? utc;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.secondary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.secondary.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_rounded, color: colorScheme.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loading
                      ? 'Calculando objetos visibles...'
                      : '$count visibles',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              TextButton.icon(
                onPressed: loading ? null : onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Recalcular'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Visible = altitud >= 0°. Advertencia si esta entre 0° y 5°.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Ubicacion ${latDeg.toStringAsFixed(4)}, ${lonDeg.toStringAsFixed(4)} · UTC ${timestamp.toIso8601String()}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}

class _CatalogSearchDelegate extends SearchDelegate<String?> {
  final CelestialCatalogRepository repository;
  final String category;

  _CatalogSearchDelegate({
    required String initialQuery,
    required this.repository,
    required this.category,
  }) {
    query = initialQuery;
  }

  @override
  String get searchFieldLabel => 'Buscar objeto...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
        icon: const Icon(Icons.clear_rounded),
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back_rounded),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    close(context, query);
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _DebouncedSuggestions(
      query: query,
      repository: repository,
      category: category,
      onTap: (obj) => close(context, obj.name),
    );
  }
}

class _DebouncedSuggestions extends StatefulWidget {
  final String query;
  final CelestialCatalogRepository repository;
  final String category;
  final ValueChanged<CelestialObject> onTap;

  const _DebouncedSuggestions({
    required this.query,
    required this.repository,
    required this.category,
    required this.onTap,
  });

  @override
  State<_DebouncedSuggestions> createState() => _DebouncedSuggestionsState();
}

class _DebouncedSuggestionsState extends State<_DebouncedSuggestions> {
  static const _debounce = Duration(milliseconds: 400);
  static const _minQueryLength = 2;

  Timer? _timer;
  List<CelestialObject> _results = [];
  bool _debouncing = false;

  @override
  void initState() {
    super.initState();
    _search(immediate: true);
  }

  @override
  void didUpdateWidget(covariant _DebouncedSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _search();
    }
  }

  void _search({bool immediate = false}) {
    _timer?.cancel();

    if (widget.query.isEmpty) {
      setState(() {
        _results = widget.repository.getByCategory(widget.category);
        _debouncing = false;
      });
      return;
    }

    if (widget.query.trim().length < _minQueryLength && !immediate) {
      setState(() {
        _results = widget.repository.getByCategory(widget.category);
        _debouncing = false;
      });
      return;
    }

    if (immediate) {
      _execute();
      return;
    }

    setState(() => _debouncing = true);
    _timer = Timer(_debounce, _execute);
  }

  void _execute() {
    if (!mounted) return;
    setState(() {
      _results = widget.repository.searchByName(
        widget.query,
        category: widget.category,
      );
      _debouncing = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.query.isEmpty) {
      return _SuggestionList(
        hint: 'Escribe el nombre de un objeto celeste',
        results: _results,
        onTap: widget.onTap,
      );
    }

    if (_debouncing) {
      return _SuggestionList(
        hint: 'Buscando...',
        results: _results,
        onTap: widget.onTap,
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No se encontraron objetos para "${widget.query}"'),
        ),
      );
    }

    return _SuggestionList(
      hint: '${_results.length} resultado${_results.length == 1 ? '' : 's'}',
      results: _results,
      onTap: widget.onTap,
    );
  }
}

class _SuggestionList extends StatelessWidget {
  final String hint;
  final List<CelestialObject> results;
  final ValueChanged<CelestialObject> onTap;

  // ignore: prefer_const_constructors_in_immutables
  _SuggestionList({
    required this.hint,
    required this.results,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(hint, style: Theme.of(context).textTheme.bodySmall),
        ),
        const Divider(height: 1),
        ...results.map(
          (obj) => CelestialListTile(object: obj, onTap: () => onTap(obj)),
        ),
      ],
    );
  }
}
