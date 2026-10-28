import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/kanban_colors.dart';
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
        final dark = Theme.of(context).brightness == Brightness.dark;
        final columnBg = col == null
            ? Theme.of(context).scaffoldBackgroundColor
            : KanbanColors.columnBackground(col.color, dark: dark);
        final accent = col == null ? null : KanbanColors.columnAccent(col.color);

        return Scaffold(
          backgroundColor: columnBg,
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
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final c = state.columns[i];
                    final selected = i == state.columnIndex;
                    final chipAccent = KanbanColors.columnAccent(c.color);
                    return ChoiceChip(
                      label: Text(c.name),
                      selected: selected,
                      selectedColor: KanbanColors.columnBackground(c.color, dark: dark),
                      side: BorderSide(
                        color: selected ? chipAccent : Theme.of(context).dividerColor,
                      ),
                      onSelected: (_) => context.read<BoardCubit>().selectColumn(i),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    if (accent != null) ...[
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      col == null ? '' : '${state.currentTasks.length} задач',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: dark ? KanbanColors.descDark : KanbanColors.descLight,
                          ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: state.currentTasks.isEmpty
                    ? Center(
                        child: Text(
                          'Пока пусто',
                          style: TextStyle(
                            color: dark ? KanbanColors.descDark : KanbanColors.descLight,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                        itemCount: state.currentTasks.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
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

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = task.isDone;
    final urgency = KanbanColors.urgency(task.priority, dark: dark);
    final titleColor = muted
        ? (dark ? KanbanColors.doneTitleDark : KanbanColors.doneTitleLight)
        : (dark ? KanbanColors.titleDark : KanbanColors.titleLight);
    final descColor = dark ? KanbanColors.descDark : KanbanColors.descLight;

    return Material(
      color: dark ? KanbanColors.cardBgDark : KanbanColors.cardBgLight,
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: dark ? 0.35 : 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: dark ? KanbanColors.cardBorderDark : KanbanColors.cardBorderLight,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: urgency.fg,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (muted) ...[
                            Icon(Icons.check_circle, size: 16, color: descColor),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              task.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: titleColor,
                                decoration: muted ? TextDecoration.lineThrough : null,
                                decorationColor: titleColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: urgency.bg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              urgency.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: urgency.fg,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (task.assignees.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ...task.assignees.take(3).map((a) {
                              final initial = a.name.isNotEmpty ? a.name[0].toUpperCase() : '?';
                              return Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: CircleAvatar(
                                  radius: 11,
                                  backgroundColor: dark
                                      ? const Color(0xFF4A5563)
                                      : const Color(0xFFE4F0F6),
                                  child: Text(
                                    initial,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: dark ? KanbanColors.titleDark : const Color(0xFF326E8B),
                                    ),
                                  ),
                                ),
                              );
                            }),
                            if (task.assignees.length > 3)
                              Text(
                                '+${task.assignees.length - 3}',
                                style: TextStyle(fontSize: 11, color: descColor),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
