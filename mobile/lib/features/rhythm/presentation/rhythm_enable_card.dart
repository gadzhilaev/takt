import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/project_actions.dart';
import '../../board/cubit/board_cubit.dart';

/// Карточка для admin, когда в проекте выключен ежедневный чек-ин.
class RhythmEnableCard extends StatelessWidget {
  const RhythmEnableCard({super.key, this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 8)});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BoardCubit, BoardState>(
      buildWhen: (a, b) => a.project?.id != b.project?.id || a.project?.rhythm != b.project?.rhythm,
      builder: (context, state) {
        final project = state.project;
        final me = context.read<BoardCubit>().currentUserId;
        if (project == null || me == null) return const SizedBox.shrink();
        if (project.rhythm.enabled) return const SizedBox.shrink();
        if (!isProjectOwner(project, me)) return const SizedBox.shrink();

        final dark = Theme.of(context).brightness == Brightness.dark;
        final muted = dark ? TaktColors.mutedDark : TaktColors.muted;

        return Padding(
          padding: padding,
          child: Material(
            color: dark ? TaktColors.surfaceDark : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: dark ? TaktColors.borderDark : TaktColors.border),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => renameProjectFlow(context, project: project),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    AppIcon(
                      AppIcons.circleCheck,
                      size: 20,
                      color: dark ? TaktColors.accentDark : TaktColors.accent,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Включите ежедневный чек-ин',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Команда будет отвечать за 10 секунд — задачи обновятся сами, а в сводке появится картина дня.',
                            style: TextStyle(fontSize: 13, height: 1.35, color: muted),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: muted),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
