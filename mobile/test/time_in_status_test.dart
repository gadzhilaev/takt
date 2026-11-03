import 'package:flutter_test/flutter_test.dart';
import 'package:takt_mobile/core/time_in_status.dart';

void main() {
  final base = DateTime.utc(2026, 11, 3, 12);

  test('formatTimeInStatus minutes hours days weeks', () {
    expect(formatTimeInStatus(base.subtract(const Duration(seconds: 30)).toIso8601String(), now: base), 'сейчас');
    expect(formatTimeInStatus(base.subtract(const Duration(minutes: 5)).toIso8601String(), now: base), '5 мин.');
    expect(formatTimeInStatus(base.subtract(const Duration(hours: 3)).toIso8601String(), now: base), '3 ч.');
    expect(formatTimeInStatus(base.subtract(const Duration(days: 2)).toIso8601String(), now: base), '2 д.');
    expect(formatTimeInStatus(base.subtract(const Duration(days: 21 * 7)).toIso8601String(), now: base), '21 нед.');
    expect(
      formatTimeInStatus(base.subtract(const Duration(days: 16 * 7 + 4)).toIso8601String(), now: base),
      '16 нед., 4 д.',
    );
  });

  test('null and bad input', () {
    expect(formatTimeInStatus(null), isNull);
    expect(formatTimeInStatus('nope'), isNull);
  });

  test('done task uses created → closed duration', () {
    final created = DateTime.utc(2026, 11, 1, 10);
    final closed = DateTime.utc(2026, 11, 3, 12);
    expect(
      formatTaskTimeLabel(
        isDone: true,
        createdAt: created.toIso8601String(),
        closedAt: closed.toIso8601String(),
        statusEnteredAt: closed.toIso8601String(),
        now: closed,
      ),
      '2 д.',
    );
  });

  test('active task uses time in column', () {
    expect(
      formatTaskTimeLabel(
        isDone: false,
        createdAt: base.subtract(const Duration(days: 5)).toIso8601String(),
        statusEnteredAt: base.subtract(const Duration(hours: 3)).toIso8601String(),
        now: base,
      ),
      '3 ч.',
    );
  });
}
