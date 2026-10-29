import 'package:flutter/material.dart';

import '../../core/kanban_colors.dart';
import '../../shared/widgets/app_icon.dart';
import '../../core/theme.dart';
import '../models/models.dart';
import 'task_card.dart';

/// One Kanban column pane (shared by Home and My Tasks).
class KanbanColumnPane extends StatelessWidget {
  const KanbanColumnPane({
    super.key,
    required this.column,
    required this.tasks,
    required this.dark,
    required this.onOpenTask,
    this.onAdd,
  });

  final StatusColumn column;
  final List<TaskItem> tasks;
  final bool dark;
  final ValueChanged<TaskItem> onOpenTask;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final bg = KanbanColors.columnBackground(column.color, dark: dark);
    final border = KanbanColors.columnBorder(column.color, dark: dark);
    final accent = KanbanColors.columnAccent(column.color);
    final radius = BorderRadius.circular(TaktRadii.lg);

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
      child: Material(
        color: bg,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: accent,
              child: const SizedBox(height: 3),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      column.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                        color: dark ? TaktColors.foregroundDark : TaktColors.graphite,
                      ),
                    ),
                  ),
                  Text(
                    '${tasks.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: dark ? KanbanColors.descDark : KanbanColors.descLight,
                    ),
                  ),
                  if (onAdd != null) ...[
                    const SizedBox(width: 2),
                    IconButton(
                      tooltip: 'Добавить',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      onPressed: onAdd,
                    icon: AppIcon(AppIcons.add, size: 20, color: dark ? TaktColors.accentDark : TaktColors.accent,
                    ),
                    ),
                  ] else
                    const SizedBox(width: 8),
                ],
              ),
            ),
            Expanded(
              child: tasks.isEmpty
                  ? Center(
                      child: Text(
                        'Пока пусто',
                        style: TextStyle(
                          fontSize: 14,
                          color: dark ? KanbanColors.descDark : KanbanColors.descLight,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                      itemCount: tasks.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final task = tasks[i];
                        return TaktTaskCardShadowed(
                          task: task,
                          isDone: column.isDone || task.isDone,
                          onTap: () => onOpenTask(task),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
