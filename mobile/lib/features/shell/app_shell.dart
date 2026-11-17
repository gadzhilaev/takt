import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/project_actions.dart';
import '../../shared/widgets/swipe_back_edge.dart';
import '../../shared/widgets/takt_app_bar.dart';
import '../board/cubit/board_cubit.dart';
import '../projects/presentation/projects_welcome_page.dart';
import 'takt_bottom_nav.dart';

/// Фиксированные AppBar + bottom nav; листается только body ([SlidingBranchStack]).
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

/// Ветки оболочки: 0 доска, 1 мои задачи, 2 сводка, 3 профиль.
const _digestIdx = 2;
const _profileIdx = 3;

class _AppShellState extends State<AppShell> {
  StatefulNavigationShell get navigationShell => widget.navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  void _backToProjects() {
    context.read<BoardCubit>().clearProject();
    context.go('/projects');
  }

  Future<void> _openProjectMenu() async {
    final board = context.read<BoardCubit>();
    final project = board.state.project;
    if (project == null) return;
    await showProjectActionsMenu(
      context,
      project: project,
      currentUserId: board.currentUserId,
      onChanged: () {
        if (!mounted) return;
        board.refreshProjects(forceLoading: true);
      },
    );
  }

  PreferredSizeWidget _buildAppBar({
    required int idx,
    required bool dark,
    required String? projectName,
    required bool hasProject,
  }) {
    if (idx == _profileIdx) {
      return const TaktAppBar(title: 'Профиль');
    }

    if (projectName == null || projectName.isEmpty) {
      return const TaktAppBar(title: 'Доска');
    }

    final editAction = hasProject
        ? [
            IconButton(
              tooltip: 'Проект',
              visualDensity: VisualDensity.compact,
              onPressed: _openProjectMenu,
              icon: AppIcon(
                AppIcons.edit,
                size: 22,
                color: dark ? TaktColors.foregroundDark : TaktColors.graphite,
              ),
            ),
            const SizedBox(width: 4),
          ]
        : null;

    if (idx == _digestIdx) {
      return TaktAppBar(
        title: 'Сводка',
        subtitle: projectName,
        onBack: _backToProjects,
        actions: editAction,
      );
    }

    if (idx == 1) {
      return TaktAppBar(
        title: 'Мои задачи',
        subtitle: projectName,
        onBack: _backToProjects,
        actions: editAction,
      );
    }

    return TaktAppBar(
      title: projectName,
      subtitle: 'Доска проекта',
      onBack: _backToProjects,
      actions: editAction,
    );
  }

  @override
  Widget build(BuildContext context) {
    final boardState = context.watch<BoardCubit>().state;
    final hasProject = boardState.project != null;
    final projectName = boardState.project?.name;
    final idx = navigationShell.currentIndex;
    final dark = Theme.of(context).brightness == Brightness.dark;

    // Без проекта вкладки проекта скрыты; если уже на одной из них — на главную.
    if (!hasProject && (idx == 1 || idx == _digestIdx)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/projects');
      });
    }

    final items = <TaktBottomNavItem>[
      TaktBottomNavItem(
        label: 'Главная',
        icon: AppIcons.home,
        selected: !hasProject && idx == 0,
        onTap: () {
          if (hasProject) {
            _backToProjects();
          } else {
            context.go('/projects');
          }
        },
      ),
      if (hasProject) ...[
        TaktBottomNavItem(
          label: 'Доска',
          icon: AppIcons.inbox,
          selected: idx == 0,
          onTap: () => _goBranch(0),
        ),
        TaktBottomNavItem(
          label: 'Мои задачи',
          icon: AppIcons.myTasks,
          selected: idx == 1,
          onTap: () => _goBranch(1),
        ),
        TaktBottomNavItem(
          label: 'Сводка',
          icon: AppIcons.status,
          selected: idx == _digestIdx,
          onTap: () => _goBranch(_digestIdx),
        ),
      ],
      TaktBottomNavItem(
        label: 'Профиль',
        icon: AppIcons.profile,
        selected: idx == _profileIdx,
        onTap: () => _goBranch(_profileIdx),
      ),
    ];

    final canSwipeBack = hasProject && (idx == 0 || idx == 1 || idx == _digestIdx);

    return SwipeBackEdge(
      enabled: canSwipeBack,
      onBack: _backToProjects,
      underlay: const ProjectsWelcomePage(previewOnly: true),
      child: Scaffold(
        appBar: _buildAppBar(
          idx: idx,
          dark: dark,
          projectName: projectName,
          hasProject: hasProject,
        ),
        body: navigationShell,
        bottomNavigationBar: TaktBottomNav(items: items),
      ),
    );
  }
}
