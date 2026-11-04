import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../shared/widgets/app_icon.dart';

class TaktBottomNavItem {
  const TaktBottomNavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onTap;
}

/// Bottom nav: active = accent + soft chip; inactive = muted (чётко различаются).
class TaktBottomNav extends StatelessWidget {
  const TaktBottomNav({super.key, required this.items});

  final List<TaktBottomNavItem> items;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? TaktColors.surfaceDark : TaktColors.surface;
    final border = dark ? TaktColors.borderDark : TaktColors.border;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    final active = dark ? TaktColors.accentDark : TaktColors.accent;
    final soft = dark ? TaktColors.accentSoftDark : TaktColors.accentSoft;

    return Material(
      color: bg,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: border, width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                for (final item in items)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: item.onTap,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOut,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: item.selected ? soft : Colors.transparent,
                              borderRadius: BorderRadius.circular(TaktRadii.md),
                            ),
                            child: AppIcon(
                              item.icon,
                              size: 22,
                              color: item.selected
                                  ? active
                                  : muted.withValues(alpha: dark ? 0.75 : 0.65),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              height: 1.1,
                              fontWeight: item.selected ? FontWeight.w700 : FontWeight.w500,
                              color: item.selected
                                  ? active
                                  : muted.withValues(alpha: dark ? 0.8 : 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
