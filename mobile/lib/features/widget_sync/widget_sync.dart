import 'dart:convert';

import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config.dart';
import '../../shared/models/models.dart';

/// Publishes a sanitized board snapshot for home-screen widgets.
/// Never writes access/refresh tokens into the shared widget store.
class WidgetSync {
  static const prefsKey = 'takt_widget_snapshot_v3';

  Future<void> publishBoard({
    required Project project,
    required List<StatusColumn> columns,
    required List<TaskItem> tasks,
    required String currentUserId,
    List<Project> allProjects = const [],
  }) async {
    final statusName = {for (final c in columns) c.id: c.name};
    final mine = selectOpenTasks(
      tasks: tasks,
      columns: columns,
      currentUserId: currentUserId,
      mode: WidgetTaskMode.mine,
    );
    final all = selectOpenTasks(
      tasks: tasks,
      columns: columns,
      currentUserId: currentUserId,
      mode: WidgetTaskMode.all,
    );

    Map<String, dynamic> tasksPayload(List<TaskItem> list) => {
          'open_count': list.length,
          'urgent_count': list.where((t) => t.priority == 'urgent').length,
          'tasks': list.take(8).map((t) {
            final json = t.toWidgetJson();
            json['status_name'] = statusName[t.statusId] ?? t.statusName ?? '';
            return json;
          }).toList(),
        };

    final projects = allProjects.isNotEmpty ? allProjects : [project];
    final catalog = projects
        .map((p) => {'id': p.id, 'name': p.name})
        .toList(growable: false);

    // Merge into previous by_project cache so other widget instances keep data.
    final previous = await _readLocalSnapshot();
    final byProject = <String, dynamic>{};
    final prevBy = previous?['by_project'];
    if (prevBy is Map<String, dynamic>) {
      byProject.addAll(Map<String, dynamic>.from(prevBy));
    }

    byProject[project.id] = {
      'project_name': project.name,
      'mine': tasksPayload(mine),
      'all': tasksPayload(all),
    };

    final snapshot = <String, dynamic>{
      'v': 3,
      'logged_in': true,
      'user_id': currentUserId,
      'default_project_id': project.id,
      'project_id': project.id,
      'project_name': project.name,
      // Backward-compatible primary view = mine of current project.
      'open_count': mine.length,
      'urgent_count': mine.where((t) => t.priority == 'urgent').length,
      'tasks': (byProject[project.id] as Map)['mine']['tasks'],
      'projects': catalog,
      'by_project': byProject,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'accent': '#315F72',
    };

    await _writeSnapshot(snapshot);
  }

  Future<void> clearOnLogout() async {
    final snapshot = <String, dynamic>{
      'v': 3,
      'logged_in': false,
      'user_id': '',
      'default_project_id': '',
      'project_id': '',
      'project_name': '',
      'open_count': 0,
      'urgent_count': 0,
      'tasks': <Map<String, dynamic>>[],
      'projects': <Map<String, dynamic>>[],
      'by_project': <String, dynamic>{},
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'accent': '#315F72',
    };
    await _writeSnapshot(snapshot);
  }

