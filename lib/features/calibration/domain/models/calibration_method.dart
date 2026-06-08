enum CalibrationMethod { oneStar, twoStars, threeStars, fixedObjectSync }

extension CalibrationMethodLabel on CalibrationMethod {
  String get title {
    return switch (this) {
      CalibrationMethod.oneStar => 'Corrección con 1 estrella',
      CalibrationMethod.twoStars => 'Corrección con 2 estrellas',
      CalibrationMethod.threeStars => 'Corrección con 3 estrellas',
      CalibrationMethod.fixedObjectSync => 'Corrección con objeto fijo',
    };
  }

  String get description {
    return switch (this) {
      CalibrationMethod.oneStar =>
        'Guarda un offset simple entre la Alt/Az esperada y la posición donde centraste la estrella.',
      CalibrationMethod.twoStars =>
        'Promedia dos referencias separadas para mejorar el apuntado posterior al GOTO.',
      CalibrationMethod.threeStars =>
        'Usa tres referencias para preparar un modelo de corrección más completo.',
      CalibrationMethod.fixedObjectSync =>
        'Usa un objeto conocido como referencia local de ajuste fino.',
    };
  }

  int get requiredPointCount {
    return switch (this) {
      CalibrationMethod.oneStar => 1,
      CalibrationMethod.twoStars => 2,
      CalibrationMethod.threeStars => 3,
      CalibrationMethod.fixedObjectSync => 1,
    };
  }

  bool get isEnabledInMvp {
    return true;
  }
}

CalibrationMethod calibrationMethodFromName(String? name) {
  return CalibrationMethod.values.firstWhere(
    (method) => method.name == name,
    orElse: () => CalibrationMethod.oneStar,
  );
}
