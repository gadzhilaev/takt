import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../shared/widgets/takt_app_bar.dart';
import '../cubit/auth_cubit.dart';
import '../../../shared/widgets/app_icon.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    context.read<AuthCubit>().register(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          passwordConfirm: _confirm.text,
        );
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
        appBar: TaktAppBar(
          title: 'Регистрация',
          onBack: () {
            FocusScope.of(context).unfocus();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login');
            }
          },
        ),
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
          child: BlocConsumer<AuthCubit, AuthState>(
              listener: (context, state) {
                if (state is AuthAuthenticated) context.go('/enable-notifications');
                if (state is AuthFailure) setState(() => _error = state.message);
              },
              builder: (context, state) {
                final loading = state is AuthLoading;
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight - 44),
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
                                const SizedBox(height: 22),
                                Material(
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
                                    padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                                    child: Form(
                                      key: _formKey,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                            'Регистрация',
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: -0.3,
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Создайте аккаунт и свой первый проект',
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  color: hint,
                                                  height: 1.35,
                                                ),
                                          ),
                                          const SizedBox(height: 24),
                                          TextFormField(
                                            controller: _name,
                                            textInputAction: TextInputAction.next,
                                            decoration: const InputDecoration(
                                              labelText: 'Имя',
                                              prefixIcon: Padding(
                                                padding: EdgeInsets.all(12),
                                                child: AppIcon(AppIcons.profile, size: 20),
                                              ),
                                            ),
                                            validator: (v) =>
                                                (v == null || v.trim().isEmpty) ? 'Укажите имя' : null,
                                          ),
                                          const SizedBox(height: 12),
                                          TextFormField(
                                            controller: _email,
                                            keyboardType: TextInputType.emailAddress,
                                            textInputAction: TextInputAction.next,
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
                                          const SizedBox(height: 12),
                                          TextFormField(
                                            controller: _password,
                                            obscureText: _obscure,
                                            textInputAction: TextInputAction.next,
                                            decoration: InputDecoration(
                                              labelText: 'Пароль',
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
                                              if (v == null || v.isEmpty) return 'Введите пароль';
                                              if (v.length < 8) return 'Минимум 8 символов';
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 12),
                                          TextFormField(
                                            controller: _confirm,
                                            obscureText: _obscure,
                                            textInputAction: TextInputAction.done,
                                            onFieldSubmitted: (_) => loading ? null : _submit(),
                                            decoration: const InputDecoration(
                                              labelText: 'Повтор пароля',
                                              prefixIcon: Padding(
                                                padding: EdgeInsets.all(12),
                                                child: AppIcon(AppIcons.lock, size: 20),
                                              ),
                                            ),
                                            validator: (v) {
                                              if (v == null || v.isEmpty) return 'Повторите пароль';
                                              if (v != _password.text) return 'Пароли не совпадают';
                                              return null;
                                            },
                                          ),
                                          if (_error != null) ...[
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
                                                  _error!,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: Theme.of(context).colorScheme.error,
                                                    height: 1.35,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 22),
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
                                                : const Text('Зарегистрироваться'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                TextButton(
                                  onPressed: () => context.go('/login'),
                                  child: Text.rich(
                                    TextSpan(
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: hint),
                                      children: [
                                        const TextSpan(text: 'Уже есть аккаунт? '),
                                        TextSpan(
                                          text: 'Войти',
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
    );
  }
}
