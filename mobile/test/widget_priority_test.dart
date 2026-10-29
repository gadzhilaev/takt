import 'package:flutter_test/flutter_test.dart';
import 'package:takt_mobile/features/widget_sync/widget_sync.dart';
import 'package:takt_mobile/shared/models/models.dart';

void main() {
  const me = 'user-me';
  const other = 'user-other';

  StatusColumn col({required String id, required bool isDone}) => StatusColumn(
        id: id,
        name: id,
        position: 0,
        isDone: isDone,
      );

  TaskItem task({
    required String id,
    required String priority,
    required double position,
    required String statusId,
    List<String> assigneeIds = const [],
    String? closedAt,
  }) =>
      TaskItem(
        id: id,
        title: id,
        statusId: statusId,
        priority: priority,
        position: position,
        closedAt: closedAt,
        assignees: assigneeIds.map((a) => TaskAssignee(id: a, name: a)).toList(),
      );

  final columns = [col(id: 'todo', isDone: false), col(id: 'done', isDone: true)];

  group('selectOpenTasks mine', () {
    test('urgent then high then medium, stable by position', () {
      final tasks = [
        task(id: '1', priority: 'medium', position: 10, statusId: 'todo', assigneeIds: [me]),
        task(id: '2', priority: 'urgent', position: 20, statusId: 'todo', assigneeIds: [me]),
        task(id: '3', priority: 'high', position: 5, statusId: 'todo', assigneeIds: [me]),
        task(id: '4', priority: 'urgent', position: 1, statusId: 'todo', assigneeIds: [me]),
      ];
      final mine = WidgetSync.selectOpenTasks(
        tasks: tasks,
        columns: columns,
        currentUserId: me,
        mode: WidgetTaskMode.mine,
      );
      expect(mine.map((t) => t.id).toList(), ['4', '2', '3', '1']);
    });

    test('only current user assignees, exclude done', () {
      final tasks = [
        task(id: 'mine', priority: 'medium', position: 1, statusId: 'todo', assigneeIds: [me, other]),
        task(id: 'theirs', priority: 'urgent', position: 0, statusId: 'todo', assigneeIds: [other]),
        task(id: 'done-col', priority: 'urgent', position: 0, statusId: 'done', assigneeIds: [me]),
        task(
          id: 'closed',
          priority: 'high',
          position: 0,
          statusId: 'todo',
          assigneeIds: [me],
          closedAt: '2026-01-01',
        ),
        task(id: 'unassigned', priority: 'high', position: 0, statusId: 'todo'),
      ];
      final mine = WidgetSync.selectOpenTasks(
        tasks: tasks,
        columns: columns,
        currentUserId: me,
        mode: WidgetTaskMode.mine,
      );
      expect(mine.map((t) => t.id).toList(), ['mine']);
    });

    test('empty user id yields empty list', () {
      final tasks = [
        task(id: '1', priority: 'urgent', position: 0, statusId: 'todo', assigneeIds: [me]),
      ];
      expect(
        WidgetSync.selectOpenTasks(
          tasks: tasks,
          columns: columns,
          currentUserId: '',
          mode: WidgetTaskMode.mine,
        ),
        isEmpty,
      );
    });
  });

  group('selectOpenTasks all', () {
    test('includes other assignees and unassigned, excludes done', () {
      final tasks = [
        task(id: 'mine', priority: 'medium', position: 2, statusId: 'todo', assigneeIds: [me]),
        task(id: 'theirs', priority: 'urgent', position: 0, statusId: 'todo', assigneeIds: [other]),
        task(id: 'open', priority: 'high', position: 1, statusId: 'todo'),
        task(id: 'done', priority: 'urgent', position: 0, statusId: 'done', assigneeIds: [me]),
      ];
      final all = WidgetSync.selectOpenTasks(
        tasks: tasks,
        columns: columns,
        currentUserId: me,
        mode: WidgetTaskMode.all,
      );
      expect(all.map((t) => t.id).toList(), ['theirs', 'open', 'mine']);
    });

    test('mine and all counts differ for mixed assignees', () {
      final tasks = [
        task(id: 'a', priority: 'medium', position: 0, statusId: 'todo', assigneeIds: [me]),
        task(id: 'b', priority: 'medium', position: 1, statusId: 'todo', assigneeIds: [other]),
        task(id: 'c', priority: 'urgent', position: 2, statusId: 'todo'),
      ];
      final mine = WidgetSync.selectOpenTasks(
        tasks: tasks,
        columns: columns,
        currentUserId: me,
        mode: WidgetTaskMode.mine,
      );
      final all = WidgetSync.selectOpenTasks(
        tasks: tasks,
        columns: columns,
        currentUserId: me,
        mode: WidgetTaskMode.all,
      );
      expect(mine.length, 1);
      expect(all.length, 3);
      expect(all.where((t) => t.priority == 'urgent').length, 1);
    });
  });

  group('deep links', () {
    test('routeFromUri maps task and board', () {
      expect(
        WidgetSync.routeFromUri(Uri.parse('takt://task?id=abc&project=p1')),
        '/task/abc',
      );
      expect(
        WidgetSync.routeFromUri(Uri.parse('takt://board?project=p1')),
        '/board?project=p1',
      );
      expect(
        WidgetSync.routeFromUri(Uri.parse('takt://board/?project=p1')),
        '/board?project=p1',
      );
      expect(
        WidgetSync.routeFromUri(Uri.parse('takt://my-tasks')),
        '/my-tasks',
      );
    });

    test('routeFromAny never returns takt:// and maps bare /', () {
      expect(WidgetSync.routeFromAny('takt://board/?project=x'), '/board?project=x');
      expect(WidgetSync.routeFromAny('/'), '/board');
      expect(WidgetSync.routeFromAny(null), '/board');
      expect(WidgetSync.routeFromAny(''), '/board');
      expect(WidgetSync.routeFromAny('/task/abc'), '/task/abc');
      expect(WidgetSync.routeFromAny(Uri.parse('takt://task?id=z')), '/task/z');
      expect(WidgetSync.routeFromAny('takt://board/?project=x').startsWith('takt:'), isFalse);
    });

    test('board mode=mine maps to my-tasks', () {
      expect(
        WidgetSync.routeFromUri(Uri.parse('takt://board?mode=mine&project=p1')),
        '/my-tasks',
      );
    });

    test('task-edit maps to in-app edit path', () {
      expect(
        WidgetSync.routeFromUri(Uri.parse('takt://task-edit/abc')),
        '/task-edit/abc',
      );
      expect(
        WidgetSync.routeFromUri(Uri.parse('takt://task-edit?id=abc')),
        '/task-edit/abc',
      );
    });
  });
}
