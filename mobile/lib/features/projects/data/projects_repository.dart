import '../../../core/api_client.dart';
import '../../../shared/models/models.dart';

class ProjectsRepository {
  ProjectsRepository(this._api);

  final ApiClient _api;

  Future<List<Project>> listProjects() async {
    final res = await _api.dio.get<Map<String, dynamic>>('/api/v1/projects');
    final items = res.data?['items'] as List<dynamic>? ?? [];
    return items.map((e) => Project.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Project> getProject(String id) async {
    final res = await _api.dio.get<Map<String, dynamic>>('/api/v1/projects/$id');
    return Project.fromJson(res.data!['project'] as Map<String, dynamic>);
  }

  Future<Project> createProject({required String name, String? description}) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/api/v1/projects',
      data: {
        'name': name.trim(),
        'description': description,
        'color': '#315F72',
        'icon': 'folder',
        'member_ids': <String>[],
      },
    );
    return Project.fromJson(res.data!['project'] as Map<String, dynamic>);
  }

  Future<List<ProjectInvite>> myInvites() async {
    final res = await _api.dio.get<Map<String, dynamic>>('/api/v1/invites/mine');
    final items = res.data?['items'] as List<dynamic>? ?? [];
    return items.map((e) => ProjectInvite.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> acceptInvite(String id) async {
    await _api.dio.post('/api/v1/invites/$id/accept');
  }

  Future<void> declineInvite(String id) async {
    await _api.dio.post('/api/v1/invites/$id/decline');
  }

  Future<void> inviteMember({
    required String projectId,
    required String email,
    String? note,
  }) async {
    await _api.dio.post(
      '/api/v1/projects/$projectId/invites',
      data: {
        'email': email.trim(),
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
  }

  Future<List<UserProfile>> searchUsers({String? q, String? excludeProjectId}) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/api/v1/users',
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        'exclude_project_id': ?excludeProjectId,
      },
    );
    final items = res.data?['items'] as List<dynamic>? ?? [];
    return items.map((e) => UserProfile.fromJson(e as Map<String, dynamic>)).toList();
  }
}