  Future<Map<String, dynamic>?> _readLocalSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey) ?? prefs.getString('takt_widget_snapshot_v2');
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  Future<void> _writeSnapshot(Map<String, dynamic> snapshot) async {
    final encoded = jsonEncode(snapshot);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, encoded);
    await prefs.remove('takt_widget_snapshot_v1');
    await prefs.remove('takt_widget_snapshot_v2');

    await HomeWidget.setAppGroupId(AppConfig.appGroupId);
    await HomeWidget.saveWidgetData<String>('snapshot', encoded);
    await HomeWidget.saveWidgetData<String>(
      'project_name',
      snapshot['project_name'] as String? ?? '',
    );
    await HomeWidget.saveWidgetData<int>(
      'open_count',
      snapshot['open_count'] as int? ?? 0,
    );
    await HomeWidget.saveWidgetData<int>(
      'urgent_count',
      snapshot['urgent_count'] as int? ?? 0,
    );
    await HomeWidget.saveWidgetData<bool>(
      'logged_in',
      snapshot['logged_in'] as bool? ?? false,
    );
    await HomeWidget.updateWidget(
      name: AppConfig.widgetNameAndroid,
      iOSName: AppConfig.widgetNameIos,
      qualifiedAndroidName: 'ru.gadzhilaev.takt.${AppConfig.widgetNameAndroid}',
    );
  }

  /// Open tasks sorted urgent → high → medium, then position.
  static List<TaskItem> selectOpenTasks({
    required List<TaskItem> tasks,
    required List<StatusColumn> columns,
    required String currentUserId,
    required WidgetTaskMode mode,
  }) {
    final doneIds = columns.where((c) => c.isDone).map((c) => c.id).toSet();
    final filtered = tasks.where((t) {
      if (t.isDone || doneIds.contains(t.statusId)) return false;
      if (mode == WidgetTaskMode.mine) {
        if (currentUserId.isEmpty) return false;
        return t.assignees.any((a) => a.id == currentUserId);
      }
      return true;
    }).toList();
    filtered.sort((a, b) {
      final pa = priorityRank(a.priority);
      final pb = priorityRank(b.priority);
      if (pa != pb) return pa.compareTo(pb);
      return a.position.compareTo(b.position);
    });
    return filtered;
  }

  /// Backward-compatible alias.
  static List<TaskItem> selectMyOpenTasks({
    required List<TaskItem> tasks,
    required List<StatusColumn> columns,
    required String currentUserId,
  }) =>
      selectOpenTasks(
        tasks: tasks,
        columns: columns,
        currentUserId: currentUserId,
        mode: WidgetTaskMode.mine,
      );

  static int priorityRank(String p) {
    switch (p) {
      case 'urgent':
        return 0;
      case 'high':
        return 1;
      default:
        return 2;
    }
  }

  /// Maps any widget / push / platform URI to an in-app go_router path.
  /// Never returns a `takt://…` string.
  static String routeFromUri(Uri uri) {
    final normalized = _normalize(uri);
    final host = normalized.host;
    final segments = normalized.segments;
    final q = normalized.query;

    if (host == 'task-edit' ||
        (host.isEmpty && segments.isNotEmpty && segments.first == 'task-edit')) {
      final taskId = q['id'] ??
          (host == 'task-edit'
              ? (segments.isNotEmpty ? segments.first : null)
              : (segments.length > 1 ? segments[1] : null));
      if (taskId != null && taskId.isNotEmpty) return '/task-edit/$taskId';
      return '/board';
    }

    if (host == 'task' || (host.isEmpty && segments.isNotEmpty && segments.first == 'task')) {
      final taskId = q['id'] ??
          (host == 'task'
              ? (segments.isNotEmpty ? segments.first : null)
              : (segments.length > 1 ? segments[1] : null));
      if (taskId != null && taskId.isNotEmpty) return '/task/$taskId';
      return '/my-tasks';
    }

    if (host == 'board' || (segments.isNotEmpty && segments.first == 'board')) {
      final projectId = q['project'];
      final taskId = q['task'];
      if (taskId != null && taskId.isNotEmpty) return '/task/$taskId';
      final params = <String>[];
      if (projectId != null && projectId.isNotEmpty) params.add('project=$projectId');
      final mode = q['mode'];
      if (mode == 'mine' || mode == 'my') return '/my-tasks';
      return params.isEmpty ? '/board' : '/board?${params.join('&')}';
    }

    if (host == 'my-tasks' || host == 'profile' || host == 'notifications') {
      return '/$host';
    }
    if (segments.isNotEmpty &&
        (segments.first == 'my-tasks' ||
            segments.first == 'profile' ||
            segments.first == 'notifications')) {
      return '/${segments.first}';
    }

    // Already an in-app path.
    if (uri.path.startsWith('/') && uri.scheme.isEmpty) {
      final path = uri.path.replaceAll(RegExp(r'/+$'), '');
      if (path.isEmpty) return '/board';
      return uri.hasQuery ? '$path?${uri.query}' : path;
    }

    return '/board';
  }

  /// Accepts [Uri], raw string, or go_router [GoRouterState] location.
  static String routeFromAny(Object? raw) {
    if (raw == null) return '/board';
    if (raw is Uri) return routeFromUri(raw);
    final s = raw.toString().trim();
    if (s.isEmpty || s == '/') return '/board';
    if (s.startsWith('/')) {
      final path = s.split('?').first.replaceAll(RegExp(r'/+$'), '');
      if (path.isEmpty) return '/board';
      return s.contains('?') ? '$path?${s.split('?').skip(1).join('?')}' : path;
    }
    try {
      return routeFromUri(Uri.parse(s));
    } catch (_) {
      return '/board';
    }
  }

  static ({String host, List<String> segments, Map<String, String> query}) _normalize(Uri uri) {
    var host = uri.host.toLowerCase();
    var segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    // takt:///board/… → host empty, path /board
    if (host.isEmpty && segments.isNotEmpty) {
      host = segments.first.toLowerCase();
      segments = segments.skip(1).toList();
    }
    return (host: host, segments: segments, query: uri.queryParameters);
  }
}

enum WidgetTaskMode { mine, all }
