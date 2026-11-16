import 'package:flutter_test/flutter_test.dart';
import 'package:takt_mobile/features/profile/data/account_delete_preview.dart';

void main() {
  test('строки последствий: удаление, передача прав, выход', () {
    final p = AccountDeletePreview.fromJson({
      'can_delete': true,
      'blocked': null,
      'projects': [
        {'id': '1', 'name': 'Общий', 'action': 'leave', 'new_admin': null},
        {
          'id': '2',
          'name': 'Команда',
          'action': 'transfer',
          'new_admin': {'id': 'u', 'name': 'Иванова Анна'},
        },
        {'id': '3', 'name': 'Личный', 'action': 'delete', 'new_admin': null},
      ],
    });
    expect(p.canDelete, isTrue);
    expect(p.lines, [
      'Проект «Личный» будет удалён.',
      'Права администратора в проекте «Команда» перейдут к Иванова Анна.',
      'Вы выйдете из проекта «Общий», данные команды сохранятся.',
    ]);
  });

  test('блокировка last_super_admin', () {
    final p = AccountDeletePreview.fromJson({
      'can_delete': false,
      'blocked': {'code': 'last_super_admin', 'message': 'Нельзя удалить'},
      'projects': [],
    });
    expect(p.canDelete, isFalse);
    expect(p.blockedMessage, 'Нельзя удалить');
    expect(p.lines, isEmpty);
  });
}
