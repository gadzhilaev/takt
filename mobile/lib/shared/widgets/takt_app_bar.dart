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
    this.subtitle,
    this.titleWidget,
    this.leading,
    this.actions,
    this.onBack,
    this.onClose,
    this.centerTitle = false,
    this.showMark = true,
  });

  final String title;
  /// Second line under [title] (e.g. project name on «Мои задачи»).
  final String? subtitle;
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
  static const double heightWithSubtitle = 56;
  static const double markHeight = 20;

  @override
  Size get preferredSize =>
      Size.fromHeight(subtitle != null && subtitle!.isNotEmpty ? heightWithSubtitle : height);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? TaktColors.foregroundDark : TaktColors.graphite;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    final barHeight = preferredSize.height;
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

    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          height: 1.15,
          color: fg,
        ) ??
        TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          height: 1.15,
          color: fg,
        );
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;
    final Widget titleBlock = hasSubtitle
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11.5,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                      color: muted,
                    ) ??
                    TextStyle(
                      fontSize: 11.5,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                      color: muted,
                    ),
              ),
            ],
          )
        : Text(
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
          Expanded(child: titleBlock),
        ],
      );
    } else {
      resolvedTitle = titleBlock;
    }

    return AppBar(
      toolbarHeight: barHeight,
      titleSpacing: lead == null ? 16 : 0,
      centerTitle: centerTitle,
      leading: lead,
      title: resolvedTitle,
      actions: actions,
    );
  }
}
