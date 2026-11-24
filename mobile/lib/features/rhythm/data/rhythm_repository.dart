import 'package:flutter/foundation.dart';

import '../../../core/api_client.dart';
import '../../widget_sync/widget_sync.dart';
import 'rhythm_models.dart';

class RhythmRepository {
  RhythmRepository(this._api, {this.widgetSync});

  final ApiClient _api;
  final WidgetSync? widgetSync;

  /// Виджет «Чек-ин» и Live Activity следят за [current].
  void _publish() {
    final payload = checkinWidgetPayload(current.value);
    widgetSync?.publishCheckin(payload);
    onCheckinsChanged?.call(current.value);
  }

  /// Подписка Live Activity (iOS); задаётся в app.dart.
  void Function(List<Checkin> checkins)? onCheckinsChanged;

  /// Последний ответ `/current` — баннеры на нескольких экранах без лишних запросов.
  final ValueNotifier<List<Checkin>> current = ValueNotifier(const []);

  /// Проекты, где можно пройти чек-ин вручную (на сегодня его ещё нет).
  final ValueNotifier<List<String>> startable = ValueNotifier(const []);

  Future<List<Checkin>> loadCurrent({String? projectId}) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/api/v1/rhythm/checkins/current',
      queryParameters: projectId == null ? null : {'project_id': projectId},
    );
    final list = (res.data?['checkins'] as List<dynamic>? ?? [])
        .map((e) => Checkin.fromJson(e as Map<String, dynamic>))
        .toList();
    if (projectId == null) {
      current.value = list;
      startable.value = [
        for (final id in (res.data?['startable_project_ids'] as List<dynamic>? ?? const []))
          '$id',
      ];
      _publish();
    }
    return list;
  }

  Future<Checkin> get(String id) async {
    final res = await _api.dio.get<Map<String, dynamic>>('/api/v1/rhythm/checkins/$id');
    return Checkin.fromJson(res.data!['checkin'] as Map<String, dynamic>);
  }

  /// «Пройти чек-ин сейчас»: сегодняшний чек-ин без push (если уже есть — тот же).
  Future<Checkin> start(String projectId) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/api/v1/rhythm/checkins/start',
      queryParameters: {'project_id': projectId},
    );
    final c = Checkin.fromJson(res.data!['checkin'] as Map<String, dynamic>);
    startable.value = [for (final id in startable.value) if (id != projectId) id];
    current.value = [c, for (final x in current.value) if (x.id != c.id) x];
    _publish();
    return c;
  }

  Future<Checkin> answer(String id, List<Map<String, dynamic>> answers) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/api/v1/rhythm/checkins/$id/answer',
      data: {'answers': answers},
    );
    final updated = Checkin.fromJson(res.data!['checkin'] as Map<String, dynamic>);
    current.value = [
      for (final c in current.value)
        if (c.id == updated.id) updated,
      if (!current.value.any((c) => c.id == updated.id)) updated,
    ];
    _publish();
    return updated;
  }
}
