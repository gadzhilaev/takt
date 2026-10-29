import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt_mobile/shared/models/models.dart';
import 'package:takt_mobile/shared/widgets/task_card.dart';
import 'package:takt_mobile/shared/widgets/user_avatar.dart';

void main() {
  testWidgets('TaktUserAvatar is circular and shows initials', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: TaktUserAvatar(name: 'Иван Петров', size: 32)),
        ),
      ),
    );
    expect(find.text('ИП'), findsOneWidget);
    final size = tester.getSize(find.byType(TaktUserAvatar));
    expect(size.width, 32);
    expect(size.height, 32);
  });

  testWidgets('TaktTaskCard clips stripe inside rounded card', (tester) async {
    const task = TaskItem(
      id: '1',
      title: 'Тестовая задача с длинным названием для двух строк',
      statusId: 's',
      priority: 'urgent',
      position: 0,
      description: 'Описание задачи',
      assignees: [TaskAssignee(id: 'u1', name: 'Анна')],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: TaktTaskCard(task: task, onTap: () {}),
          ),
        ),
      ),
    );
    expect(find.textContaining('Тестовая задача'), findsOneWidget);
    expect(find.text('Срочно'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('taktInitials handles single and multi names', () {
    expect(taktInitials('Алексей'), 'АЛ');
    expect(taktInitials('Мария Иванова'), 'МИ');
    expect(taktInitials(''), '?');
  });
}
