import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../cubit/auth_cubit.dart';

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
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) context.go('/board');
          if (state is AuthFailure) setState(() => _error = state.message);
        },
        builder: (context, state) {
          final loading = state is AuthLoading;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Имя')),
              const SizedBox(height: 12),
              TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 12),
              TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Пароль')),
              const SizedBox(height: 12),
              TextField(controller: _confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Повтор пароля')),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: loading
                    ? null
                    : () {
                        setState(() => _error = null);
                        context.read<AuthCubit>().register(
                              name: _name.text,
                              email: _email.text,
                              password: _password.text,
                              passwordConfirm: _confirm.text,
                            );
                      },
                child: loading ? const CircularProgressIndicator() : const Text('Зарегистрироваться'),
              ),
            ],
          );
        },
      ),
    );
  }
}
