import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/format_created_at.dart';
import '../../../core/kanban_colors.dart';
import '../../../core/theme.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/takt_app_bar.dart';
import '../../../shared/widgets/takt_sheet.dart';
import '../../../shared/widgets/takt_ui.dart';
import '../../../shared/widgets/task_activity_section.dart';
import '../../../shared/widgets/task_attachments_section.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../cubit/board_cubit.dart';
import '../data/board_repository.dart';

class TaskDetailPage extends StatefulWidget {
  const TaskDetailPage({super.key, required this.taskId});

  final String taskId;

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  TaskItem? _task;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  TaskItem _enrichAvatars(TaskItem task, BoardState board) {
    final byId = <String, String?>{};
    for (final p in board.projects) {
      for (final m in p.members) {
        byId[m.userId] = m.avatarUrl;
      }
    }
    final project = board.project;
    if (project != null) {
      for (final m in project.members) {
        byId[m.userId] = m.avatarUrl;
      }
    }

    final assignees = task.assignees
        .map(
          (a) => TaskAssignee(
            id: a.id,
            name: a.name,
            avatarUrl: a.avatarUrl ?? byId[a.id],
          ),
        )
        .toList();
    final authorAvatar = task.authorAvatarUrl ??
        (task.authorId != null ? byId[task.authorId!] : null);

    return task.copyWith(
      assignees: assignees,
      authorAvatarUrl: authorAvatar,
    );
  }

