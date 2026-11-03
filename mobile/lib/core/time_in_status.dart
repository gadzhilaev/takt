/// Format a duration as compact Russian label (мин. / ч. / д. / нед.).
String? formatDuration(Duration duration) {
  var ms = duration.inMilliseconds;
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

/// Human-readable time since [iso] until [now] (time in column).
String? formatTimeInStatus(String? iso, {DateTime? now}) {
  if (iso == null || iso.isEmpty) return null;
  final start = DateTime.tryParse(iso)?.toLocal();
  if (start == null) return null;
  final end = now ?? DateTime.now();
  return formatDuration(end.difference(start));
}

/// Active: time in column. Done: created → closed (how long solving took).
String? formatTaskTimeLabel({
  required bool isDone,
  String? createdAt,
  String? closedAt,
  String? statusEnteredAt,
  String? updatedAt,
  DateTime? now,
}) {
  if (isDone) {
    final start = DateTime.tryParse(createdAt ?? '')?.toLocal();
    final endIso = closedAt ?? statusEnteredAt ?? updatedAt;
    final end = DateTime.tryParse(endIso ?? '')?.toLocal();
    if (start == null || end == null) return null;
    return formatDuration(end.difference(start));
  }
  return formatTimeInStatus(
    statusEnteredAt ?? updatedAt ?? createdAt,
    now: now,
  );
}

String taskTimeTitle(bool isDone) =>
    isDone ? 'Сколько заняло решение' : 'Сколько задача в этом столбце';
