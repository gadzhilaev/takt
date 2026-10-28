import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../shared/models/models.dart';
import '../cubit/board_cubit.dart';
import 'task_sheet.dart';

class BoardPage extends StatefulWidget {
  const BoardPage({super.key, this.deepTaskId});

  final String? deepTaskId;

  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  @override
  void initState() {
    super.initState();
      context.read<BoardCubit>().bootstrap().then((_) {
      if (!mounted || widget.deepTaskId == null) return;
      TaskItem? task;
      for (final t in context.read<BoardCubit>().state.tasks) {
        if (t.id == widget.deepTaskId) {
          task = t;
          break;
        }
      }
      if (task != null) _openTask(task);
    });
  }

  void _openTask(TaskItem task) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TaskSheet(task: task),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BoardCubit, BoardState>(
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error!)));
        }
      },
      builder: (context, state) {
        if (state.loading && state.project == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (state.project == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Takt')),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Создайте первый проект', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text('Доска откроется сразу — четыре стандартных столбца.'),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => _createProjectDialog(context),
                    child: const Text('Новый проект'),
                  ),
                ],
              ),
            ),
          );
        }

        final col = state.currentColumn;
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 16,
            title: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: state.project!.id,
                isExpanded: true,
                items: state.projects
                    .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (id) {
                  if (id != null) context.read<BoardCubit>().openProject(id);
                },
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Уведомления',
                onPressed: () => context.push('/notifications'),
                icon: const Icon(Icons.notifications_none_rounded),
              ),
              IconButton(
                tooltip: 'Профиль',
                onPressed: () => context.push('/profile'),
                icon: const Icon(Icons.person_outline_rounded),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _createTaskDialog(context),
            backgroundColor: TaktColors.accent,
            child: const Icon(Icons.add, color: Colors.white),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.offline)
                Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('Офлайн: показаны последние данные. Изменения временно недоступны.'),
                  ),
                ),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: state.columns.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final c = state.columns[i];
                    final selected = i == state.columnIndex;
                    return ChoiceChip(
                      label: Text(c.name),
                      selected: selected,
                      onSelected: (_) => context.read<BoardCubit>().selectColumn(i),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  col == null ? '' : '${state.currentTasks.length} задач',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).hintColor),
                ),
              ),
              Expanded(
                child: state.currentTasks.isEmpty
                    ? Center(
                        child: Text(
                          'Пока пусто',
                          style: TextStyle(color: Theme.of(context).hintColor),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                        itemCount: state.currentTasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final task = state.currentTasks[i];
                          return _TaskTile(task: task, onTap: () => _openTask(task));
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createProjectDialog(BuildContext context) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый проект'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Название')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Создать')),
        ],
      ),
    );
    if (ok == true && controller.text.trim().isNotEmpty && context.mounted) {
      await context.read<BoardCubit>().createProject(controller.text.trim());
    }
  }

  Future<void> _createTaskDialog(BuildContext context) async {
    final title = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новая задача'),
        content: TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Название')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Создать')),
        ],
      ),
    );
    if (ok == true && title.text.trim().isNotEmpty && context.mounted) {
      await context.read<BoardCubit>().createTask(title: title.text.trim());
    }
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.onTap});
  final TaskItem task;
  final VoidCallback onTap;

  Color _urgencyColor(String p) {
    switch (p) {
      case 'urgent':
        return TaktColors.urgent;
      case 'high':
        return TaktColors.important;
      default:
        return TaktColors.normal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = task.isDone;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: _urgencyColor(task.priority),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (muted) ...[
                          Icon(Icons.check_circle, size: 16, color: Theme.of(context).hintColor),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            task.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              decoration: muted ? TextDecoration.lineThrough : null,
                              color: muted ? Theme.of(context).hintColor : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (task.assignees.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        task.assignees.map((a) => a.name).join(', '),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
