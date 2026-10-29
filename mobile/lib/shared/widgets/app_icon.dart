import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme.dart';

/// Semantic Lucide icon names — keep in sync with `shared/icons/manifest.json`
/// and `frontend/src/components/ui/app-icon.tsx`.
abstract final class AppIcons {
  static const home = 'home';
  static const myTasks = 'my-tasks';
  static const profile = 'profile';
  static const back = 'back';
  static const close = 'close';
  static const more = 'more';
  static const add = 'add';
  static const edit = 'edit';
  static const delete = 'delete';
  static const check = 'check';
  static const chevronDown = 'chevron-down';
  static const chevronRight = 'chevron-right';
  static const chevronLeft = 'chevron-left';
  static const notifications = 'notifications';
  static const search = 'search';
  static const settings = 'settings';
  static const lock = 'lock';
  static const logout = 'logout';
  static const invite = 'invite';
  static const theme = 'theme';
  static const mail = 'mail';
  static const eye = 'eye';
  static const eyeOff = 'eye-off';
  static const menu = 'menu';
  static const camera = 'camera';
  static const copy = 'copy';
  static const monitor = 'monitor';
  static const moon = 'moon';
  static const sun = 'sun';
  static const alert = 'alert';
  static const message = 'message';
  static const status = 'status';
  static const inbox = 'inbox';
  static const circle = 'circle';
  static const circleCheck = 'circle-check';
  static const assignment = 'assignment';
  static const forum = 'forum';

  static const strokeWidth = 1.75;
}

/// Lucide SVG icon from shared catalog (`assets/icons` → `shared/icons`).
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.name, {
    super.key,
    this.size = 20,
    this.color,
    this.active = false,
    this.semanticLabel,
  }); // ignore: prefer_const_constructors_in_immutables — SVG asset path is const-safe

  final String name;
  final double size;
  final Color? color;
  final bool active;
  final String? semanticLabel;

  static String notificationKind(String kind) {
    switch (kind) {
      case 'task_assigned':
      case 'assignee_added':
        return AppIcons.invite;
      case 'task_completed':
        return AppIcons.circleCheck;
      case 'status_changed':
        return AppIcons.status;
      case 'comment':
        return AppIcons.message;
      case 'invite':
      case 'project_invite':
        return AppIcons.mail;
      case 'leave_request':
      case 'member_removed':
      case 'leave_approved':
      case 'leave_rejected':
        return AppIcons.profile;
      default:
        return AppIcons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final resolved = color ??
        (active
            ? (dark ? TaktColors.accentDark : TaktColors.accent)
            : (dark ? TaktColors.foregroundDark : TaktColors.graphite));

    return SvgPicture.asset(
      'assets/icons/$name.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
      colorFilter: ColorFilter.mode(resolved, BlendMode.srcIn),
    );
  }
}
