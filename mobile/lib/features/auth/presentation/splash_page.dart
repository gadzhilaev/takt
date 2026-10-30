import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/push/fcm_bootstrap.dart';
import '../../../core/theme.dart';
import '../../board/cubit/board_cubit.dart';
import '../cubit/auth_cubit.dart';
import '../data/oauth_repository.dart';

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
  bool _warmDone = false;
  bool _warmStarted = false;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_warmStarted) return;
    _warmStarted = true;
    unawaited(_warm());
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  /// Пока виден splash — сессия, способы входа и (если залогинен) проекты.
  Future<void> _warm() async {
    final auth = context.read<AuthCubit>();
    final oauth = context.read<OAuthRepository>();
    final board = context.read<BoardCubit>();

    await Future.wait<void>([
      oauth.prefetchProviders(),
      _waitAuth(auth),
    ]);

    final state = auth.state;
    if (state is AuthAuthenticated) {
      board.setCurrentUserId(state.user.id);
      if (board.state.projects.isEmpty) {
        try {
          await board.bootstrap();
        } catch (e) {
          debugPrint('── splash board warm ✕ $e');
        }
      }
    }

    if (!mounted) return;
    setState(() => _warmDone = true);
    _leaveIfReady(auth.state);
  }

  Future<void> _waitAuth(AuthCubit auth) async {
    final current = auth.state;
    if (current is AuthAuthenticated || current is AuthGuest || current is AuthFailure) {
      return;
    }
    await auth.stream.firstWhere(
      (s) => s is AuthAuthenticated || s is AuthGuest || s is AuthFailure,
    );
  }

  void _leaveIfReady(AuthState state) {
    if (!_minElapsed || !_warmDone || !mounted) return;
    // Не вызывать go() прямо из build/listener — иначе Router markNeedsBuild mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (state is AuthAuthenticated) {
        final seen = context.read<FcmBootstrap>().promptSeen;
        context.go(seen ? '/projects' : '/enable-notifications');
      } else if (state is AuthGuest || state is AuthFailure) {
        context.go('/login');
      }
    });
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
