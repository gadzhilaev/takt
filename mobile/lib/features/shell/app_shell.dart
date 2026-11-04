import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/swipe_back_edge.dart';
import '../../shared/widgets/takt_app_bar.dart';
import '../board/cubit/board_cubit.dart';
import '../notifications/data/notifications_repository.dart';
import '../projects/presentation/projects_welcome_page.dart';
import 'takt_bottom_nav.dart';

/// Фиксированные AppBar + bottom nav; листается только body ([SlidingBranchStack]).
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _unread = 0;

  StatefulNavigationShell get navigationShell => widget.navigationShell;

  @override
  void initState() {
    super.initState();
    _loadUnread();
  }

  Future<void> _loadUnread() async {
    try {
      final list = await context.read<NotificationsRepository>().list(unreadOnly: true);
      if (mounted) setState(() => _unread = list.length);
    } catch (_) {
      /* ignore */
    }
  }

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

  PreferredSizeWidget _buildAppBar({
    required int idx,
    required bool dark,
    required String? projectName,
  }) {
    if (idx == 2) {
      return const TaktAppBar(title: 'Профиль');
    }

    if (projectName == null || projectName.isEmpty) {
      return const TaktAppBar(title: 'Доска');
    }

    if (idx == 1) {
      return TaktAppBar(
        title: 'Мои задачи',
        subtitle: projectName,
        onBack: _backToProjects,
      );
    }

    return TaktAppBar(
      title: projectName,
      subtitle: 'Доска проекта',
      onBack: _backToProjects,
      actions: [
        IconButton(
          tooltip: 'Уведомления',
          visualDensity: VisualDensity.compact,
          onPressed: () async {
            await context.push('/notifications');
            await _loadUnread();
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final boardState = context.watch<BoardCubit>().state;
    final hasProject = boardState.project != null;
    final projectName = boardState.project?.name;
    final idx = navigationShell.currentIndex;
    final dark = Theme.of(context).brightness == Brightness.dark;

    // Без проекта вкладка «Мои задачи» скрыта; если уже на ней — на главную.
    if (!hasProject && idx == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/projects');
      });
    }

    final items = <TaktBottomNavItem>[
      TaktBottomNavItem(
        label: 'Главная',
        icon: AppIcons.home,
        selected: idx == 0,
        onTap: () {
          if (hasProject) {
            _goBranch(0);
          } else {
            context.go('/projects');
          }
        },
      ),
      if (hasProject)
        TaktBottomNavItem(
          label: 'Мои задачи',
          icon: AppIcons.myTasks,
          selected: idx == 1,
          onTap: () => _goBranch(1),
        ),
      TaktBottomNavItem(
        label: 'Профиль',
        icon: AppIcons.profile,
        selected: idx == 2,
        onTap: () => _goBranch(2),
      ),
    ];

    final canSwipeBack = hasProject && (idx == 0 || idx == 1);

    return SwipeBackEdge(
      enabled: canSwipeBack,
      onBack: _backToProjects,
      underlay: const ProjectsWelcomePage(previewOnly: true),
      child: Scaffold(
        appBar: _buildAppBar(idx: idx, dark: dark, projectName: projectName),
        body: navigationShell,
        bottomNavigationBar: TaktBottomNav(items: items),
      ),
    );
  }
}
