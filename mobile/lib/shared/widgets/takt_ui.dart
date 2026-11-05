import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'app_icon.dart';

/// Compact primary/secondary/ghost buttons — not oversized M3 defaults.
class TaktButton extends StatelessWidget {
  const TaktButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = TaktButtonVariant.primary,
    this.expand = false,
    this.icon,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final TaktButtonVariant variant;
  final bool expand;
  final String? icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          AppIcon(icon!, size: 18),
          const SizedBox(width: 6),
        ],
        Text(label),
      ],
    );

    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(TaktRadii.md));
    final size = Size(expand ? double.infinity : 0, 40);

    switch (variant) {
      case TaktButtonVariant.primary:
        return FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: size,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            backgroundColor: danger ? TaktColors.danger : (dark ? TaktColors.accentDark : TaktColors.accent),
            foregroundColor: Colors.white,
            // Avoid custom textStyle — inherit mismatch breaks TextStyle.lerp on press.
            shape: shape,
          ),
          child: child,
        );
      case TaktButtonVariant.secondary:
        return OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: size,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            foregroundColor: dark ? TaktColors.foregroundDark : TaktColors.graphite,
            side: BorderSide(color: dark ? TaktColors.borderStrongDark : TaktColors.borderStrong),
            shape: shape,
          ),
          child: child,
        );
      case TaktButtonVariant.ghost:
        return TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: size,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            foregroundColor: danger
                ? TaktColors.danger
                : (dark ? TaktColors.accentDark : TaktColors.accent),
          ),
          child: child,
        );
    }
  }
}

enum TaktButtonVariant { primary, secondary, ghost }

class TaktCard extends StatelessWidget {
  const TaktCard({super.key, required this.child, this.padding, this.onTap});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(TaktRadii.md);
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? TaktColors.surfaceDark : TaktColors.surface,
        borderRadius: radius,
        border: Border.all(color: dark ? TaktColors.borderDark : TaktColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.22 : 0.04),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(TaktSpace.md),
        child: child,
      ),
    );
    if (onTap == null) return box;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: box,
    );
  }
}

class TaktSection extends StatelessWidget {
  const TaktSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 0),
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.25,
                    color: dark ? TaktColors.mutedDark : TaktColors.muted,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class TaktListTile extends StatelessWidget {
  const TaktListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.dense = true,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      dense: dense,
      enableFeedback: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: leading,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: dark ? TaktColors.foregroundDark : TaktColors.graphite,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: dark ? TaktColors.mutedDark : TaktColors.muted,
              ),
            ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class TaktEmptyState extends StatelessWidget {
  const TaktEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = AppIcons.inbox,
    this.action,
  });

  final String title;
  final String? subtitle;
  final String icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(icon, size: 36, color: muted),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: dark ? TaktColors.foregroundDark : TaktColors.graphite,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.4, color: muted),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class TaktTextField extends StatelessWidget {
  const TaktTextField({
    super.key,
    this.controller,
    this.label,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController? controller;
  final String? label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}

/// Web `.label-text` — 12px semibold muted above a field.
class TaktFieldLabel extends StatelessWidget {
  const TaktFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: dark ? TaktColors.mutedDark : TaktColors.muted,
      ),
    );
  }
}

/// Web `.field` trigger (select / multi-select style): bordered row + chevron.
class TaktFieldTrigger extends StatelessWidget {
  const TaktFieldTrigger({
    super.key,
    required this.valueText,
    required this.onTap,
    this.placeholder = 'Выбрать',
    this.enabled = true,
    this.leading,
  });

  final String? valueText;
  final String placeholder;
  final VoidCallback? onTap;
  final bool enabled;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = dark ? TaktColors.borderDark : TaktColors.border;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    final fg = dark ? TaktColors.foregroundDark : TaktColors.graphite;
    final surface = dark ? TaktColors.surfaceDark : TaktColors.surface;
    final empty = valueText == null || valueText!.trim().isEmpty;

