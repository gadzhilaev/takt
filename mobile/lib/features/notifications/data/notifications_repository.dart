import '../../../core/api_client.dart';
import '../../../shared/models/models.dart';

class NotificationsRepository {
  NotificationsRepository(this._api);
  final ApiClient _api;

  Future<List<AppNotification>> list({bool unreadOnly = false}) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/api/v1/notifications',
      queryParameters: {'unread_only': unreadOnly, 'page_size': 50},
    );
    return (res.data?['items'] as List<dynamic>? ?? [])
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markRead(String id) async {
    await _api.dio.post('/api/v1/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _api.dio.post('/api/v1/notifications/read-all');
  }

  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) async {
    await _api.dio.post(
      '/api/v1/notifications/device-token',
      data: {'token': token, 'platform': platform},
    );
  }

  Future<void> unregisterDeviceToken({
    required String token,
    required String platform,
  }) async {
    await _api.dio.delete(
      '/api/v1/notifications/device-token',
      data: {'token': token, 'platform': platform},
    );
  }
}