  Future<void> _resolve() async {
    final cubit = context.read<BoardCubit>();
    final board = cubit.state;
    TaskItem? local;
    for (final t in board.tasks) {
      if (t.id == widget.taskId) {
        local = t;
        break;
      }
    }
    if (local != null) {
      setState(() {
        _task = _enrichAvatars(local!, board);
        _loading = false;
      });
    }

    try {
      final remote = await context.read<BoardRepository>().getTask(widget.taskId);
      if (!mounted) return;
      setState(() {
        _task = _enrichAvatars(remote, cubit.state);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_task != null) return;
      setState(() {
        _error = context.read<ApiClient>().messageFromError(e);
        _loading = false;
      });
    }
  }

  Future<void> _refreshFromBoard() async {
    final board = context.read<BoardCubit>().state;
    for (final t in board.tasks) {
      if (t.id == widget.taskId) {
        setState(() => _task = _enrichAvatars(t, board));
        return;
      }
    }
    await _resolve();
  }

  void _leave() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(context.read<BoardCubit>().state.project != null ? '/board' : '/projects');
    }
  }

  Future<void> _openEdit(TaskItem task) async {
    final updated = await context.push<bool>('/task-edit/${task.id}');
    if (updated == true && mounted) await _refreshFromBoard();
  }

  Future<void> _delete(TaskItem task) async {
    final ok = await showTaktSheet(
      context: context,
      title: 'Удалить задачу?',
      confirmLabel: 'Удалить',
      body: const Text('Действие нельзя отменить.'),
    );
    if (ok == true && mounted) {
      await context.read<BoardCubit>().deleteTask(task.id);
      if (!mounted) return;
      _leave();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    final fg = dark ? TaktColors.foregroundDark : TaktColors.graphite;
    final cubit = context.watch<BoardCubit>();
    final board = cubit.state;
    final task = _task;
    final authUserId = cubit.currentUserId;

    StatusColumn? statusCol;
    if (task != null) {
      for (final c in board.columns) {
        if (c.id == task.statusId) {
          statusCol = c;
          break;
        }
      }
    }
    final rawStatusName = task?.statusName;
    final statusName =
        (rawStatusName != null && rawStatusName.isNotEmpty) ? rawStatusName : statusCol?.name;

    final canDelete = task != null &&
        authUserId != null &&
        task.authorId != null &&
        task.authorId == authUserId;

    final urgency = task == null ? null : KanbanColors.urgency(task.priority, dark: dark);
    final createdLabel = task == null ? null : formatCreatedAt(task.createdAt);
    final colBg = statusCol != null
        ? KanbanColors.columnBackground(statusCol.color, dark: dark)
        : null;
    final colBorder = statusCol != null
        ? KanbanColors.columnBorder(statusCol.color, dark: dark)
        : (dark ? TaktColors.borderDark : TaktColors.border);
    final colAccent = statusCol != null ? KanbanColors.columnAccent(statusCol.color) : null;

    return Scaffold(
      appBar: TaktAppBar(
        title: 'Задача',
        onBack: _leave,
        actions: [
          if (task != null)
            IconButton(
              tooltip: 'Редактировать',
              visualDensity: VisualDensity.compact,
              onPressed: () => _openEdit(task),
              icon: AppIcon(
                AppIcons.edit,
                size: 20,
                color: dark ? TaktColors.accentDark : TaktColors.accent,
              ),
            ),
          if (task != null && canDelete)
            IconButton(
              tooltip: 'Удалить',
              visualDensity: VisualDensity.compact,
              onPressed: () => _delete(task),
              icon: AppIcon(
                AppIcons.delete,
                size: 20,
                color: TaktColors.danger,
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 8),
        child: _loading && task == null
            ? const SizedBox.shrink()
            : _error != null
                ? TaktEmptyState(
                    title: _error!,
                    icon: AppIcons.alert,
                    action: TaktButton(
                      label: 'Назад',
                      variant: TaktButtonVariant.secondary,
                      onPressed: _leave,
                    ),
                  )
                : task == null
                    ? TaktEmptyState(
                        title: 'Задача не найдена',
                        subtitle: 'Возможно, она удалена или у вас нет доступа',
                        action: TaktButton(
                          label: 'На главную',
                          variant: TaktButtonVariant.secondary,
                          onPressed: () => context.go(
                                context.read<BoardCubit>().state.project != null ? '/board' : '/projects',
                              ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: urgency?.bg ??
                                  colBg ??
                                  (dark ? TaktColors.surface2Dark : TaktColors.surface2),
                              borderRadius: BorderRadius.circular(TaktRadii.lg),
                              border: Border.all(color: colBorder),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(TaktRadii.lg),
                              child: IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    ColoredBox(
                                      color: urgency?.fg ?? colAccent ?? TaktColors.accent,
                                      child: const SizedBox(width: 3),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (colAccent != null)
                                              Padding(
                                                padding: const EdgeInsets.only(bottom: 8),
                                                child: ColoredBox(
                                                  color: colAccent,
                                                  child: const SizedBox(height: 3, width: double.infinity),
                                                ),
                                              ),
                                            Text.rich(
                                              TextSpan(
                                                style: TextStyle(fontSize: 14, height: 1.4, color: fg),
                                                children: [
                                                  TextSpan(
                                                    text: 'Срочность: ',
                                                    style: TextStyle(color: muted),
                                                  ),
                                                  TextSpan(
                                                    text: urgency?.label ?? '',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      color: urgency?.fg ?? fg,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: '  ·  ',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w800,
                                                      color: fg,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: 'Статус: ',
                                                    style: TextStyle(color: muted),
                                                  ),
                                                  TextSpan(
                                                    text: statusName ?? '—',
                                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                if (task.authorName != null &&
                                                    task.authorName!.isNotEmpty) ...[
                                                  TaktUserAvatar(
                                                    name: task.authorName!,
                                                    avatarUrl: task.authorAvatarUrl,
                                                    size: 24,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Flexible(
                                                    child: Text(
                                                      task.authorName!,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w500,
                                                        color: fg,
                                                      ),
                                                    ),
                                                  ),
                                                ] else
                                                  Text(
                                                    'Без автора',
                                                    style: TextStyle(fontSize: 13, color: muted),
                                                  ),
                                                if (createdLabel != null) ...[
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                                    child: Text('·', style: TextStyle(color: muted)),
                                                  ),
                                                  Text(
                                                    createdLabel,
                                                    style: TextStyle(fontSize: 13, color: muted),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TaktFieldLabel('Название'),
                          const SizedBox(height: 6),
                          Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                              letterSpacing: -0.15,
                              color: fg,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TaktFieldLabel('Описание'),
                          const SizedBox(height: 6),
                          Text(
                            (task.description?.trim().isNotEmpty ?? false)
                                ? task.description!
                                : 'Без описания',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: (task.description?.trim().isNotEmpty ?? false) ? fg : muted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TaktFieldLabel('Исполнители'),
                          const SizedBox(height: 8),
                          if (task.assignees.isEmpty)
                            Text('Не назначены', style: TextStyle(fontSize: 14, color: muted))
                          else
                            Column(
                              children: [
                                for (final a in task.assignees)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        TaktUserAvatar(
                                          name: a.name,
                                          avatarUrl: a.avatarUrl,
                                          size: 28,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            a.name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: fg,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          const SizedBox(height: 16),
                          TaskAttachmentsSection(
                            taskId: task.id,
                            attachments: task.attachments,
                            editable: false,
                          ),
                          const SizedBox(height: 16),
                          TaskActivitySection(taskId: task.id),
                        ],
                      ),
      ),
    );
  }
}
