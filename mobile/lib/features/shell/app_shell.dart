import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/app_icon.dart';
import '../board/cubit/board_cubit.dart';
import 'takt_bottom_nav.dart';

/// Compact bottom navigation — active = accent color + weight, no strip/pill.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasProject = context.watch<BoardCubit>().state.project != null;
    final idx = navigationShell.currentIndex;

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

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: TaktBottomNav(items: items),
    );
  }
}
