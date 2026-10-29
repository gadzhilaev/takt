import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/push/fcm_bootstrap.dart';
import '../../../core/theme.dart';
import '../cubit/auth_cubit.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  late final Animation<double> _fade;
  late final Animation<double> _rise;
  bool _minElapsed = false;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(vsync: this, duration: const Duration(milliseconds: 720));
    _fade = CurvedAnimation(parent: _motion, curve: Curves.easeOutCubic);
    _rise = Tween<double>(begin: 10, end: 0).animate(CurvedAnimation(parent: _motion, curve: Curves.easeOutCubic));
    _motion.forward();
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _minElapsed = true);
      _leaveIfReady(context.read<AuthCubit>().state);
    });
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  void _leaveIfReady(AuthState state) {
    if (!_minElapsed || !mounted) return;
    if (state is AuthAuthenticated) {
      final seen = context.read<FcmBootstrap>().promptSeen;
      context.go(seen ? '/projects' : '/enable-notifications');
    } else if (state is AuthGuest || state is AuthFailure) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) => _leaveIfReady(state),
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [Color(0xFF12151A), Color(0xFF1A2830), Color(0xFF152028)]
                  : const [Color(0xFFF4F7F8), Color(0xFFE4EEF1), Color(0xFFD7E6EA)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: AnimatedBuilder(
                animation: _motion,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fade.value,
                    child: Transform.translate(offset: Offset(0, _rise.value), child: child),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      dark ? 'assets/brand/takt-logo-on-dark.svg' : 'assets/brand/takt-logo.svg',
                      height: 44,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Задачи команды',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: dark ? const Color(0xFF9BB0BC) : TaktColors.accent.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: dark ? const Color(0xFF6A9AAB) : TaktColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
