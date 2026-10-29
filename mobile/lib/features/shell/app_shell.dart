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
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: TaktBottomNav(
        items: [
          TaktBottomNavItem(
            label: 'Главная',
            icon: AppIcons.home,
            selected: navigationShell.currentIndex == 0,
            onTap: () {
              final hasProject = context.read<BoardCubit>().state.project != null;
              if (hasProject) {
                _goBranch(0);
              } else {
                context.go('/projects');
              }
            },
          ),
          TaktBottomNavItem(
            label: 'Мои задачи',
            icon: AppIcons.myTasks,
            selected: navigationShell.currentIndex == 1,
            onTap: () => _goBranch(1),
          ),
          TaktBottomNavItem(
            label: 'Профиль',
            icon: AppIcons.profile,
            selected: navigationShell.currentIndex == 2,
            onTap: () => _goBranch(2),
          ),
        ],
      ),
    );
  }
}
