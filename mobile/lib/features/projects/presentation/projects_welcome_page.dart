import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/kanban_colors.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/project_hub.dart';
import '../../../shared/widgets/takt_app_bar.dart';
import '../../../shared/widgets/takt_mark.dart';
import '../../board/cubit/board_cubit.dart';
import '../../notifications/data/notifications_repository.dart';

/// Welcome / project picker — outside bottom navigation.
class ProjectsWelcomePage extends StatefulWidget {
  const ProjectsWelcomePage({super.key});

  @override
  State<ProjectsWelcomePage> createState() => _ProjectsWelcomePageState();
}

class _ProjectsWelcomePageState extends State<ProjectsWelcomePage> {
  bool _loading = true;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _loadUnread();
  }

  Future<void> _bootstrap() async {
    final cubit = context.read<BoardCubit>();
    // Always land on hub: clear active board until user picks a project.
    if (cubit.state.projects.isEmpty) {
      await cubit.bootstrap();
    } else {
      cubit.clearProject();
      await cubit.refreshProjects();
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadUnread() async {
    try {
      final list = await context.read<NotificationsRepository>().list(unreadOnly: true);
      if (mounted) setState(() => _unread = list.length);
    } catch (_) {
      /* ignore */
    }
  }

  Future<void> _openProject(String id) async {
    await context.read<BoardCubit>().openProject(id);
    if (!mounted) return;
    context.go('/board');
  }

  Future<void> _createProject() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый проект'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Название'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Создать')),
        ],
      ),
    );
    if (ok == true && controller.text.trim().isNotEmpty && mounted) {
      await context.read<BoardCubit>().createProject(controller.text.trim());
      if (!mounted) return;
      if (context.read<BoardCubit>().state.project != null) {
        context.go('/board');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? KanbanColors.boardBgDark : KanbanColors.boardBgLight;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;

    return BlocBuilder<BoardCubit, BoardState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: bg,
          appBar: TaktAppBar(
            title: 'Проекты',
            leading: const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TaktMark(height: 24),
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Уведомления',
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  await context.push('/notifications');
                  _loadUnread();
                },
                icon: Badge(
                  isLabelVisible: _unread > 0,
                  smallSize: 8,
                  backgroundColor: TaktColors.urgent,
                  child: AppIcon(
                    AppIcons.notifications,
                    size: 22,
                    color: dark ? TaktColors.foregroundDark : TaktColors.graphite,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: _loading || (state.loading && state.projects.isEmpty)
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                      child: Text(
                        'Выберите проект, чтобы открыть доску',
                        style: TextStyle(fontSize: 13, height: 1.35, color: muted),
                      ),
                    ),
                    Expanded(
                      child: state.projects.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Создайте первый проект',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Доска откроется сразу: четыре стандартных столбца.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: muted, height: 1.4),
                                    ),
                                    const SizedBox(height: 24),
                                    FilledButton(
                                      onPressed: _createProject,
                                      child: const Text('Новый проект'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ProjectHub(
                              projects: state.projects,
                              currentUserId: context.read<BoardCubit>().currentUserId,
                              onOpenProject: _openProject,
                              onCreateProject: _createProject,
                              onProjectsChanged: () =>
                                  context.read<BoardCubit>().refreshProjects(),
                            ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
