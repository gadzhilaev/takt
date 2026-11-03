import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/takt_sheet.dart';
import '../../../shared/widgets/takt_ui.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/oauth_models.dart';
import '../../auth/data/oauth_repository.dart';

/// Единый блок «Вход и безопасность»: пароль + привязки Apple/VK/Яндекс.
class SignInMethodsSection extends StatefulWidget {
  const SignInMethodsSection({super.key, this.onMessage});

  final ValueChanged<String>? onMessage;

  @override
  State<SignInMethodsSection> createState() => _SignInMethodsSectionState();
}

class _SignInMethodsSectionState extends State<SignInMethodsSection> {
  static const _icons = <String, String>{
    'vk': 'assets/brand/oauth/oauth-vk.svg',
    'yandex': 'assets/brand/oauth/oauth-yandex.svg',
    'apple': 'assets/brand/oauth/oauth-apple.svg',
  };

  List<Map<String, dynamic>> _identities = const [];
  Map<String, dynamic>? _providers;
  bool _hasPassword = false;
  bool _ready = false;
  String? _busy;
  String? _error;

  OAuthRepository get _oauth => context.read<OAuthRepository>();
  ApiClient get _api => context.read<ApiClient>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final cachedProviders = _oauth.cachedProviderMap;
    final cachedIdentities = _oauth.cachedIdentities;
    if (cachedProviders != null) {
      _providers = cachedProviders;
    }
    if (cachedIdentities != null) {
      _identities = cachedIdentities.items;
      _hasPassword = cachedIdentities.hasPassword;
    }
    // Фон: обновить без спиннера, если кэш уже есть.
    _reload(silent: cachedProviders != null && cachedIdentities != null);
  }

  Future<void> _reload({bool silent = false, bool force = false}) async {
    if (!silent && mounted) {
      setState(() => _error = null);
    }
    try {
      final providers = await _oauth.providers(force: force);
      final detailed = await _oauth.identitiesDetailed(force: force);
      if (!mounted) return;
      setState(() {
        _providers = providers['providers'] as Map<String, dynamic>?;
        _identities = detailed.items;
        _hasPassword = detailed.hasPassword;
      });
    } catch (e) {
      if (!mounted) return;
      if (silent) return;
      setState(() => _error = _api.messageFromError(e));
    }
  }

  Map<String, Map<String, dynamic>> get _linkedByProvider {
    final map = <String, Map<String, dynamic>>{};
    for (final i in _identities) {
      final p = (i['provider'] as String? ?? '').toLowerCase();
      if (p.isNotEmpty) map[p] = i;
    }
    return map;
  }

  List<String> get _enabledProviders {
    final map = _providers;
    if (map == null) return const [];
    final out = <String>[];
    for (final id in OAuthProviderId.known) {
      final v = map[id];
      if (v is Map && v['enabled'] == true) out.add(id);
    }
    return out;
  }

  Future<void> _link(String id) async {
    setState(() {
      _busy = id;
      _error = null;
    });
    try {
      await _oauth.signIn(id, link: true);
      if (!mounted) return;
      _oauth.invalidateIdentitiesCache();
      widget.onMessage?.call('${OAuthProviderId.accountLabel(id)} привязан');
      await _reload(force: true, silent: true);
    } catch (e) {
      if (!mounted) return;
      if (isOAuthCancel(e)) {
        setState(() => _busy = null);
        return;
      }
      final raw = e is OAuthException ? e.message.trim() : _api.messageFromError(e);
      if (raw.isEmpty || isTechnicalOAuthMessage(raw)) {
        setState(() => _busy = null);
        return;
      }
      setState(() => _error = raw);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _unlink(Map<String, dynamic> identity) async {
    final id = '${identity['id']}';
    final provider = (identity['provider'] as String? ?? '').toLowerCase();
    final label = OAuthProviderId.accountLabel(provider);
    final ok = await showTaktSheet(
      context: context,
      title: 'Отвязать $label?',
      confirmLabel: 'Отвязать',
      body: Text(
        _hasPassword
            ? 'Вы сможете снова привязать этот способ в любой момент.'
            : 'Без пароля нельзя отвязать последний способ входа.',
        style: TextStyle(
          fontSize: 14,
          height: 1.4,
          color: Theme.of(context).brightness == Brightness.dark
              ? TaktColors.mutedDark
              : TaktColors.muted,
        ),
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = provider);
    try {
      await _oauth.unlink(id);
      if (!mounted) return;
      widget.onMessage?.call('$label отвязан');
      await _reload(force: true, silent: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _api.messageFromError(e));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final ok = await showTaktSheet(
      context: context,
      title: 'Смена пароля',
      confirmLabel: 'Получить код',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TaktTextField(controller: current, label: 'Текущий', obscureText: true),
          const SizedBox(height: 8),
          TaktTextField(controller: next, label: 'Новый', obscureText: true),
          const SizedBox(height: 8),
          TaktTextField(controller: confirm, label: 'Повтор', obscureText: true),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final authRepo = context.read<AuthRepository>();
    try {
      await authRepo.sendChangePasswordCode(
        currentPassword: current.text,
        newPassword: next.text,
        newPasswordConfirm: confirm.text,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _api.messageFromError(e));
      return;
    }
    if (!mounted) return;
    final codeCtrl = TextEditingController();
    final confirmed = await showTaktSheet(
      context: context,
      title: 'Код из письма',
      confirmLabel: 'Подтвердить',
      body: TaktTextField(
        controller: codeCtrl,
        label: 'Код',
        keyboardType: TextInputType.number,
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await authRepo.confirmChangePassword(code: codeCtrl.text);
      if (!mounted) return;
      widget.onMessage?.call('Пароль обновлён. Войдите снова');
      await context.read<AuthCubit>().logout();
      if (!mounted) return;
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _api.messageFromError(e));
    }
  }

  void _setPassword() {
    final auth = context.read<AuthCubit>().state;
    final email = auth is AuthAuthenticated ? auth.user.email : '';
    final qs = email.isEmpty ? '' : '?email=${Uri.encodeQueryComponent(email)}';
    context.push('/forgot-password$qs');
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    final surface = dark ? TaktColors.surfaceDark : TaktColors.surface;
    final border = dark ? TaktColors.borderDark : TaktColors.border;
    final linked = _linkedByProvider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Вход и безопасность',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Пароль и сервисы можно использовать вместе.',
          style: TextStyle(fontSize: 12.5, height: 1.35, color: muted),
        ),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(TaktRadii.lg),
            border: Border.all(color: border),
          ),
          child: Column(
            children: [
              _MethodRow(
                leading: Icon(Icons.lock_outline_rounded, size: 20, color: muted),
                title: 'Email и пароль',
                subtitle: _hasPassword ? 'Задан' : 'Не задан',
                actionLabel: _hasPassword ? 'Сменить' : 'Задать',
                onAction: _hasPassword ? _changePassword : _setPassword,
                busy: false,
              ),
              for (final id in _enabledProviders) ...[
                Divider(height: 1, color: border),
                _MethodRow(
                  leading: _icons.containsKey(id)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SvgPicture.asset(
                            _icons[id]!,
                            width: 22,
                            height: 22,
                            colorFilter: id == 'apple'
                                ? ColorFilter.mode(
                                    dark ? TaktColors.foregroundDark : TaktColors.graphite,
                                    BlendMode.srcIn,
                                  )
                                : null,
                          ),
                        )
                      : Icon(Icons.link_rounded, size: 20, color: muted),
                  title: OAuthProviderId.accountLabel(id),
                  subtitle: linked.containsKey(id)
                      ? (() {
                          final email = linked[id]?['email'] as String? ??
                              linked[id]?['email_hint'] as String?;
                          return (email != null && email.isNotEmpty)
                              ? 'Привязан · $email'
                              : 'Привязан';
                        })()
                      : 'Не привязан',
                  actionLabel: linked.containsKey(id) ? 'Отвязать' : 'Привязать',
                  danger: linked.containsKey(id),
                  busy: _busy == id,
                  onAction: _busy != null
                      ? null
                      : () {
                          final row = linked[id];
                          if (row != null) {
                            _unlink(row);
                          } else {
                            _link(id);
                          }
                        },
                ),
              ],
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(fontSize: 13, color: TaktColors.danger)),
        ],
      ],
    );
  }
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.busy = false,
    this.danger = false,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool busy;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: Row(
        children: [
          SizedBox(width: 28, height: 28, child: Center(child: leading)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.15,
                    color: dark ? TaktColors.foregroundDark : TaktColors.graphite,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: muted)),
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: busy ? null : onAction,
              style: TextButton.styleFrom(
                foregroundColor: danger ? TaktColors.danger : (dark ? TaktColors.accentDark : TaktColors.accent),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(actionLabel!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}
