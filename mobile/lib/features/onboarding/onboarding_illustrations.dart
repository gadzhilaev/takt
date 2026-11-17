import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../shared/widgets/app_icon.dart';
import '../rhythm/data/rhythm_models.dart';
import '../rhythm/presentation/checkin_page.dart' show answerColor;

/// Мини-UI чек-ина: три кнопки как на реальном экране.
class OnboardingCheckinArt extends StatelessWidget {
  const OnboardingCheckinArt({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final card = dark ? const Color(0xFF1A1E24) : Colors.white;
    final border = dark ? TaktColors.borderDark : TaktColors.border;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    final title = dark ? TaktColors.foregroundDark : TaktColors.graphite;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Чек-ин на сегодня',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: title),
            ),
            const SizedBox(height: 4),
            Text(
              'Подготовить аудиторию к дню открытых дверей',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, height: 1.3, color: muted),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final a in CheckinAnswer.values) ...[
                  if (a != CheckinAnswer.values.first) const SizedBox(width: 6),
                  Expanded(child: _DemoAnswer(answer: a, selected: a == CheckinAnswer.done, dark: dark)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoAnswer extends StatelessWidget {
  const _DemoAnswer({required this.answer, required this.selected, required this.dark});

  final CheckinAnswer answer;
  final bool selected;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = answerColor(answer, dark);
    final onColor = dark ? const Color(0xFF152028) : Colors.white;
    final idle = dark ? TaktColors.foregroundDark : TaktColors.graphite;
    final border = dark ? TaktColors.borderStrongDark : TaktColors.borderStrong;
    final icon = switch (answer) {
      CheckinAnswer.done => AppIcons.circleCheck,
      CheckinAnswer.inProgress => AppIcons.status,
      CheckinAnswer.blocked => AppIcons.alert,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? color : Colors.transparent,
        borderRadius: BorderRadius.circular(TaktRadii.md),
        border: Border.all(color: selected ? color : border, width: selected ? 1.5 : 1),
      ),
      child: SizedBox(
        height: 52,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(icon, size: 18, color: selected ? onColor : idle),
            const SizedBox(height: 3),
            Text(
              answer.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? onColor : idle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Мини-версия вкладки «Сводка».
class OnboardingDigestArt extends StatelessWidget {
  const OnboardingDigestArt({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final card = dark ? const Color(0xFF1A1E24) : Colors.white;
    final border = dark ? TaktColors.borderDark : TaktColors.border;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    final title = dark ? TaktColors.foregroundDark : TaktColors.graphite;

    Widget cell(String value, String label, {Color? tone}) {
      return Expanded(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: dark ? TaktColors.surface2Dark : const Color(0xFFF4F7F8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: tone ?? title,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(fontSize: 11, color: muted)),
              ],
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Сводка · неделя', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: title)),
            const SizedBox(height: 10),
            Row(
              children: [
                cell('7', 'сделано', tone: dark ? TaktColors.successDark : TaktColors.success),
                const SizedBox(width: 8),
                cell('2', 'застряло', tone: dark ? const Color(0xFFE0A146) : TaktColors.important),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                cell('1', 'просрочено', tone: dark ? TaktColors.urgent : TaktColors.danger),
                const SizedBox(width: 8),
                cell('86%', 'ответы на чек-ин'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Узкое место: «На проверке»',
              style: TextStyle(fontSize: 12, color: muted, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

/// Иллюстрация виджета чек-ина на «домашнем экране».
class OnboardingWidgetArt extends StatelessWidget {
  const OnboardingWidgetArt({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final wallpaper = dark ? const Color(0xFF0E1216) : const Color(0xFFDDE5EA);
    final card = dark ? const Color(0xFF1C2229) : Colors.white;
    final title = dark ? TaktColors.foregroundDark : TaktColors.graphite;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    final accent = dark ? TaktColors.accentDark : TaktColors.accent;

    return AspectRatio(
      aspectRatio: 1.35,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: wallpaper,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: dark ? 0.35 : 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text('Чек-ин', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: title)),
                          const Spacer(),
                          Text('сегодня', style: TextStyle(fontSize: 11, color: muted)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Обновить расписание экзаменов',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, height: 1.25, color: title),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            child: Text(
                              'Сделал',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
