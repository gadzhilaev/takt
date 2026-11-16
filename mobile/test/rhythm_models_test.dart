import 'package:flutter_test/flutter_test.dart';
import 'package:takt_mobile/features/rhythm/data/rhythm_models.dart';
import 'package:takt_mobile/shared/models/models.dart';

Checkin _checkin({String status = 'pending'}) => Checkin.fromJson({
      'id': 'c1',
      'status': status,
      'project': {'id': 'p', 'name': 'Колледж'},
      'items': [
        {'task_id': 'a', 'title': 'A', 'priority': 'high'},
        {'task_id': 'b', 'title': 'B', 'answer': 'in_progress'},
        {'task_id': 'c', 'title': 'C'},
      ],
    });

void main() {
  test('ответ: только новые, причина обрезается до 280', () {
    final c = _checkin();
    final choices = initialChoices(c)
      ..['a'] = const CheckinChoice(CheckinAnswer.done)
      ..['c'] = CheckinChoice(CheckinAnswer.blocked, '  ${'x' * 300} ');
    final out = buildCheckinAnswers(c, choices);
    expect(out.map((e) => e['task_id']), ['a', 'c']);
    expect(out.first, {'task_id': 'a', 'answer': 'done'});
    expect((out.last['reason'] as String).length, 280);
  });

  test('застрял без причины — без поля reason', () {
    final out = buildCheckinAnswers(_checkin(), {'a': const CheckinChoice(CheckinAnswer.blocked, ' ')});
    expect(out, [
      {'task_id': 'a', 'answer': 'blocked'},
    ]);
  });

  test('баннер и склонение', () {
    expect(checkinBannerText([_checkin()]), 'Чек-ин на сегодня · 2 задачи');
    expect(checkinBannerText([_checkin(status: 'answered')]), isNull);
    expect([1, 2, 5, 11, 21].map(tasksWord), ['задача', 'задачи', 'задач', 'задач', 'задача']);
  });

  test('«Застряла» из JSON и снятие при переносе в другой столбец', () {
    final t = TaskItem.fromJson({
      'id': 't',
      'title': 'T',
      'status_id': 's1',
      'priority': 'medium',
      'position': 0,
      'blocked_at': '2026-11-16T10:00:00Z',
      'blocked_reason': 'Ждём подпись',
      'blocked_by': {'name': 'Анна'},
    });
    expect(t.isBlocked, isTrue);
    expect(t.blockedByName, 'Анна');
    expect(t.copyWith(title: 'T2').isBlocked, isTrue);
    final moved = t.copyWith(statusId: 's2');
    expect(moved.isBlocked, isFalse);
    expect(moved.blockedReason, isNull);
  });

  test('настройки ритма проекта', () {
    final p = Project.fromJson({
      'id': 'p',
      'name': 'P',
      'rhythm': {'enabled': true, 'time': '09:30', 'timezone': 'Asia/Omsk', 'days': [1, 3]},
    });
    expect(p.rhythm, const RhythmSettings(time: '09:30', timezone: 'Asia/Omsk', days: [1, 3]));
    expect(Project.fromJson({'id': 'p', 'name': 'P'}).rhythm.enabled, isFalse);
  });

  test('«Пройти чек-ин сейчас»: только без активного чек-ина, текущий проект в приоритете', () {
    expect(checkinStartProjectId(const [], ['p1', 'p2'], currentProjectId: 'p2'), 'p2');
    expect(checkinStartProjectId(const [], ['p1', 'p2'], currentProjectId: 'x'), 'p1');
    expect(checkinStartProjectId(const [], const []), isNull);
    expect(checkinStartProjectId([_checkin()], ['p1']), isNull);
  });
}
