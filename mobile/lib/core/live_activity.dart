import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/rhythm/data/rhythm_models.dart';
import '../shared/models/models.dart';

/// Что показать в Live Activity: сегодняшний чек-ин, иначе ближайший срок (≤ 24 ч.).
Map<String, dynamic>? liveActivityPayload({
  required List<Checkin> checkins,
  required List<TaskItem> myTasks,
  DateTime? now,
}) {
  now ??= DateTime.now();
  final c = checkins.where((x) => x.isPending && x.unanswered > 0).firstOrNull;
  if (c != null) {
    final next = c.items.where((i) => i.answer == null).firstOrNull;
    return {
      'kind': 'checkin',
      'title': 'Чек-ин: ${c.unanswered} ${tasksWord(c.unanswered)}',
      'subtitle': next?.title ?? '',
      'answered': c.items.length - c.unanswered,
      'total': c.items.length,
      'project_name': c.projectName ?? '',
      'url': 'takt://checkin/${c.id}',
    };
  }
  TaskItem? nearest;
  DateTime? nearestDue;
  for (final t in myTasks) {
    if (t.isDone || t.dueDate == null) continue;
    final due = DateTime.tryParse(t.dueDate!)?.toLocal();
    if (due == null || due.isBefore(now) || due.difference(now) > const Duration(hours: 24)) {
      continue;
    }
    if (nearestDue == null || due.isBefore(nearestDue)) {
      nearest = t;
      nearestDue = due;
    }
  }
  if (nearest == null || nearestDue == null) return null;
  return {
    'kind': 'deadline',
    'title': nearest.title,
    'subtitle': 'Срок сегодня',
    'answered': 0,
    'total': 0,
    'deadline_ms': nearestDue.millisecondsSinceEpoch,
    'project_name': '',
    'url': 'takt://task/${nearest.id}',
  };
}

/// Live Activity (iOS 16.2+): включает сам пользователь в профиле, по умолчанию выключено.
class LiveActivityController {
  static const _channel = MethodChannel('takt/live_activity');
  static const prefKey = 'takt_live_activity_enabled';

  final ValueNotifier<bool> enabled = ValueNotifier(false);
  bool _supported = false;

  bool get available => !kIsWeb && Platform.isIOS && _supported;

  Future<void> init() async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      _supported = await _channel.invokeMethod<bool>('isSupported') ?? false;
    } catch (_) {
      _supported = false;
    }
    final prefs = await SharedPreferences.getInstance();
    enabled.value = prefs.getBool(prefKey) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    enabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKey, value);
    if (!value) await end();
  }

  Future<void> sync(Map<String, dynamic>? payload) async {
    if (!available) return;
    if (!enabled.value || payload == null) {
      await end();
      return;
    }
    try {
      await _channel.invokeMethod<bool>('show', payload);
    } catch (e) {
      debugPrint('live activity show failed: $e');
    }
  }

  Future<void> end() async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      await _channel.invokeMethod<bool>('end');
    } catch (_) {}
  }
}
