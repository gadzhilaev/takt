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

  Future<Project> renameProject({required String projectId, required String name}) async {
    final res = await _api.dio.patch<Map<String, dynamic>>(
      '/api/v1/projects/$projectId',
      data: {'name': name.trim()},
    );
    return Project.fromJson(res.data!['project'] as Map<String, dynamic>);
  }

  Future<void> deleteProject(String projectId) async {
    await _api.dio.delete('/api/v1/projects/$projectId');
  }

  Future<void> leaveProject(String projectId) async {
    await _api.dio.post('/api/v1/projects/$projectId/leave');
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

  Future<Map<String, dynamic>> inviteMember({
    required String projectId,
    String? email,
    String? note,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/api/v1/projects/$projectId/invites',
      data: {
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return res.data ?? {};
  }

  Future<String?> createOrGetInviteLink(String projectId) async {
    final res = await inviteMember(projectId: projectId);
    final invite = res['invite'];
    if (invite is Map<String, dynamic>) {
      return invite['token'] as String?;
    }
    return null;
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

  Future<void> removeMember({required String projectId, required String userId}) async {
    await _api.dio.delete('/api/v1/projects/$projectId/members/$userId');
  }

  Future<LeaveRequest> requestLeave(String projectId) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/api/v1/projects/$projectId/leave-requests',
    );
    return LeaveRequest.fromJson(res.data!['request'] as Map<String, dynamic>);
  }

  Future<List<LeaveRequest>> listLeaveRequests(String projectId) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/api/v1/projects/$projectId/leave-requests',
    );
    final items = res.data?['items'] as List<dynamic>? ?? [];
    return items.map((e) => LeaveRequest.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> approveLeaveRequest({required String projectId, required String requestId}) async {
    await _api.dio.post('/api/v1/projects/$projectId/leave-requests/$requestId/approve');
  }

  Future<void> rejectLeaveRequest({required String projectId, required String requestId}) async {
    await _api.dio.post('/api/v1/projects/$projectId/leave-requests/$requestId/reject');
  }
}
