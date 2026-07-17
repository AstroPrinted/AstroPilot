import 'package:astroprintedlogicincludedgeoengine/features/space_education/data/local_space_education_repository.dart';
import 'package:astroprintedlogicincludedgeoengine/features/space_education/domain/models/educational_space_object.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads offline educational objects with required categories', () async {
    final objects = await const LocalSpaceEducationRepository().loadObjects();
    final categories = objects.map((object) => object.category).toSet();

    expect(objects, isNotEmpty);
    expect(categories, containsAll(educationalSpaceCategories));
    expect(objects.any((object) => object.id == 'iss'), isTrue);
  });

  test('educational objects are never controllable', () async {
    final objects = await const LocalSpaceEducationRepository().loadObjects();

    expect(objects.every((object) => object.allowGoto == false), isTrue);
    expect(objects.every((object) => object.isControllable == false), isTrue);
  });
}
