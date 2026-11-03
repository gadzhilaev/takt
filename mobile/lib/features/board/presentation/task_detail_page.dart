import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/takt_app_bar.dart';
import '../../../shared/widgets/takt_sheet.dart';
import '../../../shared/widgets/takt_ui.dart';
import '../../../shared/widgets/urgency_badge.dart';
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

  Future<void> _resolve() async {
    final board = context.read<BoardCubit>().state;
    TaskItem? local;
    for (final t in board.tasks) {
      if (t.id == widget.taskId) {
        local = t;
        break;
      }
    }
    if (local != null) {
      setState(() {
        _task = local;
        _loading = false;
      });
      return;
    }
    try {
      final remote = await context.read<BoardRepository>().getTask(widget.taskId);
      if (!mounted) return;
      setState(() {
        _task = remote;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
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
        setState(() => _task = t);
        return;
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    final fg = dark ? TaktColors.foregroundDark : TaktColors.graphite;
    final cubit = context.watch<BoardCubit>();
    final board = cubit.state;
    final task = _task;
    final authUserId = cubit.currentUserId;

    String? statusName = task?.statusName;
    if (task != null && (statusName == null || statusName.isEmpty)) {
      statusName = board.columns.where((c) => c.id == task.statusId).map((c) => c.name).firstOrNull;
    }

    final canDelete = task != null &&
        authUserId != null &&
        task.authorId != null &&
        task.authorId == authUserId;

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
              icon: AppIcon(AppIcons.edit, size: 20, color: fg),
            ),
          if (task != null)
            PopupMenuButton<String>(
              useRootNavigator: true,
              icon: AppIcon(AppIcons.more, size: 22, color: fg),
              onSelected: (v) async {
                if (v == 'edit') {
                  await _openEdit(task);
                } else if (v == 'done') {
                  final done = board.columns.where((c) => c.isDone).toList();
                  if (done.isEmpty) return;
                  final boardCubit = context.read<BoardCubit>();
                  await boardCubit.moveToColumn(task, done.first.id);
                  if (!mounted) return;
                  _leave();
                } else if (v == 'delete' && canDelete) {
                  final boardCubit = context.read<BoardCubit>();
                  final ok = await showTaktSheet(
                    context: context,
                    title: 'Удалить задачу?',
                    confirmLabel: 'Удалить',
                    body: const Text('Действие нельзя отменить.'),
                  );
                  if (ok == true && mounted) {
                    await boardCubit.deleteTask(task.id);
                    if (!mounted) return;
                    _leave();
                  }
                } else if (v.startsWith('move:')) {
                  final boardCubit = context.read<BoardCubit>();
                  await boardCubit.moveToColumn(task, v.substring(5));
                  if (mounted) await _refreshFromBoard();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Редактировать')),
                const PopupMenuItem(value: 'done', child: Text('Завершить')),
                if (board.columns.isNotEmpty) ...[
                  const PopupMenuDivider(),
                  ...board.columns
                      .where((c) => c.id != task.statusId)
                      .map((c) => PopupMenuItem(value: 'move:${c.id}', child: Text('В «${c.name}»'))),
                ],
                if (canDelete) ...[
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Удалить', style: TextStyle(color: TaktColors.danger)),
                  ),
                ],
              ],
            ),
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
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.25,
                            height: 1.3,
                            color: fg,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            UrgencyBadge(priority: task.priority),
                            if (statusName != null)
                              Text(
                                statusName,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: muted),
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text('Описание', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted)),
                        const SizedBox(height: 6),
                        Text(
                          (task.description?.trim().isNotEmpty ?? false) ? task.description! : 'Без описания',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: (task.description?.trim().isNotEmpty ?? false) ? fg : muted,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text('Исполнители', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted)),
                        const SizedBox(height: 8),
                        if (task.assignees.isEmpty)
                          Text('Не назначены', style: TextStyle(fontSize: 14, color: muted))
                        else
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              for (final a in task.assignees)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TaktUserAvatar(name: a.name, avatarUrl: a.avatarUrl, size: 26),
                                    const SizedBox(width: 6),
                                    Text(
                                      a.name,
                                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: fg),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        if (task.authorName != null && task.authorName!.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Text('Автор', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TaktUserAvatar(name: task.authorName!, size: 26),
                              const SizedBox(width: 6),
                              Text(
                                task.authorName!,
                                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: fg),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
      ),
    );
  }
}
