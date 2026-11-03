import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'app_icon.dart';
import 'takt_mark.dart';

/// Standard Takt AppBar: fixed height, left title, optional leading/actions.
///
/// By default shows the brand mark before [title]. Pass [titleWidget] to
/// replace that (e.g. full [TaktLogo] on the home screen).
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
    this.showMark = true,
  });

  final String title;
  /// When set, replaces mark + [title] (e.g. [TaktLogo] on home).
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final VoidCallback? onClose;
  final bool centerTitle;
  /// Brand symbol before the title. Ignored when [titleWidget] is set.
  final bool showMark;

  static const double height = 48;
  static const double markHeight = 20;

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
    final titleText = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: titleStyle,
    );
    final Widget resolvedTitle;
    if (titleWidget != null) {
      resolvedTitle = titleWidget!;
    } else if (showMark) {
      resolvedTitle = Row(
        children: [
          const TaktMark(height: markHeight, semanticLabel: null),
          const SizedBox(width: 8),
          Expanded(child: titleText),
        ],
      );
    } else {
      resolvedTitle = titleText;
    }

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
