import 'package:flutter/material.dart';

import '../../core/kanban_colors.dart';
import '../../shared/widgets/app_icon.dart';
import '../../core/theme.dart';
import '../models/models.dart';
import 'task_card.dart';

/// One Kanban column pane (shared by Home and My Tasks).
/// Height follows tasks (как `self-start` на сайте), не растягивается на весь экран.
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

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 4),
        child: Material(
          color: bg,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                        icon: AppIcon(
                          AppIcons.add,
                          size: 20,
                          color: dark ? TaktColors.accentDark : TaktColors.accent,
                        ),
                      ),
                    ] else
                      const SizedBox(width: 8),
                  ],
                ),
              ),
              if (tasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
                  child: Text(
                    'Пока пусто',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: dark ? KanbanColors.descDark : KanbanColors.descLight,
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < tasks.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        TaktTaskCardShadowed(
                          task: tasks[i],
                          isDone: column.isDone || tasks[i].isDone,
                          onTap: () => onOpenTask(tasks[i]),
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
