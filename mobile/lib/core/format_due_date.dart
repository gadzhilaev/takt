import 'time_in_status.dart';

// Due-date chip helpers (device local timezone).

bool isDueOverdue(String? iso, {DateTime? now}) {
  if (iso == null || iso.isEmpty) return false;
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return false;
  return d.isBefore(now ?? DateTime.now());
}

String? formatDueAbsolute(String? iso, {DateTime? now}) {
  if (iso == null || iso.isEmpty) return null;
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return null;
  final n = now ?? DateTime.now();

  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  final time = '$hh:$mm';

  final startToday = DateTime(n.year, n.month, n.day);
  final startDay = DateTime(d.year, d.month, d.day);
  final dayDiff = startDay.difference(startToday).inDays;

  if (dayDiff == 0) return 'сегодня $time';
  if (dayDiff == 1) return 'завтра $time';
  if (dayDiff == -1) return 'вчера $time';

  final dd = d.day.toString().padLeft(2, '0');
  final mo = d.month.toString().padLeft(2, '0');
  if (d.year == n.year) return '$dd.$mo $time';
  return '$dd.$mo.${d.year} $time';
}

/// Remaining until due (same style as time-in-status), or overdue duration.
String? formatDueChip(String? iso, {DateTime? now, bool isDone = false}) {
  if (iso == null || iso.isEmpty) return null;
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return null;
  final n = now ?? DateTime.now();
  if (isDone) return formatDueAbsolute(iso, now: n);

  final diff = d.difference(n);
  if (!diff.isNegative) return formatDuration(diff);
  return formatDuration(diff.abs());
}

String dueChipTitle(String? iso, {DateTime? now, bool isDone = false}) {
  final abs = formatDueAbsolute(iso, now: now);
  if (isDone) return abs == null ? 'Срок' : 'Срок был $abs';
  if (isDueOverdue(iso, now: now)) {
    return abs == null ? 'Срок просрочен' : 'Просрочено · сдача была $abs';
  }
  return abs == null ? 'До сдачи' : 'До сдачи · $abs';
}
