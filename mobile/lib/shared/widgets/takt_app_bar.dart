import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'app_icon.dart';

/// Standard Takt AppBar: fixed height, left title, optional leading/actions.
class TaktAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TaktAppBar({
    super.key,
    required this.title,
    this.titleWidget,
    this.leading,
    this.actions,
    this.onBack,
    this.onClose,
    this.centerTitle = false,
  });

  final String title;
  /// When set, replaces the string [title] (e.g. [TaktBrandLockup]).
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final VoidCallback? onClose;
  final bool centerTitle;

  static const double height = 48;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? TaktColors.foregroundDark : TaktColors.graphite;
    Widget? lead = leading;
    if (lead == null && onClose != null) {
      lead = IconButton(
        tooltip: 'Закрыть',
        visualDensity: VisualDensity.compact,
        onPressed: onClose,
        icon: AppIcon(AppIcons.close, size: 22, color: fg),
      );
    } else if (lead == null && onBack != null) {
      lead = IconButton(
        tooltip: 'Назад',
        visualDensity: VisualDensity.compact,
        onPressed: onBack,
        icon: AppIcon(AppIcons.back, size: 20, color: fg),
      );
    }

    final titleStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: fg,
    );
    final resolvedTitle = titleWidget ??
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        );

    return AppBar(
      toolbarHeight: height,
      titleSpacing: lead == null ? 16 : 0,
      centerTitle: centerTitle,
      leading: lead,
      title: resolvedTitle,
      actions: actions,
    );
  }
}
