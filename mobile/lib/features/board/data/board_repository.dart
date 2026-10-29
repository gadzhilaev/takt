import '../../../core/api_client.dart';
import '../../../shared/models/models.dart';

class BoardRepository {
  BoardRepository(this._api);

  final ApiClient _api;

  /// Tasks assigned to the current user across accessible projects (`mine=true`).
  Future<List<TaskItem>> listMyTasks({bool includeDone = true}) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/api/v1/tasks',
      queryParameters: {
        'mine': true,
        'page_size': 200,
        'include_archived': false,
      },
    );
    final tasks = (res.data?['items'] as List<dynamic>? ?? [])
        .map((e) => TaskItem.fromJson(e as Map<String, dynamic>))
        .toList();
    if (includeDone) return tasks;
    return tasks.where((t) => !t.isDone).toList();
  }

  Future<TaskItem> getTask(String taskId) async {
    final res = await _api.dio.get<Map<String, dynamic>>('/api/v1/tasks/$taskId');
    final raw = res.data?['task'] as Map<String, dynamic>? ?? res.data!;
    return TaskItem.fromJson(raw);
  }

  Future<({List<StatusColumn> columns, List<TaskItem> tasks})> loadBoard(String projectId) async {
    final projectRes = await _api.dio.get<Map<String, dynamic>>('/api/v1/projects/$projectId');
    final project = projectRes.data!['project'] as Map<String, dynamic>;
    final columnsRaw = project['statuses'] as List<dynamic>? ??
        project['columns'] as List<dynamic>? ??
        [];

    List<StatusColumn> columns;
    if (columnsRaw.isNotEmpty) {
      columns = columnsRaw.map((e) => StatusColumn.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      final st = await _api.dio.get<Map<String, dynamic>>(
        '/api/v1/settings/statuses',
        queryParameters: {'project_id': projectId},
      );
      columns = (st.data?['items'] as List<dynamic>? ?? [])
          .map((e) => StatusColumn.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    columns.sort((a, b) => a.position.compareTo(b.position));

    final tasksRes = await _api.dio.get<Map<String, dynamic>>(
      '/api/v1/tasks',
      queryParameters: {'project_id': projectId, 'page_size': 200},
    );
    final tasks = (tasksRes.data?['items'] as List<dynamic>? ?? [])
        .map((e) => TaskItem.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    return (columns: columns, tasks: tasks);
  }

  Future<TaskItem> createTask({
    required String projectId,
    required String statusId,
    required String title,
    String? description,
    String priority = 'medium',
    List<String> assigneeIds = const [],
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/api/v1/tasks',
      data: {
        'title': title.trim(),
        'description': description,
        'status_id': statusId,
        'project_id': projectId,
        'priority': priority,
        'assignee_ids': assigneeIds,
        'label_names': <String>[],
      },
    );
    return TaskItem.fromJson(res.data!['task'] as Map<String, dynamic>);
  }

  Future<TaskItem> updateTask({
    required String taskId,
    String? title,
    String? description,
    String? priority,
    String? statusId,
    List<String>? assigneeIds,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title.trim();
    if (description != null) body['description'] = description;
    if (priority != null) body['priority'] = priority;
    if (statusId != null) body['status_id'] = statusId;
    if (assigneeIds != null) body['assignee_ids'] = assigneeIds;
    final res = await _api.dio.patch<Map<String, dynamic>>('/api/v1/tasks/$taskId', data: body);
    return TaskItem.fromJson(res.data!['task'] as Map<String, dynamic>);
  }

  Future<TaskItem> moveTask({
    required String taskId,
    required String statusId,
    required double position,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/api/v1/tasks/$taskId/move',
      data: {'status_id': statusId, 'position': position},
    );
    return TaskItem.fromJson(res.data!['task'] as Map<String, dynamic>);
  }

  Future<void> deleteTask(String taskId) async {
    await _api.dio.delete('/api/v1/tasks/$taskId');
  }

  Future<StatusColumn> createColumn({
    required String projectId,
    required String name,
    String color = '#607FA4',
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/api/v1/settings/statuses',
      data: {
        'project_id': projectId,
        'name': name.trim(),
        'color': color,
        'is_done': false,
      },
    );
    return StatusColumn.fromJson(res.data!['status'] as Map<String, dynamic>? ?? res.data!);
  }

  Future<void> renameColumn({required String statusId, required String name}) async {
    await _api.dio.patch(
      '/api/v1/settings/statuses/$statusId',
      data: {'name': name.trim()},
    );
  }

  Future<void> deleteColumn({
    required String statusId,
    required String moveToStatusId,
  }) async {
    await _api.dio.delete(
      '/api/v1/settings/statuses/$statusId',
      queryParameters: {'move_to_status_id': moveToStatusId},
    );
  }
}
