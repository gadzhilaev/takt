import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/push/fcm_bootstrap.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/app_icon.dart';

class NotificationsIntroPage extends StatefulWidget {
  const NotificationsIntroPage({super.key});

  @override
  State<NotificationsIntroPage> createState() => _NotificationsIntroPageState();
}

class _NotificationsIntroPageState extends State<NotificationsIntroPage> {
  bool _busy = false;

  Future<void> _continue({required bool requestPermission}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final fcm = context.read<FcmBootstrap>();
    try {
      if (requestPermission) {
        await fcm.enablePush();
        await fcm.registerForUser();
      } else {
        // Skip OS prompt; in-app notification center still works.
        await fcm.markPromptSeen();
      }
    } catch (_) {
      await fcm.markPromptSeen();
    }
    if (!mounted) return;
    context.go('/projects');
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hint = Theme.of(context).hintColor;

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF171C22) : const Color(0xFFF4F7F8),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? const [Color(0xFF12151A), Color(0xFF171C22)]
                : const [Color(0xFFE9F1F3), Color(0xFFF4F7F8), Color(0xFFE9EDF2)],
          ),
        ),
        child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Material(
                  color: dark ? const Color(0xFF1A1E24) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: dark
                          ? Colors.white.withValues(alpha: 0.06)
                          : TaktColors.graphite.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: TaktColors.accent.withValues(alpha: dark ? 0.22 : 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: AppIcon(
                              AppIcons.notifications,
                              color: dark ? const Color(0xFF6A9AAB) : TaktColors.accent,
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Не пропускайте важное',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.3,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Takt пришлёт уведомление, когда вам назначат задачу, '
                          'изменят статус или упомянут в комментарии. '
                          'Так команда быстрее реагирует на изменения на доске.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: hint,
                                height: 1.45,
                              ),
                        ),
                        const SizedBox(height: 20),
                        _Benefit(
                          icon: AppIcons.assignment,
                          text: 'Новые назначения и срочные задачи',
                          dark: dark,
                        ),
                        const SizedBox(height: 10),
                        _Benefit(
                          icon: AppIcons.forum,
                          text: 'Упоминания и ответы в обсуждении',
                          dark: dark,
                        ),
                        const SizedBox(height: 10),
                        _Benefit(
                          icon: AppIcons.status,
                          text: 'Смена статуса по вашим задачам',
                          dark: dark,
                        ),
                        const SizedBox(height: 28),
                        FilledButton(
                          onPressed: _busy ? null : () => _continue(requestPermission: true),
                          child: _busy
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Включить уведомления'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _busy ? null : () => _continue(requestPermission: false),
                          child: const Text('Позже'),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Системный запрос появится только после «Включить уведомления». '
                          'Центр уведомлений в приложении работает без разрешения push.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: hint,
                                height: 1.35,
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

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text, required this.dark});

  final String icon;
  final String text;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIcon(icon, size: 20, color: dark ? const Color(0xFF6A9AAB) : TaktColors.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.35),
          ),
        ),
      ],
    );
  }
}
