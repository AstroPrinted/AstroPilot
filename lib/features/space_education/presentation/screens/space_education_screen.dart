import 'package:flutter/material.dart';

import '../../data/local_iss_pass_service.dart';
import '../../data/local_space_education_repository.dart';
import '../../domain/models/educational_space_object.dart';
import '../../domain/models/iss_pass.dart';
import '../../domain/services/iss_pass_service.dart';

class SpaceEducationScreen extends StatefulWidget {
  final LocalSpaceEducationRepository repository;
  final IssPassService issPassService;

  /// Barra superior; por defecto "Satélites y exploración espacial".
  final PreferredSizeWidget? appBar;

  const SpaceEducationScreen({
    super.key,
    this.repository = const LocalSpaceEducationRepository(),
    this.issPassService = const LocalIssPassService(),
    this.appBar,
  });

  @override
  State<SpaceEducationScreen> createState() => _SpaceEducationScreenState();
}

class _SpaceEducationScreenState extends State<SpaceEducationScreen> {
  late final Future<List<EducationalSpaceObject>> _objectsFuture;

  @override
  void initState() {
    super.initState();
    _objectsFuture = widget.repository.loadObjects();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          widget.appBar ??
          AppBar(title: const Text('Satélites y exploración espacial')),
      body: FutureBuilder<List<EducationalSpaceObject>>(
        future: _objectsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _CenteredMessage(
              icon: Icons.error_outline_rounded,
              title: 'No se pudo cargar la sección',
              message: snapshot.error.toString(),
            );
          }

          final objects = snapshot.data ?? const [];
          if (objects.isEmpty) {
            return const _CenteredMessage(
              icon: Icons.public_off_rounded,
              title: 'Sin contenido educativo',
              message:
                  'No hay objetos educativos disponibles en el asset local.',
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              const _EducationSafetyBanner(),
              const SizedBox(height: 14),
              _IntroCard(objectCount: objects.length),
              const SizedBox(height: 14),
              for (final category in educationalSpaceCategories) ...[
                _CategoryCard(
                  category: category,
                  count: objects
                      .where((object) => object.category == category)
                      .length,
                  onTap: () => _openCategory(context, category, objects),
                ),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }

  void _openCategory(
    BuildContext context,
    EducationalSpaceCategory category,
    List<EducationalSpaceObject> objects,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SpaceEducationCategoryScreen(
          category: category,
          objects: objects
              .where((object) => object.category == category)
              .toList(growable: false),
          issPassService: widget.issPassService,
        ),
      ),
    );
  }
}

class _SpaceEducationCategoryScreen extends StatelessWidget {
  final EducationalSpaceCategory category;
  final List<EducationalSpaceObject> objects;
  final IssPassService issPassService;

  const _SpaceEducationCategoryScreen({
    required this.category,
    required this.objects,
    required this.issPassService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(category.label)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const _EducationSafetyBanner(compact: true),
          const SizedBox(height: 14),
          if (category == EducationalSpaceCategory.iss) ...[
            _IssPassPanel(service: issPassService),
            const SizedBox(height: 14),
          ],
          for (final object in objects) ...[
            _EducationalObjectCard(object: object),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _EducationalObjectDetailScreen extends StatelessWidget {
  final EducationalSpaceObject object;

  const _EducationalObjectDetailScreen({required this.object});

  @override
  Widget build(BuildContext context) {
    final metadata = _metadataFor(object);

    return Scaffold(
      appBar: AppBar(title: Text(object.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const _EducationSafetyBanner(compact: true),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Pill(
                    icon: _iconForType(object.type),
                    label: object.type.label,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    object.name,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(object.longDescription),
                ],
              ),
            ),
          ),
          if (metadata.isNotEmpty) ...[
            const SizedBox(height: 14),
            _MetadataCard(items: metadata),
          ],
          if (object.visibilityNote != null) ...[
            const SizedBox(height: 14),
            _InfoCard(
              icon: Icons.visibility_rounded,
              title: 'Visibilidad educativa',
              message: object.visibilityNote!,
            ),
          ],
          const SizedBox(height: 14),
          _FactsCard(facts: object.facts),
        ],
      ),
    );
  }

  List<({String label, String value})> _metadataFor(
    EducationalSpaceObject object,
  ) {
    return [
      if (object.agency != null) (label: 'Agencia', value: object.agency!),
      if (object.missionStatus != null)
        (label: 'Estado', value: object.missionStatus!),
      if (object.destination != null)
        (label: 'Destino', value: object.destination!),
      if (object.launchYear != null)
        (label: 'Lanzamiento', value: object.launchYear.toString()),
      if (object.orbit != null) (label: 'Órbita', value: object.orbit!),
    ];
  }
}

class _IntroCard extends StatelessWidget {
  final int objectCount;

