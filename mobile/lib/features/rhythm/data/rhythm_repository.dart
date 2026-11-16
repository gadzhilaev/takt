import 'package:flutter/foundation.dart';

import '../../../core/api_client.dart';
import 'rhythm_models.dart';

class RhythmRepository {
  RhythmRepository(this._api);

  final ApiClient _api;

  /// Последний ответ `/current` — баннеры на нескольких экранах без лишних запросов.
  final ValueNotifier<List<Checkin>> current = ValueNotifier(const []);

  Future<List<Checkin>> loadCurrent({String? projectId}) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/api/v1/rhythm/checkins/current',
      queryParameters: projectId == null ? null : {'project_id': projectId},
    );
    final list = (res.data?['checkins'] as List<dynamic>? ?? [])
        .map((e) => Checkin.fromJson(e as Map<String, dynamic>))
        .toList();
    if (projectId == null) current.value = list;
    return list;
  }

  Future<Checkin> get(String id) async {
    final res = await _api.dio.get<Map<String, dynamic>>('/api/v1/rhythm/checkins/$id');
    return Checkin.fromJson(res.data!['checkin'] as Map<String, dynamic>);
  }

  Future<Checkin> answer(String id, List<Map<String, dynamic>> answers) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/api/v1/rhythm/checkins/$id/answer',
      data: {'answers': answers},
    );
    final updated = Checkin.fromJson(res.data!['checkin'] as Map<String, dynamic>);
    current.value = [
      for (final c in current.value)
        if (c.id == updated.id) updated else c,
    ];
    return updated;
  }
}
