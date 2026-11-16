import 'package:flutter_test/flutter_test.dart';
import 'package:takt_mobile/features/digest/data/digest_models.dart';

void main() {
  test('парсинг сводки', () {
    final d = Digest.fromJson({
      'project': {'id': 'p', 'name': 'Колледж'},
      'period': {'kind': 'week', 'start': '2026-11-11', 'end': '2026-11-17', 'timezone': 'Europe/Moscow'},
      'summary': {'done': 3, 'stuck': 1, 'overdue': 2, 'due_soon': 1, 'participation': 75},
      'done': [],
      'stuck': [
        {'task_id': 't', 'title': 'Проектор', 'priority': 'high', 'assignees': ['Анна'],
          'reason': 'Ждём HDMI', 'blocked_by': 'Артём', 'days_stuck': 2},
      ],
      'overdue': [],
      'due_soon': [],
      'bottleneck': {'name': 'В работе', 'avg_hours': 30.0, 'stays': 2, 'tasks': []},
      'rhythm': {
        'enabled': true, 'total': 4, 'answered': 3, 'participation': 75,
        'members_without_answer': [{'user_id': 'u', 'name': 'Орлов', 'total': 3, 'missed': 1}],
      },
      'viewer': {'is_admin': true, 'subscribed': true},
    });
    expect(d.period, DigestPeriod.week);
    expect(d.stuckTasks.single.reason, 'Ждём HDMI');
    expect(d.bottleneckName, 'В работе');
    expect(d.missed.single, const DigestMissed(name: 'Орлов', missed: 1, total: 3));
    expect(d.isAdmin, isTrue);
  });

  test('форматирование', () {
    expect(digestDaysLabel(0), 'меньше дня');
    expect(formatDigestHours(0.4), '< 1 ч.');
    expect(formatDigestHours(30), '1 д. 6 ч.');
    expect(formatDigestHours(48), '2 д.');
    expect([1, 2, 5, 11, 21].map(digestDaysLabel), ['1 день', '2 дня', '5 дней', '11 дней', '21 день']);
    expect(digestPeriodLabel('2026-11-11', '2026-11-17'), '11.11 — 17.11');
    expect(digestParticipation(null), '—');
  });
}
