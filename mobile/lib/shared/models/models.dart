import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  const UserProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.avatarUrl,
    this.mustChangePassword = false,
  });

  final String id;
  final String email;
  final String name;
  final String role;
  final String? avatarUrl;
  final bool mustChangePassword;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
        role: json['role'] as String? ?? 'member',
        avatarUrl: json['avatar_url'] as String?,
        mustChangePassword: json['must_change_password'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [id, email, name, role, avatarUrl];
}

class ProjectMember extends Equatable {
  const ProjectMember({
    required this.userId,
    required this.name,
    required this.role,
    this.avatarUrl,
    this.email,
  });

  final String userId;
  final String name;
  final String role;
  final String? avatarUrl;
  final String? email;

  factory ProjectMember.fromJson(Map<String, dynamic> json) => ProjectMember(
        userId: json['user_id'] as String,
        name: json['name'] as String? ?? '',
        role: json['role'] as String? ?? 'member',
        avatarUrl: json['avatar_url'] as String?,
        email: json['email'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'name': name,
        'role': role,
        'avatar_url': avatarUrl,
        'email': email,
      };

  @override
  List<Object?> get props => [userId, name, role, avatarUrl, email];
}

class Project extends Equatable {
  const Project({
    required this.id,
    required this.name,
    this.description,
    this.color,
    this.isDemo = false,
    this.members = const [],
  });

  final String id;
  final String name;
  final String? description;
  final String? color;
  final bool isDemo;
  final List<ProjectMember> members;

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        color: json['color'] as String?,
        isDemo: json['is_demo'] as bool? ?? false,
        members: (json['members'] as List<dynamic>? ?? [])
            .map((e) => ProjectMember.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'color': color,
        'is_demo': isDemo,
        'members': members.map((m) => m.toJson()).toList(),
      };

  @override
  List<Object?> get props => [id, name, description, color, isDemo, members];
}

class StatusColumn extends Equatable {
  const StatusColumn({
    required this.id,
    required this.name,
    required this.position,
    this.color,
    this.isDone = false,
  });

  final String id;
  final String name;
  final double position;
  final String? color;
  final bool isDone;

  factory StatusColumn.fromJson(Map<String, dynamic> json) => StatusColumn(
        id: json['id'] as String,
        name: json['name'] as String,
        position: (json['position'] as num?)?.toDouble() ?? 0,
        color: json['color'] as String?,
        isDone: json['is_done'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'position': position,
        'color': color,
        'is_done': isDone,
      };

  @override
  List<Object?> get props => [id, name, position, color, isDone];
}

class TaskAssignee extends Equatable {
  const TaskAssignee({required this.id, required this.name, this.avatarUrl});

  final String id;
  final String name;
  final String? avatarUrl;

  factory TaskAssignee.fromJson(Map<String, dynamic> json) => TaskAssignee(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar_url': avatarUrl,
      };

  @override
  List<Object?> get props => [id, name, avatarUrl];
}

class TaskItem extends Equatable {
  const TaskItem({
    required this.id,
    required this.title,
    required this.statusId,
    required this.priority,
    required this.position,
    this.projectId,
    this.description,
    this.assignees = const [],
    this.closedAt,
    this.statusName,
    this.authorId,
    this.authorName,
    this.commentCount = 0,
  });

  final String id;
  final String title;
  final String statusId;
  final String priority;
  final double position;
  final String? projectId;
  final String? description;
  final List<TaskAssignee> assignees;
  final String? closedAt;
  final String? statusName;
  final String? authorId;
  final String? authorName;
  final int commentCount;

  bool get isDone => closedAt != null;

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as Map<String, dynamic>?;
    final author = json['author'] as Map<String, dynamic>?;
    return TaskItem(
      id: json['id'] as String,
      title: json['title'] as String,
      statusId: json['status_id'] as String,
      priority: json['priority'] as String? ?? 'medium',
      position: (json['position'] as num?)?.toDouble() ?? 0,
      projectId: json['project_id'] as String?,
      description: json['description'] as String?,
      assignees: (json['assignees'] as List<dynamic>? ?? [])
          .map((e) => TaskAssignee.fromJson(e as Map<String, dynamic>))
          .toList(),
      closedAt: json['closed_at'] as String?,
      statusName: status?['name'] as String?,
      authorId: json['author_id'] as String? ?? author?['id'] as String?,
      authorName: author?['name'] as String?,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
    );
  }

  TaskItem copyWith({
    String? title,
    String? description,
    String? statusId,
    String? priority,
    String? projectId,
    List<TaskAssignee>? assignees,
    String? closedAt,
    String? statusName,
    double? position,
  }) =>
      TaskItem(
        id: id,
        title: title ?? this.title,
        statusId: statusId ?? this.statusId,
        priority: priority ?? this.priority,
        position: position ?? this.position,
        projectId: projectId ?? this.projectId,
        description: description ?? this.description,
        assignees: assignees ?? this.assignees,
        closedAt: closedAt ?? this.closedAt,
        statusName: statusName ?? this.statusName,
        authorId: authorId,
        authorName: authorName,
        commentCount: commentCount,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'status_id': statusId,
        'priority': priority,
        'position': position,
        'project_id': projectId,
        'description': description,
        'assignees': assignees.map((a) => a.toJson()).toList(),
        'closed_at': closedAt,
        'status': statusName == null ? null : {'name': statusName},
        'author_id': authorId,
        'author': authorName == null && authorId == null
            ? null
            : {'id': authorId, 'name': authorName},
        'comment_count': commentCount,
      };

  Map<String, dynamic> toWidgetJson() => {
        'id': id,
        'title': title,
        'priority': priority,
        'status_id': statusId,
        'project_id': projectId,
        'assignee_ids': assignees.map((a) => a.id).toList(),
      };

  @override
  List<Object?> get props =>
      [id, title, statusId, priority, position, description, assignees, closedAt, commentCount];
}

class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.title,
    required this.kind,
    required this.createdAt,
    this.body,
    this.taskId,
    this.projectId,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String kind;
  final String createdAt;
  final String? body;
  final String? taskId;
  final String? projectId;
  final bool isRead;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        kind: json['kind'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
        body: json['body'] as String?,
        taskId: json['task_id'] as String?,
        projectId: json['project_id'] as String?,
        isRead: json['is_read'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [id, title, isRead];
}

class ProjectInvite extends Equatable {
  const ProjectInvite({
    required this.id,
    required this.projectId,
    required this.projectName,
    required this.status,
  });

  final String id;
  final String projectId;
  final String projectName;
  final String status;

  factory ProjectInvite.fromJson(Map<String, dynamic> json) => ProjectInvite(
        id: json['id'] as String,
        projectId: json['project_id'] as String,
        projectName: json['project_name'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
      );

  @override
  List<Object?> get props => [id, projectId, status];
}

class LeaveRequest extends Equatable {
  const LeaveRequest({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.userName,
    required this.status,
    this.avatarUrl,
  });

  final String id;
  final String projectId;
  final String userId;
  final String userName;
  final String status;
  final String? avatarUrl;

  factory LeaveRequest.fromJson(Map<String, dynamic> json) => LeaveRequest(
        id: json['id'] as String,
        projectId: json['project_id'] as String,
        userId: json['user_id'] as String,
        userName: json['user_name'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
        avatarUrl: json['avatar_url'] as String?,
      );

  @override
  List<Object?> get props => [id, projectId, userId, status];
}
