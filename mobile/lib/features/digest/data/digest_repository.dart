import '../../../core/api_client.dart';
import 'digest_models.dart';

class DigestRepository {
  DigestRepository(this._api);

  final ApiClient _api;

  Future<Digest> load(String projectId, DigestPeriod period) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/api/v1/projects/$projectId/digest',
      queryParameters: {'period': period.wire},
    );
    return Digest.fromJson(res.data!['digest'] as Map<String, dynamic>);
  }

  Future<bool> setSubscribed(String projectId, bool subscribed) async {
    final res = await _api.dio.put<Map<String, dynamic>>(
      '/api/v1/projects/$projectId/digest-subscription',
      data: {'subscribed': subscribed},
    );
    return res.data?['subscribed'] as bool? ?? subscribed;
  }
}
