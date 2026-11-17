import 'package:flutter_test/flutter_test.dart';
import 'package:takt_mobile/core/live_activity.dart';
import 'package:takt_mobile/features/rhythm/data/rhythm_models.dart';
import 'package:takt_mobile/shared/models/models.dart';

TaskItem _task(String id, {String? due, String? closed}) => TaskItem(
      id: id,
      title: 'Задача $id',
      statusId: 's',
      priority: 'medium',
      position: 0,
      dueDate: due,
      closedAt: closed,
    );

void main() {
  final now = DateTime(2026, 11, 17, 10);

  test('чек-ин важнее срока', () {
    final c = Checkin.fromJson({
      'id': 'c1',
      'status': 'pending',
      'project': {'id': 'p', 'name': 'Колледж'},
      'items': [
        {'task_id': 'a', 'title': 'A', 'answer': 'done'},
        {'task_id': 'b', 'title': 'B'},
      ],
    });
    final p = liveActivityPayload(checkins: [c], myTasks: const [], now: now)!;
    expect(p['kind'], 'checkin');
    expect(p['title'], 'Чек-ин: 1 задача');
    expect(p['subtitle'], 'B');
    expect([p['answered'], p['total']], [1, 2]);
    expect(p['url'], 'takt://checkin/c1');
  });

  test('без чек-ина — ближайший срок в пределах суток', () {
    final p = liveActivityPayload(checkins: const [], now: now, myTasks: [
      _task('far', due: now.add(const Duration(days: 3)).toIso8601String()),
      _task('soon', due: now.add(const Duration(hours: 5)).toIso8601String()),
      _task('sooner-done', due: now.add(const Duration(hours: 1)).toIso8601String(), closed: 'x'),
      _task('past', due: now.subtract(const Duration(hours: 1)).toIso8601String()),
    ])!;
    expect(p['kind'], 'deadline');
    expect(p['url'], 'takt://task/soon');
    expect(liveActivityPayload(checkins: const [], myTasks: const [], now: now), isNull);
  });

  test('данные для виджета: первый неотвеченный чек-ин с токеном', () {
    final c = Checkin.fromJson({
      'id': 'c1',
      'status': 'pending',
      'date': '2026-11-17',
      'project': {'id': 'p', 'name': 'Колледж'},
      'action_token': 'tok',
      'items': [
        {'task_id': 'a', 'title': 'A', 'priority': 'high'},
      ],
    });
    final w = checkinWidgetPayload([c])!;
    expect(w['token'], 'tok');
    expect(w['action_path'], '/api/v1/rhythm/push-answer');
    expect((w['tasks'] as List).single, {'id': 'a', 'title': 'A', 'priority': 'high', 'answer': null});
    expect(checkinWidgetPayload(const []), isNull);
  });
}
