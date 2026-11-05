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
    this.isDefault = false,
    this.autoUrgencyFromDue = true,
    this.members = const [],
  });

  final String id;
  final String name;
  final String? description;
  final String? color;
  final bool isDemo;
  final bool isDefault;
  final bool autoUrgencyFromDue;
  final List<ProjectMember> members;

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        color: json['color'] as String?,
        isDemo: json['is_demo'] as bool? ?? false,
        isDefault: json['is_default'] as bool? ?? false,
        autoUrgencyFromDue: json['auto_urgency_from_due'] as bool? ?? true,
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
        'is_default': isDefault,
        'auto_urgency_from_due': autoUrgencyFromDue,
        'members': members.map((m) => m.toJson()).toList(),
      };

  @override
  List<Object?> get props =>
      [id, name, description, color, isDemo, isDefault, autoUrgencyFromDue, members];
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

class TaskActivityItem extends Equatable {
  const TaskActivityItem({
    required this.id,
    required this.action,
    required this.summary,
    required this.createdAt,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    this.field,
    this.oldLabel,
    this.newLabel,
  });

  final String id;
  final String action;
  final String summary;
  final String createdAt;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final String? field;
  final String? oldLabel;
  final String? newLabel;

  factory TaskActivityItem.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? const {};
    return TaskActivityItem(
      id: json['id'] as String,
      action: json['action'] as String? ?? '',
      summary: json['summary'] as String? ?? json['action'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      userId: user['id'] as String? ?? '',
      userName: user['name'] as String? ?? 'Участник',
      userAvatarUrl: user['avatar_url'] as String?,
      field: json['field'] as String?,
      oldLabel: json['old_label'] as String?,
      newLabel: json['new_label'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, action, summary, createdAt, userId];
}

class TaskAttachment extends Equatable {
  const TaskAttachment({
    required this.id,
    required this.filename,
    required this.contentType,
    required this.sizeBytes,
    required this.isImage,
    required this.url,
    this.previewUrl,
    this.createdAt,
  });

  final String id;
  final String filename;
  final String contentType;
  final int sizeBytes;
  final bool isImage;
  final String url;
  final String? previewUrl;
  final String? createdAt;

  factory TaskAttachment.fromJson(Map<String, dynamic> json) => TaskAttachment(
        id: json['id'] as String,
        filename: json['filename'] as String? ?? 'file',
        contentType: json['content_type'] as String? ?? 'application/octet-stream',
        sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
        isImage: json['is_image'] as bool? ?? false,
        url: json['url'] as String? ?? '',
        previewUrl: json['preview_url'] as String?,
        createdAt: json['created_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'filename': filename,
        'content_type': contentType,
        'size_bytes': sizeBytes,
        'is_image': isImage,
        'url': url,
        'preview_url': previewUrl,
        'created_at': createdAt,
      };

  @override
  List<Object?> get props => [id, filename, sizeBytes, isImage, url, previewUrl];
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
    this.attachments = const [],
    this.dueDate,
    this.closedAt,
    this.statusEnteredAt,
    this.updatedAt,
    this.createdAt,
    this.statusName,
    this.authorId,
    this.authorName,
    this.authorAvatarUrl,
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
  final List<TaskAttachment> attachments;
  final String? dueDate;
  final String? closedAt;
  final String? statusEnteredAt;
  final String? updatedAt;
  final String? createdAt;
  final String? statusName;
  final String? authorId;
  final String? authorName;
  final String? authorAvatarUrl;
  final int commentCount;

  bool get isDone => closedAt != null;

  /// ISO for time-in-column badge (status enter → updated → created).
  String? get timeInStatusIso => statusEnteredAt ?? updatedAt ?? createdAt;

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
      dueDate: json['due_date'] as String?,
      closedAt: json['closed_at'] as String?,
      statusEnteredAt: json['status_entered_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      createdAt: json['created_at'] as String?,
      statusName: status?['name'] as String?,
      authorId: json['author_id'] as String? ?? author?['id'] as String?,
      authorName: author?['name'] as String?,
      authorAvatarUrl: author?['avatar_url'] as String?,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      attachments: (json['attachments'] as List<dynamic>? ?? [])
          .map((e) => TaskAttachment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static const Object _unset = Object();

  TaskItem copyWith({
    String? title,
    String? description,
    String? statusId,
    String? priority,
    String? projectId,
    List<TaskAssignee>? assignees,
    List<TaskAttachment>? attachments,
    Object? dueDate = _unset,
    Object? closedAt = _unset,
    Object? statusEnteredAt = _unset,
    String? updatedAt,
    String? createdAt,
    String? statusName,
    String? authorAvatarUrl,
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
        attachments: attachments ?? this.attachments,
        dueDate: identical(dueDate, _unset) ? this.dueDate : dueDate as String?,
        closedAt: identical(closedAt, _unset) ? this.closedAt : closedAt as String?,
        statusEnteredAt:
            identical(statusEnteredAt, _unset) ? this.statusEnteredAt : statusEnteredAt as String?,
        updatedAt: updatedAt ?? this.updatedAt,
        createdAt: createdAt ?? this.createdAt,
        statusName: statusName ?? this.statusName,
        authorId: authorId,
        authorName: authorName,
        authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
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
        'attachments': attachments.map((a) => a.toJson()).toList(),
        'due_date': dueDate,
        'closed_at': closedAt,
        'status_entered_at': statusEnteredAt,
        'updated_at': updatedAt,
        'created_at': createdAt,
        'status': statusName == null ? null : {'name': statusName},
        'author_id': authorId,
        'author': authorName == null && authorId == null
            ? null
            : {
                'id': authorId,
                'name': authorName,
                'avatar_url': authorAvatarUrl,
              },
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
  List<Object?> get props => [
        id,
        title,
        statusId,
        priority,
        position,
        description,
        assignees,
        attachments,
        dueDate,
        closedAt,
        statusEnteredAt,
        commentCount,
      ];
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
    this.projectName,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String kind;
  final String createdAt;
  final String? body;
  final String? taskId;
  final String? projectId;
  final String? projectName;
  final bool isRead;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        kind: json['kind'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
        body: json['body'] as String?,
        taskId: json['task_id'] as String?,
        projectId: json['project_id'] as String?,
        projectName: json['project_name'] as String?,
        isRead: json['is_read'] as bool? ?? false,
      );

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        kind: kind,
        createdAt: createdAt,
        body: body,
        taskId: taskId,
        projectId: projectId,
        projectName: projectName,
        isRead: isRead ?? this.isRead,
      );

  @override
  List<Object?> get props => [id, title, isRead, projectName];
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
