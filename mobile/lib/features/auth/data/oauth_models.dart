import 'package:equatable/equatable.dart';

import '../../../shared/models/models.dart';

/// Идентификаторы провайдеров, как их отдаёт backend.
abstract final class OAuthProviderId {
  static const apple = 'apple';
  static const vk = 'vk';
  static const yandex = 'yandex';

  static const known = [apple, vk, yandex];

  /// Подпись на кнопках входа (официальные названия).
  static String loginLabel(String id) {
    switch (id) {
      case apple:
        return 'Войти с Apple';
      case vk:
        return 'VK ID';
      case yandex:
        return 'Яндекс ID';
      default:
        return id;
    }
  }

  /// Название сервиса в списке привязанных аккаунтов.
  static String accountLabel(String id) {
    switch (id) {
      case apple:
        return 'Apple';
      case vk:
        return 'VK ID';
      case yandex:
        return 'Яндекс ID';
      default:
        return id;
    }
  }
}

class OAuthProviderInfo extends Equatable {
  const OAuthProviderInfo({
    required this.id,
    required this.label,
    required this.enabled,
    this.reason,
  });

  final String id;
  final String label;
  final bool enabled;
  final String? reason;

  factory OAuthProviderInfo.fromJson(Map<String, dynamic> json) => OAuthProviderInfo(
        id: (json['id'] as String? ?? '').toLowerCase(),
        label: json['label'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? false,
        reason: json['reason'] as String?,
      );

  @override
  List<Object?> get props => [id, label, enabled, reason];
}

class LinkedIdentity extends Equatable {
  const LinkedIdentity({
    required this.id,
    required this.provider,
    required this.linkedAt,
    this.emailHint,
  });

  final String id;
  final String provider;
  final String? emailHint;
  final DateTime? linkedAt;

  factory LinkedIdentity.fromJson(Map<String, dynamic> json) => LinkedIdentity(
        id: '${json['id']}',
        provider: (json['provider'] as String? ?? '').toLowerCase(),
        emailHint: json['email_hint'] as String?,
        linkedAt: DateTime.tryParse(json['linked_at'] as String? ?? '')?.toLocal(),
      );

  @override
  List<Object?> get props => [id, provider, emailHint, linkedAt];
}

/// Ответ `start` / `link/start`.
class OAuthStart extends Equatable {
  const OAuthStart({
    required this.authorizationUrl,
    required this.state,
    this.codeVerifier,
  });

  final String authorizationUrl;
  final String state;

  /// Если backend генерирует PKCE и отдаёт verifier клиенту — вернём его в exchange.
  final String? codeVerifier;

  factory OAuthStart.fromJson(Map<String, dynamic> json) {
    final url = json['authorization_url'] as String?;
    final state = json['state'] as String?;
    if (url == null || url.isEmpty || state == null || state.isEmpty) {
      throw const FormatException('invalid_oauth_start');
    }
    return OAuthStart(
      authorizationUrl: url,
      state: state,
      codeVerifier: json['code_verifier'] as String?,
    );
  }

  @override
  List<Object?> get props => [authorizationUrl, state, codeVerifier];
}

enum OAuthIntent { login, link }

enum OAuthStatus { success, cancelled, error }

class OAuthOutcome extends Equatable {
  const OAuthOutcome({
    required this.intent,
    required this.provider,
    required this.status,
    this.message,
    this.user,
  });

  final OAuthIntent intent;
  final String provider;
  final OAuthStatus status;
  final String? message;

  /// Только для [OAuthIntent.login] при успехе (после `exchange`).
  final UserProfile? user;

  @override
  List<Object?> get props => [intent, provider, status, message, user];
}

/// Ошибка OAuth с текстом на русском для пользователя.
class OAuthException implements Exception {
  const OAuthException(this.message, {this.cancelled = false});

  final String message;
  final bool cancelled;

  @override
  String toString() => message;
}
