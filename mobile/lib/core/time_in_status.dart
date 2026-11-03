/// Human-readable time since task entered its current column (как на web).
String? formatTimeInStatus(String? iso, {DateTime? now}) {
  if (iso == null || iso.isEmpty) return null;
  final start = DateTime.tryParse(iso)?.toLocal();
  if (start == null) return null;
  final end = now ?? DateTime.now();
  var ms = end.difference(start).inMilliseconds;
  if (ms < 0) ms = 0;

  const minute = 60 * 1000;
  const hour = 60 * minute;
  const day = 24 * hour;
  const week = 7 * day;

  if (ms < minute) return 'сейчас';
  if (ms < hour) {
    final m = ms ~/ minute;
    return '$m мин.';
  }
  if (ms < day) {
    final h = ms ~/ hour;
    return '$h ч.';
  }
  if (ms < week) {
    final d = ms ~/ day;
    return '$d д.';
  }
  final w = ms ~/ week;
  final remDays = (ms % week) ~/ day;
  if (remDays > 0) return '$w нед., $remDays д.';
  return '$w нед.';
}
