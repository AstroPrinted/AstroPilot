enum EducationalSpaceCategory { iss, satellites, spaceProbes, curiosities }

const educationalSpaceCategories = <EducationalSpaceCategory>[
  EducationalSpaceCategory.iss,
  EducationalSpaceCategory.satellites,
  EducationalSpaceCategory.spaceProbes,
  EducationalSpaceCategory.curiosities,
];

extension EducationalSpaceCategoryInfo on EducationalSpaceCategory {
  String get id {
    return switch (this) {
      EducationalSpaceCategory.iss => 'iss',
      EducationalSpaceCategory.satellites => 'satellites',
      EducationalSpaceCategory.spaceProbes => 'space_probes',
      EducationalSpaceCategory.curiosities => 'curiosities',
    };
  }

  String get label {
    return switch (this) {
      EducationalSpaceCategory.iss => 'Estación Espacial Internacional',
      EducationalSpaceCategory.satellites => 'Satélites artificiales',
      EducationalSpaceCategory.spaceProbes => 'Sondas espaciales',
      EducationalSpaceCategory.curiosities => 'Curiosidades',
    };
  }

  String get description {
    return switch (this) {
      EducationalSpaceCategory.iss =>
        'Aprende por qué la ISS puede verse desde la Tierra.',
      EducationalSpaceCategory.satellites =>
        'Conoce observatorios, constelaciones y satélites útiles.',
      EducationalSpaceCategory.spaceProbes =>
        'Explora misiones que visitaron planetas, lunas y el espacio profundo.',
      EducationalSpaceCategory.curiosities =>
        'Ideas breves para entender órbitas, brillo y objetos artificiales.',
    };
  }
}

EducationalSpaceCategory educationalSpaceCategoryFromId(String id) {
  for (final category in educationalSpaceCategories) {
    if (category.id == id) {
      return category;
    }
  }
  throw FormatException('Categoría educativa desconocida: $id');
}

enum EducationalSpaceObjectType {
  artificialSatellite,
  spaceStation,
  spaceProbe,
  rover,
  spaceTelescope,
  historicalMission,
  curiosity,
}

extension EducationalSpaceObjectTypeInfo on EducationalSpaceObjectType {
  String get id {
    return switch (this) {
      EducationalSpaceObjectType.artificialSatellite => 'artificial_satellite',
      EducationalSpaceObjectType.spaceStation => 'space_station',
      EducationalSpaceObjectType.spaceProbe => 'space_probe',
      EducationalSpaceObjectType.rover => 'rover',
      EducationalSpaceObjectType.spaceTelescope => 'space_telescope',
      EducationalSpaceObjectType.historicalMission => 'historical_mission',
      EducationalSpaceObjectType.curiosity => 'curiosity',
    };
  }

  String get label {
    return switch (this) {
      EducationalSpaceObjectType.artificialSatellite => 'Satélite artificial',
      EducationalSpaceObjectType.spaceStation => 'Estación espacial',
      EducationalSpaceObjectType.spaceProbe => 'Sonda espacial',
      EducationalSpaceObjectType.rover => 'Rover',
      EducationalSpaceObjectType.spaceTelescope => 'Telescopio espacial',
      EducationalSpaceObjectType.historicalMission => 'Misión histórica',
      EducationalSpaceObjectType.curiosity => 'Curiosidad',
    };
  }
}

EducationalSpaceObjectType educationalSpaceObjectTypeFromId(String id) {
  for (final type in EducationalSpaceObjectType.values) {
    if (type.id == id) {
      return type;
    }
  }
  throw FormatException('Tipo educativo desconocido: $id');
}

class EducationalSpaceObject {
  final String id;
  final String name;
  final EducationalSpaceCategory category;
  final EducationalSpaceObjectType type;
  final String shortDescription;
  final String longDescription;
  final List<String> facts;
  final String? imageAssetPath;

  /// Autor y licencia de la imagen, tal como exige su licencia.
  final String? imageCredit;
  final String? agency;
  final String? missionStatus;
  final String? destination;
  final int? launchYear;
  final String? orbit;
  final String? visibilityNote;

  const EducationalSpaceObject({
    required this.id,
    required this.name,
    required this.category,
    required this.type,
    required this.shortDescription,
    required this.longDescription,
    required this.facts,
    this.imageAssetPath,
    this.imageCredit,
    this.agency,
    this.missionStatus,
    this.destination,
    this.launchYear,
    this.orbit,
    this.visibilityNote,
  });

  bool get allowGoto => false;
  bool get isControllable => false;
}
