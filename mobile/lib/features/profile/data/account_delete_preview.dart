/// Ответ `GET /api/v1/users/me/delete-preview`: что станет с проектами после удаления.
class AccountDeletePreview {
  const AccountDeletePreview({
    required this.canDelete,
    required this.projects,
    this.blockedMessage,
  });

  final bool canDelete;
  final String? blockedMessage;
  final List<AccountDeleteProjectPlan> projects;

  factory AccountDeletePreview.fromJson(Map<String, dynamic> json) {
    final blocked = json['blocked'];
    return AccountDeletePreview(
      canDelete: json['can_delete'] as bool? ?? true,
      blockedMessage: blocked is Map ? blocked['message'] as String? : null,
      projects: [
        for (final p in (json['projects'] as List? ?? const []))
          if (p is Map) AccountDeleteProjectPlan.fromJson(Map<String, dynamic>.from(p)),
      ],
    );
  }

  /// Строки для подтверждения: сначала удаление, затем передача прав, затем выход.
  List<String> get lines {
    const order = {'delete': 0, 'transfer': 1, 'leave': 2};
    final sorted = [...projects]
      ..sort((a, b) {
        final byAction = (order[a.action] ?? 3).compareTo(order[b.action] ?? 3);
        return byAction != 0 ? byAction : a.name.compareTo(b.name);
      });
    return [for (final p in sorted) p.line];
  }
}

class AccountDeleteProjectPlan {
  const AccountDeleteProjectPlan({
    required this.id,
    required this.name,
    required this.action,
    this.newAdminName,
  });

  final String id;
  final String name;

  /// `delete` | `transfer` | `leave`
  final String action;
  final String? newAdminName;

  factory AccountDeleteProjectPlan.fromJson(Map<String, dynamic> json) {
    final admin = json['new_admin'];
    return AccountDeleteProjectPlan(
      id: '${json['id']}',
      name: json['name'] as String? ?? 'Проект',
      action: json['action'] as String? ?? 'leave',
      newAdminName: admin is Map ? admin['name'] as String? : null,
    );
  }

  String get line {
    if (action == 'delete') return 'Проект «$name» будет удалён.';
    if (action == 'transfer' && newAdminName != null) {
      return 'Права администратора в проекте «$name» перейдут к $newAdminName.';
    }
    return 'Вы выйдете из проекта «$name», данные команды сохранятся.';
  }
}
