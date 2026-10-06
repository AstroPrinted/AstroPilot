/// "06/10/2026 18:14:05 UTC-3": la hora local del teléfono con su desfase,
/// para que se pueda comparar con un reloj sin convertir desde UTC.
String formatLocalDateTime(DateTime time) {
  final t = time.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  final offset = t.timeZoneOffset;
  final minutes = offset.inMinutes.abs();
  final zone =
      'UTC${offset.isNegative ? '-' : '+'}${minutes ~/ 60}'
      '${minutes % 60 == 0 ? '' : ':${two(minutes % 60)}'}';
  return '${two(t.day)}/${two(t.month)}/${t.year} '
      '${two(t.hour)}:${two(t.minute)}:${two(t.second)} $zone';
}
