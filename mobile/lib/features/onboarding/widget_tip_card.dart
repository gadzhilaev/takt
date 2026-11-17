import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme.dart';
import '../../shared/widgets/app_icon.dart';
import 'onboarding_controller.dart';

/// После первого ответа на чек-ин — ненавязчивая подсказка про виджет.
class WidgetTipCard extends StatelessWidget {
  const WidgetTipCard({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final onboarding = context.read<OnboardingController>();
    return AnimatedBuilder(
      animation: Listenable.merge([
        onboarding.checkinAnsweredListenable,
        onboarding.widgetTipDismissedListenable,
      ]),
      builder: (context, _) {
        if (!onboarding.shouldShowWidgetTip) return const SizedBox.shrink();
        final dark = Theme.of(context).brightness == Brightness.dark;
        final muted = dark ? TaktColors.mutedDark : TaktColors.muted;

        return Padding(
          padding: padding,
          child: Material(
            color: dark ? TaktColors.accentSoftDark : TaktColors.accentSoft,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: (dark ? TaktColors.accentDark : TaktColors.accent).withValues(alpha: 0.28),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: AppIcon(
                      AppIcons.circleCheck,
                      size: 18,
                      color: dark ? TaktColors.accentDark : TaktColors.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Отмечайте задачи с экрана iPhone',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Добавьте виджет «Чек-ин»: зажмите домашний экран → «Изменить» → «Добавить виджет» → Takt.',
                          style: TextStyle(fontSize: 13, height: 1.35, color: muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Закрыть',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onboarding.dismissWidgetTip(),
                    icon: Icon(Icons.close, size: 18, color: muted),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
