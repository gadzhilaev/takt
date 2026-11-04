import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api_client.dart';
import '../../../core/push/fcm_bootstrap.dart';
import '../../../shared/models/models.dart';
import '../../widget_sync/widget_sync.dart';
import '../data/auth_repository.dart';
import '../data/oauth_repository.dart';

sealed class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthUnknown extends AuthState {
  const AuthUnknown();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final UserProfile user;
  @override
  List<Object?> get props => [user];
}

class AuthGuest extends AuthState {
  const AuthGuest();
}

class AuthFailure extends AuthState {
  const AuthFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required this.auth,
    required this.api,
    required this.widgetSync,
    this.oauth,
    this.fcm,
  }) : super(const AuthUnknown());

  final AuthRepository auth;
  final OAuthRepository? oauth;
  final ApiClient api;
  final WidgetSync widgetSync;
  final FcmBootstrap? fcm;

  Future<void> bootstrap() async {
    // Остаёмся на AuthUnknown → splash, без AuthLoading и повторных спиннеров.
    try {
      final user = await auth.restoreSession();
      if (user == null) {
        emit(const AuthGuest());
      } else {
        emit(AuthAuthenticated(user));
        // Token register only after user completed the notifications intro.
        await fcm?.registerForUser();
      }
    } catch (e) {
      // Network/deploy blip with tokens still stored — stay on splash briefly, retry once.
      try {
        await Future<void>.delayed(const Duration(seconds: 2));
        final user = await auth.restoreSession();
        if (user == null) {
          emit(const AuthGuest());
        } else {
          emit(AuthAuthenticated(user));
          await fcm?.registerForUser();
        }
      } catch (_) {
        emit(AuthFailure(api.messageFromError(e)));
        emit(const AuthGuest());
      }
    }
  }

  Future<void> login(String email, String password) async {
    // Без AuthLoading → без повторного splash / полноэкранных лоадеров.
    try {
      final user = await auth.login(email: email, password: password);
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthFailure(api.messageFromError(e)));
      emit(const AuthGuest());
    }
  }

  Future<void> sendRegisterCode({
    required String name,
    required String email,
    required String password,
    required String passwordConfirm,
  }) async {
    try {
      await auth.sendRegisterCode(
        name: name,
        email: email,
        password: password,
        passwordConfirm: passwordConfirm,
      );
      emit(const AuthGuest());
    } catch (e) {
      emit(AuthFailure(api.messageFromError(e)));
      emit(const AuthGuest());
    }
  }

  Future<void> confirmRegister({
    required String email,
    required String code,
  }) async {
    try {
      final user = await auth.confirmRegister(email: email, code: code);
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthFailure(api.messageFromError(e)));
      emit(const AuthGuest());
    }
  }

  Future<void> logout() async {
    await fcm?.unregister();
    await auth.logout();
    await widgetSync.clearOnLogout();
    oauth?.invalidateIdentitiesCache();
    emit(const AuthGuest());
  }

  Future<void> deleteAccount() async {
    try {
      await fcm?.unregister();
    } catch (_) {
      /* server may already revoke tokens */
    }
    await auth.deleteAccount();
    await widgetSync.clearOnLogout();
    oauth?.invalidateIdentitiesCache();
    emit(const AuthGuest());
  }

  void setUser(UserProfile user) => emit(AuthAuthenticated(user));

  /// Успешный OAuth (токены уже сохранены в [OAuthRepository]).
  void acceptOAuthUser(UserProfile user) => emit(AuthAuthenticated(user));
}
