import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api_client.dart';
import '../data/oauth_repository.dart';

/// Shows enabled OAuth providers from backend policy. Does not claim store SDKs are live
/// until credentials exist and a real provider login succeeds.
class OAuthButtons extends StatefulWidget {
  const OAuthButtons({super.key, this.link = false});

  final bool link;

  @override
  State<OAuthButtons> createState() => _OAuthButtonsState();
}

class _OAuthButtonsState extends State<OAuthButtons> {
  OAuthRepository? _repo;
  Map<String, dynamic>? _providers;
  String? _error;
  String? _busy;
  bool _loaded = false;

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
    } catch (e) {
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
    } catch (e) {
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
              onPressed: _busy != null ? null : () => _start(e.key, (e.value as Map)['label'] as String? ?? e.key),
              child: Text(_busy == e.key ? 'Открываем…' : 'Продолжить с ${(e.value as Map)['label']}'),
            ),
          ),
        if (_error != null)
          Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ],
    );
  }
}
