import 'package:flutter_test/flutter_test.dart';
import 'package:takt_mobile/core/push/checkin_push.dart';
import 'package:takt_mobile/core/push/fcm_bootstrap.dart';

const _data = <String, dynamic>{
  'kind': 'rhythm_checkin',
  'checkin_id': 'c1',
  'task_id': 't1',
  'task_count': '1',
  'action_token': 'tok-123456789',
  'action_path': '/api/v1/rhythm/push-answer',
};

void main() {
  test('кнопки уведомления → тело push-answer', () {
    expect(pushAnswerBody(_data, CheckinActions.done), {
      'checkin_id': 'c1',
      'task_id': 't1',
      'answer': 'done',
      'token': 'tok-123456789',
    });
    expect(pushAnswerBody(_data, CheckinActions.inProgress)?['answer'], 'in_progress');
    final blocked = pushAnswerBody(_data, CheckinActions.blocked, input: '  ${'я' * 300} ');
    expect(blocked?['answer'], 'blocked');
    expect((blocked?['reason'] as String).length, 280);
    expect(pushAnswerBody(_data, CheckinActions.blocked, input: '  ')!.containsKey('reason'), isFalse);
  });

  test('«Открыть чек-ин» и неполные данные — не ответ', () {
    expect(pushAnswerBody(_data, CheckinActions.open), isNull);
    expect(pushAnswerBody({..._data}..remove('task_id'), CheckinActions.done), isNull);
    expect(pushAnswerBody({..._data}..remove('action_token'), CheckinActions.done), isNull);
  });

  test('push чек-ина открывает экран чек-ина', () {
    expect(isCheckinPush(_data), isTrue);
    expect(FcmBootstrap.routeFromData(_data), '/checkin/c1');
    expect(FcmBootstrap.routeFromData({'kind': 'rhythm_checkin'}), '/checkin');
    expect(FcmBootstrap.routeFromData({'project_id': 'p', 'task_id': 't'}), '/board?project=p&task=t');
  });
}
