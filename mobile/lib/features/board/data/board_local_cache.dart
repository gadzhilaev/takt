import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/models/models.dart';

/// Disk cache for project hub + last-known boards (stale-while-revalidate).
class BoardLocalCache {
  static const _projectsKey = 'takt_cache_projects_v1';
  static String _boardKey(String projectId) => 'takt_cache_board_v1_$projectId';

  Future<List<Project>> loadProjects() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_projectsKey);
      if (raw == null || raw.isEmpty) return const [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Project.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveProjects(List<Project> projects) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(projects.map((p) => p.toJson()).toList());
      await prefs.setString(_projectsKey, raw);
      await _pruneBoardKeys(prefs, projects.map((p) => p.id).toSet());
    } catch (_) {
      /* ignore cache write failures */
    }
  }

  /// Полная очистка локального кэша (logout / сервер опустел).
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('takt_cache_') || k == 'takt_last_project_id').toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {
      /* ignore */
    }
  }

  Future<void> _pruneBoardKeys(SharedPreferences prefs, Set<String> keepIds) async {
    final prefix = 'takt_cache_board_v1_';
    for (final k in prefs.getKeys().where((k) => k.startsWith(prefix)).toList()) {
      final id = k.substring(prefix.length);
      if (!keepIds.contains(id)) {
        await prefs.remove(k);
      }
    }
  }

  Future<({Project project, List<StatusColumn> columns, List<TaskItem> tasks})?> loadBoard(
    String projectId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_boardKey(projectId));
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final project = Project.fromJson(map['project'] as Map<String, dynamic>);
      final columns = (map['columns'] as List<dynamic>? ?? [])
          .map((e) => StatusColumn.fromJson(e as Map<String, dynamic>))
          .toList();
      final tasks = (map['tasks'] as List<dynamic>? ?? [])
          .map((e) => TaskItem.fromJson(e as Map<String, dynamic>))
          .toList();
      if (columns.isEmpty) return null;
      return (project: project, columns: columns, tasks: tasks);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveBoard({
    required Project project,
    required List<StatusColumn> columns,
    required List<TaskItem> tasks,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode({
        'project': project.toJson(),
        'columns': columns.map((c) => c.toJson()).toList(),
        'tasks': tasks.map((t) => t.toJson()).toList(),
      });
      await prefs.setString(_boardKey(project.id), raw);
    } catch (_) {
      /* ignore */
    }
  }
}
