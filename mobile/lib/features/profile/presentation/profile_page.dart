import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_client.dart';
import '../../../core/config.dart';
import '../../../core/push/fcm_bootstrap.dart';
import '../../../core/takt_links.dart';
import '../../../core/theme.dart';
import '../../../core/theme_scope.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/takt_app_bar.dart';
import '../../../shared/widgets/takt_sheet.dart';
import '../../../shared/widgets/takt_ui.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../board/cubit/board_cubit.dart';
import '../../projects/data/projects_repository.dart';
import '../data/profile_repository.dart';
import 'sign_in_methods_section.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.embeddedInShell = false});

  final bool embeddedInShell;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _message;
  String? _avatarUrl;
  String _name = '';
  String _email = '';
  PushPermission? _pushStatus;
  bool _pushBusy = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthCubit>().state;
    if (auth is AuthAuthenticated) {
      _name = auth.user.name;
      _email = auth.user.email;
      _avatarUrl = auth.user.avatarUrl;
    }
    _refreshPushStatus();
  }

  Future<void> _refreshPushStatus() async {
    final fcm = context.read<FcmBootstrap>();
    final status = await fcm.currentPermission();
    if (mounted) setState(() => _pushStatus = status);
  }

  String get _pushLabel {
    switch (_pushStatus) {
      case PushPermission.authorized:
      case PushPermission.provisional:
        return 'Разрешены';
      case PushPermission.denied:
        return 'Отклонены системой';
      case PushPermission.notDetermined:
        return 'Ещё не запрошены';
      case PushPermission.unavailable:
      case null:
        return 'Недоступны на этом устройстве';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final themeCtrl = ThemeScope.of(context);
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    final border = dark ? TaktColors.borderDark : TaktColors.border;
    final surface = dark ? TaktColors.surfaceDark : TaktColors.surface;

    return ListenableBuilder(
      listenable: themeCtrl,
      builder: (context, _) {
        return Scaffold(
          appBar: TaktAppBar(title: 'Профиль'),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 28),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    TaktUserAvatar(
                      name: _name.isEmpty ? '?' : _name,
                      avatarUrl: _avatarUrl,
                      size: 64,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _name.isEmpty ? 'Пользователь' : _name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: dark ? TaktColors.foregroundDark : TaktColors.graphite,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _email,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                    const SizedBox(height: 12),
                    TaktButton(
                      label: 'Изменить профиль',
                      variant: TaktButtonVariant.secondary,
                      onPressed: () => _editProfile(context),
                    ),
                  ],
                ),
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    _message!,
                    style: TextStyle(
                      fontSize: 13,
                      color: dark ? TaktColors.accentDark : TaktColors.accent,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Divider(height: 1, color: border),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SignInMethodsSection(
                  onMessage: (m) => setState(() => _message = m),
                ),
              ),
              TaktSection(
                title: 'Тема',
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _SettingsGroup(
                  surface: surface,
                  border: border,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      child: Row(
                        children: [
                          for (final entry in const [
                            (ThemeMode.system, 'Авто'),
                            (ThemeMode.light, 'Светлая'),
                            (ThemeMode.dark, 'Тёмная'),
                          ]) ...[
                            Expanded(
                              child: _ThemeChip(
                                label: entry.$2,
                                selected: themeCtrl.mode == entry.$1,
                                onTap: () => themeCtrl.setMode(entry.$1),
                              ),
                            ),
                            if (entry.$1 != ThemeMode.dark) const SizedBox(width: 6),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              TaktSection(
                title: 'Уведомления',
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _SettingsGroup(
                  surface: surface,
                  border: border,
                  children: [
                    TaktListTile(
                      leading: AppIcon(AppIcons.notifications, size: 20, color: muted),
                      title: 'Push-уведомления',
                      subtitle: _pushLabel,
                      trailing: _pushBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : AppIcon(AppIcons.settings, size: 20, color: muted),
                      onTap: _pushBusy ? null : () => _handlePushTap(context),
                    ),
                    TaktListTile(
                      leading: AppIcon(AppIcons.inbox, size: 20, color: muted),
                      title: 'Центр уведомлений',
                      trailing: AppIcon(AppIcons.chevronRight, size: 20, color: muted),
                      onTap: () => context.push('/notifications'),
                    ),
                  ],
                ),
              ),
              Builder(
                builder: (context) {
                  final project = context.watch<BoardCubit>().state.project;
                  if (project == null) return const SizedBox.shrink();
                  return TaktSection(
                    title: 'Проекты',
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _SettingsGroup(
                      surface: surface,
                      border: border,
                      children: [
                        TaktListTile(
                          leading: AppIcon(AppIcons.invite, size: 20, color: muted),
                          title: 'Пригласить участника',
                          subtitle: 'В проект «${project.name}»',
                          trailing: AppIcon(AppIcons.chevronRight, size: 20, color: muted),
                          onTap: () => _inviteDialog(context, projectId: project.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
              TaktSection(
                title: 'О приложении',
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _SettingsGroup(
                  surface: surface,
                  border: border,
                  children: [
                    TaktListTile(
                      leading: AppIcon(AppIcons.message, size: 20, color: muted),
                      title: 'Поддержка',
                      subtitle: 'Написать в поддержку',
                      trailing: AppIcon(AppIcons.chevronRight, size: 20, color: muted),
                      onTap: () => _openSupport(context),
                    ),
                    TaktListTile(
                      leading: AppIcon(AppIcons.lock, size: 20, color: muted),
                      title: 'Конфиденциальность',
                      subtitle: 'Политика обработки данных',
                      trailing: AppIcon(AppIcons.chevronRight, size: 20, color: muted),
                      onTap: () => _openPrivacy(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(height: 1, color: border),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TaktButton(
                    label: 'Выйти',
                    variant: TaktButtonVariant.ghost,
                    danger: true,
                    icon: AppIcons.logout,
                    onPressed: () async {
                      final ok = await showTaktSheet(
                        context: context,
                        title: 'Выйти из аккаунта?',
                        confirmLabel: 'Выйти',
                        body: Text(
                          'Виджеты очистят данные текущего пользователя.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: dark ? TaktColors.mutedDark : TaktColors.muted,
                          ),
                        ),
                      );
                      if (ok != true || !context.mounted) return;
                      await context.read<AuthCubit>().logout();
                      if (context.mounted) context.go('/login');
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openSupport(BuildContext context) async {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    await showTaktInfoSheet(
      context: context,
      title: 'Поддержка',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Напишите нам, если что-то не работает или нужна помощь по Takt.',
            style: TextStyle(fontSize: 14, height: 1.45, color: muted),
          ),
          const SizedBox(height: 14),
          Text(
            TaktLinks.supportEmail,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: dark ? TaktColors.foregroundDark : TaktColors.graphite,
            ),
          ),
          const SizedBox(height: 14),
          TaktButton(
            label: 'Написать письмо',
            expand: true,
            onPressed: () async {
              final uri = Uri.parse(TaktLinks.supportMailto);
              try {
                await launchUrl(uri);
              } catch (_) {
                await Clipboard.setData(const ClipboardData(text: TaktLinks.supportEmail));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Email скопирован')),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 8),
          TaktButton(
            label: 'Скопировать email',
            variant: TaktButtonVariant.secondary,
            expand: true,
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: TaktLinks.supportEmail));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Email скопирован')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openPrivacy(BuildContext context) async {
    final uri = Uri.parse(TaktLinks.privacyUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      setState(() => _message = 'Не удалось открыть ${TaktLinks.privacyUrl}');
    }
  }

  Future<void> _handlePushTap(BuildContext context) async {
    final fcm = context.read<FcmBootstrap>();
    setState(() => _pushBusy = true);
    try {
      if (_pushStatus == PushPermission.notDetermined) {
        await fcm.enablePush();
        await _refreshPushStatus();
        return;
      }
      await fcm.openSystemSettings();
      await _refreshPushStatus();
    } finally {
      if (mounted) setState(() => _pushBusy = false);
    }
  }

  Future<void> _editProfile(BuildContext context) async {
    final name = TextEditingController(text: _name);
    final email = TextEditingController(text: _email);
    final ok = await showTaktSheet(
      context: context,
      title: 'Личные данные',
      confirmLabel: 'Сохранить',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TaktTextField(controller: name, label: 'Имя'),
          const SizedBox(height: 10),
          TaktTextField(controller: email, label: 'Email', keyboardType: TextInputType.emailAddress),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final profileRepo = context.read<ProfileRepository>();
    final authCubit = context.read<AuthCubit>();
    final api = context.read<ApiClient>();
    try {
      final user = await profileRepo.update(name: name.text, email: email.text);
      if (!mounted) return;
      authCubit.setUser(user);
      setState(() {
        _name = user.name;
        _email = user.email;
        _avatarUrl = user.avatarUrl;
        _message = 'Сохранено';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = api.messageFromError(e));
    }
  }

  Future<void> _inviteDialog(BuildContext context, {required String projectId}) async {
    final email = TextEditingController();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final choice = await showTaktDialog<String>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Material(
            color: dark ? TaktColors.surfaceDark : TaktColors.surface,
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: dark ? 0.45 : 0.18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(TaktRadii.lg),
              side: BorderSide(color: dark ? TaktColors.borderDark : TaktColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Приглашение',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.25,
                      color: dark ? TaktColors.foregroundDark : TaktColors.graphite,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TaktTextField(
                    controller: email,
                    label: 'Email сотрудника',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TaktButton(
                    label: 'Пригласить по email',
                    expand: true,
                    onPressed: () => Navigator.pop(ctx, 'email'),
                  ),
                  const SizedBox(height: 8),
                  TaktButton(
                    label: 'Скопировать ссылку',
                    variant: TaktButtonVariant.secondary,
                    expand: true,
                    onPressed: () => Navigator.pop(ctx, 'link'),
                  ),
                  const SizedBox(height: 8),
                  TaktButton(
                    label: 'Отмена',
                    variant: TaktButtonVariant.ghost,
                    expand: true,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (choice == null || !context.mounted) return;
    final projectsRepo = context.read<ProjectsRepository>();
    final api = context.read<ApiClient>();
    try {
      if (choice == 'link') {
        final token = await projectsRepo.createOrGetInviteLink(projectId);
        if (!mounted) return;
        if (token == null || token.isEmpty) {
          setState(() => _message = 'Не удалось создать ссылку');
          return;
        }
        final url = _inviteWebUrl(token);
        await Clipboard.setData(ClipboardData(text: url));
        if (!mounted) return;
        setState(() => _message = 'Ссылка скопирована');
        return;
      }
      final trimmed = email.text.trim();
      if (trimmed.isEmpty) {
        setState(() => _message = 'Укажите email');
        return;
      }
      final res = await projectsRepo.inviteMember(projectId: projectId, email: trimmed);
      if (!mounted) return;
      final invite = res['invite'];
      final token = invite is Map<String, dynamic> ? invite['token'] as String? : null;
      if (token != null && token.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: _inviteWebUrl(token)));
        if (!mounted) return;
        setState(() => _message = 'Приглашение создано, ссылка скопирована');
      } else {
        setState(() => _message = 'Приглашение отправлено');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = api.messageFromError(e));
    }
  }
}

String _inviteWebUrl(String token) {
  final api = AppConfig.apiBase;
  // https://taktapp.ru/api/v1 → https://taktapp.ru
  final origin = api.replaceFirst(RegExp(r'/api(?:/v1)?/?$'), '');
  return '$origin/invite/$token';
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? TaktColors.accentDark : TaktColors.accent;
    return Material(
      color: selected
          ? (dark ? TaktColors.accentSoftDark : TaktColors.accentSoft)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(TaktRadii.md),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? accent : (dark ? TaktColors.mutedDark : TaktColors.muted),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.children,
    required this.surface,
    required this.border,
  });

  final List<Widget> children;
  final Color surface;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TaktRadii.md),
        side: BorderSide(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(height: 1, indent: 52, endIndent: 16, color: border),
          ],
        ],
      ),
    );
  }
}
