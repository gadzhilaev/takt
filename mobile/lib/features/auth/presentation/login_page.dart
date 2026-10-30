import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../cubit/auth_cubit.dart';
import '../../../shared/widgets/app_icon.dart';
import 'oauth_buttons.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _localError;
  bool _obscure = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final msg = GoRouterState.of(context).uri.queryParameters['message']?.trim();
      if (msg != null && msg.isNotEmpty) {
        setState(() => _localError = null);
        // Информационное сообщение с сервера после сброса пароля.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _localError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await context.read<AuthCubit>().login(_email.text.trim(), _password.text);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hint = Theme.of(context).hintColor;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        appBar: null,
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
          child: SafeArea(
            child: BlocConsumer<AuthCubit, AuthState>(
              listener: (context, state) {
                if (state is AuthAuthenticated) context.go('/enable-notifications');
                if (state is AuthFailure) setState(() => _localError = state.message);
              },
              builder: (context, state) {
                final loading = _busy;
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(
                                  child: SvgPicture.asset(
                                    dark ? 'assets/brand/takt-logo-on-dark.svg' : 'assets/brand/takt-logo.svg',
                                    height: 40,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Material(
                                  color: dark ? const Color(0xFF1A1E24) : Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: dark
                                          ? Colors.white.withValues(alpha: 0.06)
                                          : TaktColors.graphite.withValues(alpha: 0.08),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                                    child: Form(
                                      key: _formKey,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                            'Вход',
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: -0.3,
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Войдите, чтобы открыть доску команды',
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  color: hint,
                                                  height: 1.35,
                                                ),
                                          ),
                                          const SizedBox(height: 24),
                                          TextFormField(
                                            controller: _email,
                                            keyboardType: TextInputType.emailAddress,
                                            textInputAction: TextInputAction.next,
                                            autofillHints: const [AutofillHints.email],
                                            decoration: InputDecoration(
                                              labelText: 'Email',
                                              prefixIcon: const Padding(
                                                padding: EdgeInsets.all(12),
                                                child: AppIcon(AppIcons.mail, size: 20),
                                              ),
                                            ),
                                            validator: (v) {
                                              final value = (v ?? '').trim();
                                              if (value.isEmpty || !value.contains('@')) return '';
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 14),
                                          TextFormField(
                                            controller: _password,
                                            obscureText: _obscure,
                                            textInputAction: TextInputAction.done,
                                            onFieldSubmitted: (_) => loading ? null : _submit(),
                                            autofillHints: const [AutofillHints.password],
                                            decoration: InputDecoration(
                                              labelText: 'Пароль',
                                              prefixIcon: const Padding(
                                                padding: EdgeInsets.all(12),
                                                child: AppIcon(AppIcons.lock, size: 20),
                                              ),
                                              suffixIcon: IconButton(
                                                tooltip: _obscure ? 'Показать пароль' : 'Скрыть пароль',
                                                onPressed: () => setState(() => _obscure = !_obscure),
                                                icon: AppIcon(
                                                  _obscure ? AppIcons.eye : AppIcons.eyeOff,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                            validator: (v) =>
                                                (v == null || v.isEmpty) ? '' : null,
                                          ),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton(
                                              onPressed: () => context.push('/forgot-password'),
                                              style: TextButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              child: Text(
                                                'Забыли пароль?',
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.primary,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (_localError != null) ...[
                                            const SizedBox(height: 14),
                                            DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error
                                                    .withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                child: Text(
                                                  _localError!,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: Theme.of(context).colorScheme.error,
                                                    height: 1.35,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 8),
                                          FilledButton(
                                            onPressed: loading ? null : _submit,
                                            child: loading
                                                ? const SizedBox(
                                                    height: 22,
                                                    width: 22,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                : const Text('Войти'),
                                          ),
                                          const OAuthButtons(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                TextButton(
                                  onPressed: () => context.push('/register'),
                                  child: Text.rich(
                                    TextSpan(
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: hint),
                                      children: [
                                        const TextSpan(text: 'Нет аккаунта? '),
                                        TextSpan(
                                          text: 'Создать',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
