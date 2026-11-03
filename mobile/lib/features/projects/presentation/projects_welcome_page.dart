import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/kanban_colors.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/project_hub.dart';
import '../../../shared/widgets/takt_app_bar.dart';
import '../../../shared/widgets/takt_mark.dart';
import '../../../shared/widgets/takt_sheet.dart';
import '../../../shared/widgets/takt_ui.dart';
import '../../board/cubit/board_cubit.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../shell/takt_bottom_nav.dart';

/// Welcome / project picker. Bottom nav: Главная / Мои задачи / Профиль.
class ProjectsWelcomePage extends StatefulWidget {
  const ProjectsWelcomePage({super.key});

  @override
  State<ProjectsWelcomePage> createState() => _ProjectsWelcomePageState();
}

class _ProjectsWelcomePageState extends State<ProjectsWelcomePage> {
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
    cubit.clearProject();
    if (cubit.state.projects.isEmpty) {
      // Cold path: may show spinner only until disk/network fills projects.
      await cubit.bootstrap();
    }
    // Если список уже с splash — не дёргаем /projects снова (только pull-to-refresh).
  }

  Future<void> _loadUnread() async {
    try {
      final list = await context.read<NotificationsRepository>().list(unreadOnly: true);
      if (mounted) setState(() => _unread = list.length);
    } catch (_) {
      /* ignore */
    }
  }

  Future<void> _onUserRefresh() async {
    await context.read<BoardCubit>().refreshProjects(forceLoading: true);
    await _loadUnread();
  }

  Future<void> _openProject(String id) async {
    // openProject returns after cache/memory hydrate; network may still run.
    await context.read<BoardCubit>().openProject(id);
    if (!mounted) return;
    if (context.read<BoardCubit>().state.project?.id == id) {
      context.go('/board');
    }
  }

  Future<void> _createProject() async {
    final controller = TextEditingController();
    final ok = await showTaktSheet(
      context: context,
      title: 'Новый проект',
      confirmLabel: 'Создать',
      body: TaktTextField(controller: controller, label: 'Название'),
      onConfirm: () => controller.text.trim().isNotEmpty,
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
        // После splash — без полноэкранных лоадеров: пустой хаб или список сразу.
        return Scaffold(
          backgroundColor: bg,
          appBar: TaktAppBar(
            title: 'Takt',
            titleWidget: const TaktLogo(height: 26),
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
          body: state.projects.isEmpty
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
                          onPressed: state.loading ? null : _createProject,
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
                  onRefresh: _onUserRefresh,
                ),
          bottomNavigationBar: TaktBottomNav(
            items: [
              TaktBottomNavItem(
                label: 'Главная',
                icon: AppIcons.home,
                selected: true,
                onTap: () {},
              ),
              TaktBottomNavItem(
                label: 'Мои задачи',
                icon: AppIcons.myTasks,
                selected: false,
                onTap: () => context.go('/my-tasks'),
              ),
              TaktBottomNavItem(
                label: 'Профиль',
                icon: AppIcons.profile,
                selected: false,
                onTap: () => context.go('/profile'),
              ),
            ],
          ),
        );
      },
    );
  }
}
