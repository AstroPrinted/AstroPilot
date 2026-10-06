import 'package:astroprintedlogicincludedgeoengine/core/theme/app_theme.dart';
import 'package:astroprintedlogicincludedgeoengine/features/space_education/data/local_space_education_repository.dart';
import 'package:astroprintedlogicincludedgeoengine/features/space_education/domain/models/educational_space_object.dart';
import 'package:astroprintedlogicincludedgeoengine/features/space_education/presentation/screens/space_education_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows educational categories and no telescope actions', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_screen()));
    await _pumpEducationScreen(tester);

    expect(find.text('Satélites y exploración espacial'), findsOneWidget);
    expect(
      find.text('Estación Espacial Internacional', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text('Satélites artificiales', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Sondas espaciales', skipOffstage: false), findsOneWidget);
    expect(find.text('Curiosidades', skipOffstage: false), findsOneWidget);
    expect(find.textContaining('No controla el telescopio'), findsOneWidget);

    for (final label in _blockedActionLabels) {
      expect(
        find.textContaining(label, findRichText: true, skipOffstage: false),
        findsNothing,
      );
    }
  });
}

const _blockedActionLabels = [
  'GOTO',
  'Enviar al telescopio',
  'Track',
  'Seguir objeto',
  'Apuntar telescopio',
];

Widget _app(Widget child) {
  return MaterialApp(theme: AppTheme.darkTheme, home: child);
}

Widget _screen() {
  return const SpaceEducationScreen(
    repository: _FakeSpaceEducationRepository(),
  );
}

Future<void> _pumpEducationScreen(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump();
}

class _FakeSpaceEducationRepository extends LocalSpaceEducationRepository {
  const _FakeSpaceEducationRepository() : super();

  @override
  Future<List<EducationalSpaceObject>> loadObjects() async {
    return const [
      EducationalSpaceObject(
        id: 'iss',
        name: 'Estación Espacial Internacional',
        category: EducationalSpaceCategory.iss,
        type: EducationalSpaceObjectType.spaceStation,
        shortDescription: 'Laboratorio orbital educativo.',
        longDescription: 'Laboratorio orbital educativo.',
        facts: ['Se ve porque refleja luz solar.'],
      ),
      EducationalSpaceObject(
        id: 'hubble',
        name: 'Hubble Space Telescope',
        category: EducationalSpaceCategory.satellites,
        type: EducationalSpaceObjectType.spaceTelescope,
        shortDescription: 'Observatorio espacial.',
        longDescription: 'Observatorio espacial.',
        facts: ['Observa desde fuera de la atmósfera densa.'],
      ),
      EducationalSpaceObject(
        id: 'voyager_1',
        name: 'Voyager 1',
        category: EducationalSpaceCategory.spaceProbes,
        type: EducationalSpaceObjectType.spaceProbe,
        shortDescription: 'Sonda de espacio profundo.',
        longDescription: 'Sonda de espacio profundo.',
        facts: ['Fue lanzada en 1977.'],
      ),
      EducationalSpaceObject(
        id: 'leo',
        name: '¿Qué es una órbita baja terrestre?',
        category: EducationalSpaceCategory.curiosities,
        type: EducationalSpaceObjectType.curiosity,
        shortDescription: 'Concepto orbital básico.',
        longDescription: 'Concepto orbital básico.',
        facts: ['Está cerca de la Tierra comparada con otras órbitas.'],
      ),
    ];
  }
}
