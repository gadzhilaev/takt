import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/push/fcm_bootstrap.dart';
import '../../core/theme.dart';
import '../../features/auth/cubit/auth_cubit.dart';
import 'onboarding_controller.dart';
import 'onboarding_illustrations.dart';

/// Три экрана позиционирования. Показывается один раз до входа (или после — если
/// пользователь уже авторизован и флаг ещё не выставлен).
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _index = 0;

  static const _pages = [
    _Slide(
      title: 'Отвечайте на чек-ин — задачи обновятся сами',
      body: 'Каждое утро команда за несколько секунд отмечает: сделал, в работе или застрял. Карточки двигаются без отдельного обновления доски.',
      art: OnboardingCheckinArt(),
    ),
    _Slide(
      title: 'Руководитель видит, что сделано и что застряло',
      body: 'Сводка собирает сделанное, просрочки, узкое место по столбцам и участие в ритме — за день, неделю или месяц.',
      art: OnboardingDigestArt(),
    ),
    _Slide(
      title: 'Отмечайте задачи прямо с экрана iPhone',
      body: 'Виджет чек-ина, ответ из уведомления, Live Activity и команды Siri — когда нет времени открывать приложение.',
      art: OnboardingWidgetArt(),
      showWidgetHowTo: true,
    ),
  ];

  Future<void> _finish() async {
    await context.read<OnboardingController>().markSeen();
    if (!mounted) return;
    final auth = context.read<AuthCubit>().state;
    final fcm = context.read<FcmBootstrap>();
    if (auth is AuthAuthenticated) {
      context.go(fcm.shouldShowPrompt ? '/enable-notifications' : '/projects');
    } else {
      context.go('/login');
    }
  }

  void _next() {
    if (_index >= _pages.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  Future<void> _showWidgetHowTo() async {
    final dark = Theme.of(context).brightness == Brightness.dark;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: dark ? TaktColors.surfaceDark : Colors.white,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Как добавить виджет',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                const _HowStep(n: '1', text: 'На домашнем экране зажмите пустое место, пока иконки не задрожат.'),
                const _HowStep(n: '2', text: 'Нажмите «Изменить» → «Добавить виджет» и найдите Takt.'),
                const _HowStep(n: '3', text: 'Выберите виджет «Чек-ин» и нажмите «Добавить виджет».'),
                const SizedBox(height: 8),
                Text(
                  'Кнопка «Сделал» на виджете доступна на iOS 17 и новее.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: dark ? TaktColors.mutedDark : TaktColors.muted,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    final media = MediaQuery.of(context);
    final bottomPad = media.padding.bottom + 16;

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF171C22) : const Color(0xFFF4F7F8),
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: Text('Пропустить', style: TextStyle(color: muted, fontWeight: FontWeight.w500)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final slide = _pages[i];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: media.size.height - media.padding.vertical - 140),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            slide.title,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.3,
                                  height: 1.2,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            slide.body,
                            style: TextStyle(fontSize: 15, height: 1.45, color: muted),
                          ),
                          const SizedBox(height: 22),
                          slide.art,
                          if (slide.showWidgetHowTo) ...[
                            const SizedBox(height: 14),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: _showWidgetHowTo,
                                style: TextButton.styleFrom(
                                  foregroundColor: dark ? TaktColors.accentDark : TaktColors.accent,
                                  padding: EdgeInsets.zero,
                                ),
                                child: const Text('Как добавить виджет'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPad),
              child: Row(
                children: [
                  Row(
                    children: List.generate(_pages.length, (i) {
                      final on = i == _index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 6),
                        width: on ? 18 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: on
                              ? (dark ? TaktColors.accentDark : TaktColors.accent)
                              : muted.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    child: Text(_index == _pages.length - 1 ? 'Начать' : 'Далее'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide({
    required this.title,
    required this.body,
    required this.art,
    this.showWidgetHowTo = false,
  });

  final String title;
  final String body;
  final Widget art;
  final bool showWidgetHowTo;
}

class _HowStep extends StatelessWidget {
  const _HowStep({required this.n, required this.text});

  final String n;
  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(
              n,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: dark ? TaktColors.accentDark : TaktColors.accent,
              ),
            ),
          ),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