    return Material(
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TaktRadii.md),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(TaktRadii.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    empty ? placeholder : valueText!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                      color: empty ? muted : fg,
                    ),
                  ),
                ),
                AppIcon(AppIcons.chevronDown, size: 16, color: muted.withValues(alpha: 0.7)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Label + child stack with web drawer spacing (`space-y` field block).
class TaktFormField extends StatelessWidget {
  const TaktFormField({
    super.key,
    required this.label,
    required this.child,
    this.bottomGap = 16,
  });

  final String label;
  final Widget child;
  final double bottomGap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TaktFieldLabel(label),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

/// Strip internal demo markers from notification copy.
String taktSanitizeNotificationText(String? raw) {
  if (raw == null) return '';
  return raw
      .replaceAll(RegExp(r'\[demo-seed\]\s*', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String taktRelativeTime(String iso) {
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'сейчас';
  if (diff.inMinutes < 60) return '${diff.inMinutes} мин';
  if (diff.inHours < 24) return '${diff.inHours} ч';
  if (diff.inDays < 7) return '${diff.inDays} дн.';
  return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}';
}

String taktNotificationIcon(String kind) => AppIcon.notificationKind(kind);

String taktNotificationKindLabel(String kind) {
  switch (kind) {
    case 'task_assigned':
    case 'assignee_added':
      return 'Новая задача';
    case 'task_completed':
      return 'Задача выполнена';
    case 'task_due_soon':
      return 'Скоро срок';
    case 'task_overdue':
      return 'Срок просрочен';
    case 'status_changed':
    case 'task_moved':
      return 'Изменение задачи';
    case 'comment':
    case 'mention':
      return 'Комментарий';
    case 'project_invite':
    case 'invite':
      return 'Приглашение';
    case 'leave_request':
      return 'Заявка на выход';
    case 'leave_approved':
    case 'member_removed':
      return 'Участник удалён';
    case 'leave_rejected':
      return 'Заявка отклонена';
    default:
      return 'Уведомление';
  }
}

enum TaktDateGroup { today, yesterday, earlier }

TaktDateGroup taktDateGroup(String iso, {DateTime? now}) {
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return TaktDateGroup.earlier;
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return TaktDateGroup.today;
  if (diff == 1) return TaktDateGroup.yesterday;
  return TaktDateGroup.earlier;
}

String taktDateGroupLabel(TaktDateGroup g) {
  switch (g) {
    case TaktDateGroup.today:
      return 'Сегодня';
    case TaktDateGroup.yesterday:
      return 'Вчера';
    case TaktDateGroup.earlier:
      return 'Ранее';
  }
}

({String detail, String projectLine}) taktParseNotificationBody(String? body) {
  final raw = (body ?? '').replaceAll(RegExp(r'\[demo-seed\]\s*', caseSensitive: false), '').trim();
  if (raw.isEmpty) return (detail: '', projectLine: '');
  final lines = raw.split(RegExp(r'\n+')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  if (lines.length >= 2 && RegExp(r'^Проект\s+', caseSensitive: false).hasMatch(lines.last)) {
    return (detail: lines.sublist(0, lines.length - 1).join(' '), projectLine: lines.last);
  }
  final project = lines.where((l) => RegExp(r'^Проект\s+', caseSensitive: false).hasMatch(l)).firstOrNull;
  if (project != null) {
    return (
      detail: lines.where((l) => l != project).join(' '),
      projectLine: project,
    );
  }
  return (detail: lines.join(' '), projectLine: '');
}

/// Card fields for list UI. Normalizes legacy long assignment titles.
({String subject, String detail, String projectLine}) taktNotificationCardParts({
  required String kind,
  required String title,
  String? body,
  String? projectName,
}) {
  final cleanTitle = taktSanitizeNotificationText(title);
  final parsed = taktParseNotificationBody(body);
  var detail = parsed.detail;
  if (detail.toLowerCase().contains('открывается по ссылке')) {
    detail = '';
  }
  var project = parsed.projectLine;
  if (project.isEmpty && projectName != null && projectName.trim().isNotEmpty) {
    project = 'Проект ${projectName.trim()}';
  }

  final quote = RegExp(r'[«"](.+?)[»"]').firstMatch(cleanTitle);
  final assign = RegExp(r'^(.+?)\s+(назначил[аи]?)\b', caseSensitive: false).firstMatch(cleanTitle);
  final complete = RegExp(r'^(.+?)\s+(завершил[аи]?)\b', caseSensitive: false).firstMatch(cleanTitle);

  if ((kind == 'task_assigned' || kind == 'assignee_added') && assign != null && quote != null) {
    final actor = assign.group(1)!.trim();
    final verb = assign.group(2)!.toLowerCase();
    return (subject: quote.group(1)!.trim(), detail: '$actor $verb вам задачу', projectLine: project);
  }
  if (kind == 'task_completed' && complete != null && quote != null) {
    final actor = complete.group(1)!.trim();
    final verb = complete.group(2)!.toLowerCase();
    return (subject: quote.group(1)!.trim(), detail: '$actor $verb задачу', projectLine: project);
  }

  return (subject: cleanTitle, detail: detail, projectLine: project);
}