  const _IntroCard({required this.objectCount});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.satellite_alt_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Objetos artificiales y misiones',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Explora $objectCount fichas locales sobre satélites, la ISS, sondas y conceptos espaciales. Todo el contenido básico está disponible sin internet.',
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final EducationalSpaceCategory category;
  final int count;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.primary.withValues(alpha: 0.14),
                child: Icon(
                  _iconForCategory(category),
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(category.description),
                    const SizedBox(height: 8),
                    Text(
                      '$count fichas educativas',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _EducationalObjectCard extends StatelessWidget {
  final EducationalSpaceObject object;

  const _EducationalObjectCard({required this.object});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _EducationalObjectDetailScreen(object: object),
            ),
          );
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
          child: Icon(_iconForType(object.type), size: 20),
        ),
        title: Text(
          object.name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('${object.type.label}\n${object.shortDescription}'),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _IssPassPanel extends StatefulWidget {
  final IssPassService service;

  const _IssPassPanel({required this.service});

  @override
  State<_IssPassPanel> createState() => _IssPassPanelState();
}

class _IssPassPanelState extends State<_IssPassPanel> {
  late final Future<IssPassResult> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.service.getUpcomingIssPasses(
      latitude: 0,
      longitude: 0,
      from: DateTime.now().toUtc(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<IssPassResult>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final result = snapshot.data;
        if (result == null || snapshot.hasError) {
          return const _InfoCard(
            icon: Icons.cloud_off_rounded,
            title: 'Próximos pasos de la ISS',
            message:
                'No se pudieron revisar datos orbitales. El contenido educativo local sigue disponible.',
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.timeline_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Próximos pasos de la ISS',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(result.message),
                const SizedBox(height: 12),
                if (result.passes.isEmpty)
                  const _EmptyPassState()
                else
                  for (final pass in result.passes) _IssPassTile(pass: pass),
                const SizedBox(height: 12),
                const Text(
                  'La ISS suele verse como un punto brillante que se mueve de forma constante por el cielo. No parpadea como un avión y no deja estela.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _IssPassTile extends StatelessWidget {
  final IssPass pass;

  const _IssPassTile({required this.pass});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pass.visibilityLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text('Hora: ${_formatTime(pass.startTime)}'),
          Text('Duración: ${_formatDuration(pass.duration)}'),
          Text('Altura máxima: ${pass.maxElevation}'),
          Text('Dirección: ${pass.startDirection} → ${pass.endDirection}'),
          if (pass.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(pass.note, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime? value) {
    if (value == null) return 'Pendiente';
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDuration(Duration? value) {
    if (value == null) return 'Pendiente';
    return '${value.inMinutes} min';
  }
}

class _EmptyPassState extends StatelessWidget {
  const _EmptyPassState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'La primera versión muestra el espacio reservado para predicciones futuras sin depender de internet.',
            ),
          ),
        ],
      ),
    );
  }
}

class _EducationSafetyBanner extends StatelessWidget {
  final bool compact;

  const _EducationSafetyBanner({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.12),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.38)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.school_rounded, color: colorScheme.primary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Sección educativa: aquí solo se lee información. No controla el telescopio, no envía comandos y no mueve motores.',
            ),
          ),
        ],
      ),
    );
  }
}

class _MetadataCard extends StatelessWidget {
  final List<({String label, String value})> items;

  const _MetadataCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        item.label,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.value,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FactsCard extends StatelessWidget {
  final List<String> facts;

  const _FactsCard({required this.facts});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Curiosidades',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            for (final fact in facts) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle, size: 6),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(fact)),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Pill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

IconData _iconForCategory(EducationalSpaceCategory category) {
  return switch (category) {
    EducationalSpaceCategory.iss => Icons.home_work_rounded,
    EducationalSpaceCategory.satellites => Icons.satellite_alt_rounded,
    EducationalSpaceCategory.spaceProbes => Icons.rocket_launch_rounded,
    EducationalSpaceCategory.curiosities => Icons.lightbulb_outline_rounded,
  };
}

IconData _iconForType(EducationalSpaceObjectType type) {
  return switch (type) {
    EducationalSpaceObjectType.artificialSatellite =>
      Icons.satellite_alt_rounded,
    EducationalSpaceObjectType.spaceStation => Icons.home_work_rounded,
    EducationalSpaceObjectType.spaceProbe => Icons.rocket_launch_rounded,
    EducationalSpaceObjectType.rover => Icons.smart_toy_outlined,
    EducationalSpaceObjectType.spaceTelescope => Icons.travel_explore_rounded,
    EducationalSpaceObjectType.historicalMission => Icons.history_edu_rounded,
    EducationalSpaceObjectType.curiosity => Icons.lightbulb_outline_rounded,
  };
}
