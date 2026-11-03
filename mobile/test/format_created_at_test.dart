import 'package:flutter_test/flutter_test.dart';
import 'package:takt_mobile/core/format_created_at.dart';

void main() {
  final now = DateTime(2026, 11, 3, 17, 30);

  test('today yesterday absolute', () {
    expect(formatCreatedAt(DateTime(2026, 11, 3, 18).toIso8601String(), now: now), 'сегодня в 18:00');
    expect(formatCreatedAt(DateTime(2026, 11, 2, 18).toIso8601String(), now: now), 'вчера в 18:00');
    expect(formatCreatedAt(DateTime(2026, 11, 18, 18).toIso8601String(), now: now), '18.11.2026 в 18:00');
  });

  test('null and bad', () {
    expect(formatCreatedAt(null), isNull);
    expect(formatCreatedAt('nope'), isNull);
  });
}
