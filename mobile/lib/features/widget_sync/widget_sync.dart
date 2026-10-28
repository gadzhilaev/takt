import 'dart:convert';

import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config.dart';
import '../../shared/models/models.dart';

/// Publishes a sanitized board snapshot for home-screen widgets.
/// Never writes access/refresh tokens into the shared widget store.
class WidgetSync {
  static const _prefsKey = 'takt_widget_snapshot_v1';

  Future<void> publishBoard({
    required Project project,
    required List<StatusColumn> columns,
    required List<TaskItem> tasks,
  }) async {
    final doneIds = columns.where((c) => c.isDone).map((c) => c.id).toSet();
    final open = tasks.where((t) => !doneIds.contains(t.statusId) && !t.isDone).toList();
    open.sort((a, b) {
      final pa = _priorityRank(a.priority);
      final pb = _priorityRank(b.priority);
      if (pa != pb) return pa.compareTo(pb);
      return a.position.compareTo(b.position);
    });

    final snapshot = {
      'project_id': project.id,
      'project_name': project.name,
      'open_count': open.length,
      'tasks': open.take(7).map((t) => t.toWidgetJson()).toList(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'accent': '#315F72',
    };

    final encoded = jsonEncode(snapshot);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, encoded);

    await HomeWidget.setAppGroupId(AppConfig.appGroupId);
    await HomeWidget.saveWidgetData<String>('snapshot', encoded);
    await HomeWidget.saveWidgetData<String>('project_name', project.name);
    await HomeWidget.saveWidgetData<int>('open_count', open.length);
    await HomeWidget.updateWidget(
      name: AppConfig.widgetNameAndroid,
      iOSName: AppConfig.widgetNameIos,
      qualifiedAndroidName: 'ru.gadzhilaev.takt.${AppConfig.widgetNameAndroid}',
    );
  }

  Future<void> clearOnLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    await HomeWidget.setAppGroupId(AppConfig.appGroupId);
    await HomeWidget.saveWidgetData<String>('snapshot', '');
    await HomeWidget.saveWidgetData<String>('project_name', '');
    await HomeWidget.saveWidgetData<int>('open_count', 0);
    await HomeWidget.updateWidget(
      name: AppConfig.widgetNameAndroid,
      iOSName: AppConfig.widgetNameIos,
      qualifiedAndroidName: 'ru.gadzhilaev.takt.${AppConfig.widgetNameAndroid}',
    );
  }

  int _priorityRank(String p) {
    switch (p) {
      case 'urgent':
        return 0;
      case 'high':
        return 1;
      default:
        return 2;
    }
  }
}
