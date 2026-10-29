import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/api_client.dart';
import '../data/oauth_repository.dart';

/// Shows enabled OAuth providers from backend policy (env + admin toggles).
class OAuthButtons extends StatefulWidget {
  const OAuthButtons({super.key, this.link = false, this.register = false});

  final bool link;
  final bool register;

  @override
  State<OAuthButtons> createState() => _OAuthButtonsState();
}

class _OAuthButtonsState extends State<OAuthButtons> {
  OAuthRepository? _repo;
  Map<String, dynamic>? _providers;
  String? _error;
  String? _busy;
  bool _loaded = false;

  static const _icons = <String, String>{
    'vk': 'assets/brand/oauth/oauth-vk.svg',
    'yandex': 'assets/brand/oauth/oauth-yandex.svg',
    'apple': 'assets/brand/oauth/oauth-apple.svg',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repo ??= OAuthRepository(context.read<ApiClient>());
    if (!_loaded) {
      _loaded = true;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final data = await _repo!.providers();
      if (!mounted) return;
      setState(() => _providers = data['providers'] as Map<String, dynamic>?);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось загрузить способы входа');
    }
  }

  Future<void> _start(String id, String label) async {
    setState(() {
      _busy = id;
      _error = null;
    });
    try {
      await _repo!.startWebOAuth(id, link: widget.link);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось открыть $label');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final map = _providers;
    if (map == null && _error == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    final enabled = <MapEntry<String, dynamic>>[];
    if (map != null) {
      for (final e in map.entries) {
        final v = e.value;
        if (v is Map && v['enabled'] == true) enabled.add(e);
      }
    }
    if (enabled.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          'Apple / VK ID / Яндекс ID появятся после настройки на сервере.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
        ),
      );
    }
    final prefix = widget.register ? 'Зарегистрироваться через' : 'Продолжить с';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text('или', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 10),
        for (final e in enabled)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onPressed: _busy != null
                  ? null
                  : () => _start(e.key, (e.value as Map)['label'] as String? ?? e.key),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_icons.containsKey(e.key)) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: SvgPicture.asset(_icons[e.key]!, width: 22, height: 22),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      _busy == e.key
                          ? 'Открываем…'
                          : '$prefix ${(e.value as Map)['label']}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_error != null)
          Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ],
    );
  }
}
