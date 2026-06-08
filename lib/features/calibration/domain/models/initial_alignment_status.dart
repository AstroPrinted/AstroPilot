enum InitialAlignmentStatus {
  notAligned,
  selectingReferenceStar,
  waitingForManualCentering,
  aligned,
  alignmentFailed,
}

extension InitialAlignmentStatusLabel on InitialAlignmentStatus {
  String get label {
    return switch (this) {
      InitialAlignmentStatus.notAligned => 'No alineado',
      InitialAlignmentStatus.selectingReferenceStar =>
        'Seleccionando estrella de referencia',
      InitialAlignmentStatus.waitingForManualCentering =>
        'Esperando centrado manual',
      InitialAlignmentStatus.aligned => 'Completada',
      InitialAlignmentStatus.alignmentFailed => 'Alineación fallida',
    };
  }
}
