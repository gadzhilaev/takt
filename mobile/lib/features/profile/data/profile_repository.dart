import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../shared/models/models.dart';

class ProfileRepository {
  ProfileRepository(this._api);
  final ApiClient _api;

  Future<UserProfile> update({String? name, String? email}) async {
    final res = await _api.dio.patch<Map<String, dynamic>>(
      '/api/v1/users/me',
      data: {
        if (name != null) 'name': name.trim(),
        if (email != null) 'email': email.trim(),
      },
    );
    return UserProfile.fromJson(res.data!['user'] as Map<String, dynamic>);
  }

  Future<String?> uploadAvatar(File file) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: file.uri.pathSegments.last),
    });
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/api/v1/users/me/avatar',
      data: form,
    );
    return res.data?['avatar_url'] as String?;
  }

  Future<void> deleteAvatar() async {
    await _api.dio.delete('/api/v1/users/me/avatar');
  }
}
