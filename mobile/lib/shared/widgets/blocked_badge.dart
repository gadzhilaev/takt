import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'app_icon.dart';

Color blockedColor(bool dark) => dark ? const Color(0xFFE0A146) : TaktColors.important;
Color blockedSoft(bool dark) =>
    dark ? const Color(0xFFE0A146).withValues(alpha: 0.16) : const Color(0xFFFBF1E3);

/// Чип «Застряла» на карточке — заметный, но спокойный.
class BlockedChip extends StatelessWidget {
  const BlockedChip({super.key, required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = blockedColor(dark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: blockedSoft(dark),
        borderRadius: BorderRadius.circular(TaktRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(AppIcons.alert, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            'Застряла',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

/// Блок «Застряла — причина» в карточке задачи.
class BlockedNotice extends StatelessWidget {
  const BlockedNotice({super.key, required this.dark, this.reason, this.byName});

  final bool dark;
  final String? reason;
  final String? byName;

  @override
  Widget build(BuildContext context) {
    final color = blockedColor(dark);
    final fg = dark ? TaktColors.foregroundDark : TaktColors.graphite;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    final hasReason = reason != null && reason!.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: blockedSoft(dark),
        borderRadius: BorderRadius.circular(TaktRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: AppIcon(AppIcons.alert, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: 14, height: 1.35, color: fg),
                    children: [
                      TextSpan(
                        text: 'Застряла',
                        style: TextStyle(fontWeight: FontWeight.w600, color: color),
                      ),
                      if (hasReason) TextSpan(text: ' — ${reason!.trim()}'),
                    ],
                  ),
                ),
                if (byName != null && byName!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Отметил(а) $byName в чек-ине',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
