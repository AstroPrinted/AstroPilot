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
        'Rapida y simple. Estima un desfase basico usando una referencia de motores.',
      CalibrationMethod.twoStars =>
        'Correccion logica multipunto con dos referencias de motores.',
      CalibrationMethod.threeStars =>
        'Correccion logica multipunto con tres referencias de motores.',
      CalibrationMethod.fixedObjectSync =>
        'Permitira guardar una correccion local cerca de un objeto.',
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
      CalibrationMethod.oneStar ||
      CalibrationMethod.twoStars ||
      CalibrationMethod.threeStars => true,
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
