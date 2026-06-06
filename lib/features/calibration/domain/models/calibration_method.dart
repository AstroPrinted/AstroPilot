enum CalibrationMethod { oneStar, twoStars, threeStars, fixedObjectSync }

extension CalibrationMethodLabel on CalibrationMethod {
  String get title {
    return switch (this) {
      CalibrationMethod.oneStar => '1 estrella',
      CalibrationMethod.twoStars => '2 estrellas',
      CalibrationMethod.threeStars => '3 estrellas',
      CalibrationMethod.fixedObjectSync => 'Objeto fijo',
    };
  }

  String get description {
    return switch (this) {
      CalibrationMethod.oneStar =>
        'Referencia inicial. Centra manualmente una estrella y fija la posicion real Alt/Az del telescopio.',
      CalibrationMethod.twoStars =>
        'Proximamente: correccion multipunto con dos referencias.',
      CalibrationMethod.threeStars =>
        'Proximamente: correccion multipunto con tres referencias.',
      CalibrationMethod.fixedObjectSync =>
        'Proximamente: sincronizacion local cerca de un objeto.',
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
    return switch (this) {
      CalibrationMethod.oneStar => true,
      CalibrationMethod.twoStars ||
      CalibrationMethod.threeStars ||
      CalibrationMethod.fixedObjectSync => false,
    };
  }
}

CalibrationMethod calibrationMethodFromName(String? name) {
  return CalibrationMethod.values.firstWhere(
    (method) => method.name == name,
    orElse: () => CalibrationMethod.oneStar,
  );
}
