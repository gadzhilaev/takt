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
    this.onTaskDropped,
    this.onDraggingChanged,
    this.onDragPointer,
    this.draggable = true,
  });

  final StatusColumn column;
  final List<TaskItem> tasks;
  final bool dark;
  final ValueChanged<TaskItem> onOpenTask;
  final VoidCallback? onAdd;
  /// Drop onto this column (status change). Same-column drops ignored.
  final ValueChanged<TaskItem>? onTaskDropped;
  final ValueChanged<bool>? onDraggingChanged;
  /// Global pointer while dragging — used for edge page scroll.
  final ValueChanged<Offset>? onDragPointer;
  final bool draggable;

  @override
  Widget build(BuildContext context) {
    final bg = KanbanColors.columnBackground(column.color, dark: dark);
    final border = KanbanColors.columnBorder(column.color, dark: dark);
    final accent = KanbanColors.columnAccent(column.color);
    final radius = BorderRadius.circular(TaktRadii.lg);
    final canDrop = onTaskDropped != null && draggable;

    Widget pane({required bool highlighted}) {
      final dropBorder = highlighted
          ? (dark ? TaktColors.accentDark : TaktColors.accent)
          : border;
      final dropBg = highlighted
          ? Color.alphaBlend(
              (dark ? TaktColors.accentDark : TaktColors.accent).withValues(alpha: 0.12),
              bg,
            )
          : bg;

      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 4),
          child: Material(
            color: dropBg,
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(color: dropBorder, width: highlighted ? 1.5 : 1),
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
                      highlighted ? 'Отпустите сюда' : 'Пока пусто',
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
                          _DraggableTaskCard(
                            task: tasks[i],
                            isDone: column.isDone || tasks[i].isDone,
                            dark: dark,
                            enabled: canDrop,
                            onOpen: () => onOpenTask(tasks[i]),
                            onDraggingChanged: onDraggingChanged,
                            onDragPointer: onDragPointer,
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

    if (!canDrop) {
      return pane(highlighted: false);
    }

    return DragTarget<TaskItem>(
      onWillAcceptWithDetails: (details) => details.data.statusId != column.id,
      onAcceptWithDetails: (details) => onTaskDropped!(details.data),
      builder: (context, candidate, rejected) {
        return pane(highlighted: candidate.isNotEmpty);
      },
    );
  }
}

class _DraggableTaskCard extends StatelessWidget {
  const _DraggableTaskCard({
    required this.task,
    required this.isDone,
    required this.dark,
    required this.enabled,
    required this.onOpen,
    this.onDraggingChanged,
    this.onDragPointer,
  });

  final TaskItem task;
  final bool isDone;
  final bool dark;
  final bool enabled;
  final VoidCallback onOpen;
  final ValueChanged<bool>? onDraggingChanged;
  final ValueChanged<Offset>? onDragPointer;

  @override
  Widget build(BuildContext context) {
    final card = TaktTaskCardShadowed(
      task: task,
      isDone: isDone,
      onTap: onOpen,
    );
    if (!enabled) return card;

    final feedbackWidth = MediaQuery.sizeOf(context).width * 0.82;

    return LongPressDraggable<TaskItem>(
      data: task,
      delay: const Duration(milliseconds: 200),
      hapticFeedbackOnStart: true,
      onDragStarted: () => onDraggingChanged?.call(true),
      onDragUpdate: (details) => onDragPointer?.call(details.globalPosition),
      onDragEnd: (_) => onDraggingChanged?.call(false),
      onDraggableCanceled: (_, _) => onDraggingChanged?.call(false),
      feedback: Material(
        color: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: dark ? 0.5 : 0.25),
        borderRadius: BorderRadius.circular(TaktRadii.md),
        child: SizedBox(
          width: feedbackWidth,
          child: TaktTaskCard(
            task: task,
            isDone: isDone,
            onTap: () {},
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }
}
