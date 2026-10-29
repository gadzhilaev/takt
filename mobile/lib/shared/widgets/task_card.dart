import 'package:flutter/material.dart';

import '../../core/kanban_colors.dart';
import '../../shared/widgets/app_icon.dart';
import '../../core/theme.dart';
import '../models/models.dart';
import 'urgency_badge.dart';
import 'user_avatar.dart';

class TaktTaskCard extends StatelessWidget {
  const TaktTaskCard({
    super.key,
    required this.task,
    required this.onTap,
    this.isDone = false,
    this.subtitle,
  });

  final TaskItem task;
  final VoidCallback onTap;
  final bool isDone;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final done = isDone || task.isDone;
    final urgency = KanbanColors.urgency(task.priority, dark: dark);
    final desc = task.description?.trim();
    final hasDesc = desc != null && desc.isNotEmpty;
    final radius = BorderRadius.circular(TaktRadii.md);
    final borderColor = dark ? KanbanColors.cardBorderDark : KanbanColors.cardBorderLight;
    final bg = dark ? KanbanColors.cardBgDark : KanbanColors.cardBgLight;

    return Material(
      color: bg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(color: urgency.fg, child: const SizedBox(width: 2.5)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (done) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: AppIcon(AppIcons.check, size: 13, color: dark ? TaktColors.successDark : TaktColors.success,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              task.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: taktTitleStyle(dark: dark, done: done),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      UrgencyBadge(priority: task.priority),
                      if (hasDesc) ...[
                        const SizedBox(height: 4),
                        Text(
                          desc,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: taktDescStyle(dark: dark, done: done),
                        ),
                      ],
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: dark ? TaktColors.mutedDark : TaktColors.muted,
                          ),
                        ),
                      ],
                      if (task.assignees.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Opacity(
                          opacity: done ? 0.85 : 1,
                          child: TaktAssigneeRow(
                            names: task.assignees.map((a) => a.name).toList(),
                            avatarUrls: task.assignees.map((a) => a.avatarUrl).toList(),
                            size: 18,
                          ),
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

class TaktTaskCardShadowed extends StatelessWidget {
  const TaktTaskCardShadowed({
    super.key,
    required this.task,
    required this.onTap,
    this.isDone = false,
    this.subtitle,
  });

  final TaskItem task;
  final VoidCallback onTap;
  final bool isDone;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return TaktTaskCard(
      task: task,
      onTap: onTap,
      isDone: isDone,
      subtitle: subtitle,
    );
  }
}
