import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../shared/widgets/app_icon.dart';

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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? TaktColors.surfaceDark : TaktColors.surface;
    final border = dark ? TaktColors.borderDark : TaktColors.border;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    final active = dark ? TaktColors.accentDark : TaktColors.accent;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Material(
        color: bg,
        elevation: 0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: border, width: 0.5)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 52,
              child: Row(
                children: [
                  _NavItem(
                    label: 'Главная',
                    icon: AppIcons.home,
                    selected: navigationShell.currentIndex == 0,
                    active: active,
                    muted: muted,
                    onTap: () => _goBranch(0),
                  ),
                  _NavItem(
                    label: 'Мои задачи',
                    icon: AppIcons.myTasks,
                    selected: navigationShell.currentIndex == 1,
                    active: active,
                    muted: muted,
                    onTap: () => _goBranch(1),
                  ),
                  _NavItem(
                    label: 'Профиль',
                    icon: AppIcons.profile,
                    selected: navigationShell.currentIndex == 2,
                    active: active,
                    muted: muted,
                    onTap: () => _goBranch(2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.active,
    required this.muted,
    required this.onTap,
  });

  final String label;
  final String icon;
  final bool selected;
  final Color active;
  final Color muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? active : muted;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.1,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
