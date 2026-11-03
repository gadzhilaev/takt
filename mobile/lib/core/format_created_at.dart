/// Relative created-at: сегодня/вчера/дд.мм.гггг в HH:MM (local).
String? formatCreatedAt(String? iso, {DateTime? now}) {
  if (iso == null || iso.isEmpty) return null;
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return null;

  final n = now ?? DateTime.now();
  final time =
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final dayDiff = today.difference(day).inDays;

  if (dayDiff == 0) return 'сегодня в $time';
  if (dayDiff == 1) return 'вчера в $time';

  final dd = dt.day.toString().padLeft(2, '0');
  final mm = dt.month.toString().padLeft(2, '0');
  return '$dd.$mm.${dt.year} в $time';
}
