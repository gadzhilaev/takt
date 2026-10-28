import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/data/auth_repository.dart';
import '../../projects/data/projects_repository.dart';
import '../data/profile_repository.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  String? _message;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthCubit>().state;
    if (auth is AuthAuthenticated) {
      _name.text = auth.user.name;
      _email.text = auth.user.email;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Имя')),
          const SizedBox(height: 12),
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () async {
              try {
                final user = await context.read<ProfileRepository>().update(
                      name: _name.text,
                      email: _email.text,
                    );
                context.read<AuthCubit>().setUser(user);
                setState(() => _message = 'Сохранено');
              } catch (e) {
                setState(() => _message = context.read<ApiClient>().messageFromError(e));
              }
            },
            child: const Text('Сохранить'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _changePassword(context),
            child: const Text('Сменить пароль'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _inviteDialog(context),
            child: const Text('Пригласить в текущий проект'),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () async {
              await context.read<AuthCubit>().logout();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Смена пароля'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: current, obscureText: true, decoration: const InputDecoration(labelText: 'Текущий')),
            TextField(controller: next, obscureText: true, decoration: const InputDecoration(labelText: 'Новый')),
            TextField(controller: confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Повтор')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сменить')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await context.read<AuthRepository>().changePassword(
            currentPassword: current.text,
            newPassword: next.text,
            newPasswordConfirm: confirm.text,
          );
      setState(() => _message = 'Пароль обновлён');
    } catch (e) {
      setState(() => _message = context.read<ApiClient>().messageFromError(e));
    }
  }

  Future<void> _inviteDialog(BuildContext context) async {
    final email = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Приглашение'),
        content: TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Отправить')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final projects = await context.read<ProjectsRepository>().listProjects();
      if (projects.isEmpty) {
        setState(() => _message = 'Сначала создайте проект');
        return;
      }
      await context.read<ProjectsRepository>().inviteMember(
            projectId: projects.first.id,
            email: email.text,
          );
      setState(() => _message = 'Приглашение отправлено');
    } catch (e) {
      setState(() => _message = context.read<ApiClient>().messageFromError(e));
    }
  }
}
