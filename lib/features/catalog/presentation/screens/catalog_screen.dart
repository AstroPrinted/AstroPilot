import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/repository/celestial_catalog_repository.dart';
import '../../domain/models/celestial_object.dart';
import '../widgets/category_filter_chips.dart';
import '../widgets/celestial_list_tile.dart';
import 'celestial_detail_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final CelestialCatalogRepository _repository = CelestialCatalogRepository();
  String _category = 'all';
  String _query = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      await _repository.initialize();
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _loading
        ? const <CelestialObject>[]
        : _repository.searchByName(_query, category: _category);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalogo Celestial'),
        actions: [
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
              setState(() => _query = value);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 12),
            CategoryFilterChips(
              selected: _category,
              onSelected: (value) => setState(() => _category = value),
            ),
            const SizedBox(height: 8),
            if (_query.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _query = ''),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: Text('Busqueda: "$_query"'),
                ),
              ),
            const SizedBox(height: 4),
            Expanded(child: _buildBody(results)),
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
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CelestialDetailScreen(object: object),
              ),
            );
          },
        );
      },
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
