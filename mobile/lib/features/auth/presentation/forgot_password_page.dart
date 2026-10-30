import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../shared/widgets/app_icon.dart';
import '../cubit/auth_cubit.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  String? _error;
  String? _info;
  bool _awaitingCode = false;
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() {
      _error = null;
      _info = null;
    });
    if (!(_emailFormKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final cubit = context.read<AuthCubit>();
    try {
      await cubit.auth.sendForgotPasswordCode(email: _email.text.trim());
      if (!mounted) return;
      setState(() {
        _awaitingCode = true;
        _busy = false;
        _info = 'Если аккаунт существует, код отправлен на почту';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = cubit.api.messageFromError(e);
        _busy = false;
      });
    }
  }

  Future<void> _confirmReset() async {
    setState(() {
      _error = null;
      _info = null;
    });
    if (!(_resetFormKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final cubit = context.read<AuthCubit>();
    try {
      await cubit.auth.confirmForgotPassword(
        email: _email.text.trim(),
        code: _code.text.trim(),
        newPassword: _password.text,
        newPasswordConfirm: _confirm.text,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.go('/login');
      messenger.showSnackBar(
        const SnackBar(content: Text('Пароль обновлён. Войдите с новым паролем.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = cubit.api.messageFromError(e);
        _busy = false;
      });
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
            child: LayoutBuilder(
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
                                child: !_awaitingCode
                                    ? Form(
                                        key: _emailFormKey,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Text(
                                              'Сброс пароля',
                                              textAlign: TextAlign.center,
                                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    letterSpacing: -0.3,
                                                  ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Укажите email — пришлём код для сброса пароля',
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
                                              textInputAction: TextInputAction.done,
                                              onFieldSubmitted: (_) => _busy ? null : _sendCode(),
                                              autofillHints: const [AutofillHints.email],
                                              decoration: const InputDecoration(
                                                labelText: 'Email',
                                                prefixIcon: Padding(
                                                  padding: EdgeInsets.all(12),
                                                  child: AppIcon(AppIcons.mail, size: 20),
                                                ),
                                              ),
                                              validator: (v) {
                                                final value = (v ?? '').trim();
                                                if (value.isEmpty) return 'Введите email';
                                                if (!value.contains('@')) return 'Некорректный email';
                                                return null;
                                              },
                                            ),
                                            if (_error != null) ...[
                                              const SizedBox(height: 14),
                                              _ErrorBox(text: _error!),
                                            ],
                                            const SizedBox(height: 22),
                                            FilledButton(
                                              onPressed: _busy ? null : _sendCode,
                                              child: _busy
                                                  ? const SizedBox(
                                                      height: 22,
                                                      width: 22,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white,
                                                      ),
                                                    )
                                                  : const Text('Отправить код'),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Form(
                                        key: _resetFormKey,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Text(
                                              'Новый пароль',
                                              textAlign: TextAlign.center,
                                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    letterSpacing: -0.3,
                                                  ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Введите код из письма и задайте новый пароль',
                                              textAlign: TextAlign.center,
                                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                    color: hint,
                                                    height: 1.35,
                                                  ),
                                            ),
                                            if (_info != null) ...[
                                              const SizedBox(height: 12),
                                              Text(
                                                _info!,
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                      color: Theme.of(context).colorScheme.primary,
                                                    ),
                                              ),
                                            ],
                                            const SizedBox(height: 20),
                                            TextFormField(
                                              controller: _code,
                                              keyboardType: TextInputType.number,
                                              textInputAction: TextInputAction.next,
                                              autofillHints: const [AutofillHints.oneTimeCode],
                                              decoration: const InputDecoration(labelText: 'Код из письма'),
                                              validator: (v) =>
                                                  (v == null || v.trim().length < 4) ? 'Введите код' : null,
                                            ),
                                            const SizedBox(height: 14),
                                            TextFormField(
                                              controller: _password,
                                              obscureText: _obscure,
                                              textInputAction: TextInputAction.next,
                                              autofillHints: const [AutofillHints.newPassword],
                                              decoration: InputDecoration(
                                                labelText: 'Новый пароль',
                                                prefixIcon: const Padding(
                                                  padding: EdgeInsets.all(12),
                                                  child: AppIcon(AppIcons.lock, size: 20),
                                                ),
                                                suffixIcon: IconButton(
                                                  onPressed: () => setState(() => _obscure = !_obscure),
                                                  icon: AppIcon(
                                                    _obscure ? AppIcons.eye : AppIcons.eyeOff,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                              validator: (v) {
                                                if (v == null || v.length < 8) {
                                                  return 'Минимум 8 символов';
                                                }
                                                return null;
                                              },
                                            ),
                                            const SizedBox(height: 14),
                                            TextFormField(
                                              controller: _confirm,
                                              obscureText: _obscure,
                                              textInputAction: TextInputAction.done,
                                              onFieldSubmitted: (_) => _busy ? null : _confirmReset(),
                                              decoration: const InputDecoration(
                                                labelText: 'Подтверждение пароля',
                                              ),
                                              validator: (v) {
                                                if (v != _password.text) return 'Пароли не совпадают';
                                                return null;
                                              },
                                            ),
                                            if (_error != null) ...[
                                              const SizedBox(height: 14),
                                              _ErrorBox(text: _error!),
                                            ],
                                            const SizedBox(height: 22),
                                            FilledButton(
                                              onPressed: _busy ? null : _confirmReset,
                                              child: _busy
                                                  ? const SizedBox(
                                                      height: 22,
                                                      width: 22,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white,
                                                      ),
                                                    )
                                                  : const Text('Сбросить пароль'),
                                            ),
                                            TextButton(
                                              onPressed: _busy ? null : _sendCode,
                                              child: const Text('Отправить код ещё раз'),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            TextButton(
                              onPressed: () => context.go('/login'),
                              child: Text(
                                'Назад ко входу',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
