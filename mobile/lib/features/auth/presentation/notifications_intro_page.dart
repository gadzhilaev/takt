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

  Future<void> _allow() async {
    if (_busy) return;
    setState(() => _busy = true);
    final fcm = context.read<FcmBootstrap>();
    try {
      await fcm.enablePush();
      await fcm.registerForUser();
    } catch (_) {
      await fcm.markPromptNever();
    }
    if (!mounted) return;
    context.go('/projects');
  }

  Future<void> _notNow() async {
    if (_busy) return;
    setState(() => _busy = true);
    // Don't ask on every launch — can enable later in profile.
    await context.read<FcmBootstrap>().markPromptNever();
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
            constraints: const BoxConstraints(maxWidth: 400),
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
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: TaktColors.accent.withValues(alpha: dark ? 0.22 : 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: AppIcon(
                            AppIcons.notifications,
                            color: dark ? const Color(0xFF6A9AAB) : TaktColors.accent,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Будьте в курсе важных событий',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                              fontSize: 18,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Узнавайте о новых задачах, комментариях и изменениях в проектах.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: hint,
                              height: 1.4,
                            ),
                      ),
                      const SizedBox(height: 18),
                      _Benefit(icon: AppIcons.assignment, text: 'Назначения и новые задачи', dark: dark),
                      const SizedBox(height: 10),
                      _Benefit(icon: AppIcons.forum, text: 'Упоминания и комментарии', dark: dark),
                      const SizedBox(height: 10),
                      _Benefit(icon: AppIcons.status, text: 'Важные изменения задач', dark: dark),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _busy ? null : _allow,
                        child: _busy
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Разрешить уведомления'),
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: _busy ? null : _notNow,
                        child: const Text('Не сейчас'),
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
      children: [
        AppIcon(icon, size: 20, color: dark ? const Color(0xFF6A9AAB) : TaktColors.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.3),
          ),
        ),
      ],
    );
  }
}
