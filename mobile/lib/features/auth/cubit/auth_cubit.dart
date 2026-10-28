import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api_client.dart';
import '../../../core/push/fcm_bootstrap.dart';
import '../../../shared/models/models.dart';
import '../../widget_sync/widget_sync.dart';
import '../data/auth_repository.dart';

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
    this.fcm,
  }) : super(const AuthUnknown());

  final AuthRepository auth;
  final ApiClient api;
  final WidgetSync widgetSync;
  final FcmBootstrap? fcm;

  Future<void> bootstrap() async {
    emit(const AuthLoading());
    try {
      final user = await auth.restoreSession();
      if (user == null) {
        emit(const AuthGuest());
      } else {
        emit(AuthAuthenticated(user));
        await fcm?.registerForUser();
      }
    } catch (e) {
      emit(AuthFailure(api.messageFromError(e)));
      emit(const AuthGuest());
    }
  }

  Future<void> login(String email, String password) async {
    emit(const AuthLoading());
    try {
      final user = await auth.login(email: email, password: password);
      emit(AuthAuthenticated(user));
      await fcm?.registerForUser();
    } catch (e) {
      emit(AuthFailure(api.messageFromError(e)));
      emit(const AuthGuest());
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirm,
  }) async {
    emit(const AuthLoading());
    try {
      final user = await auth.register(
        name: name,
        email: email,
        password: password,
        passwordConfirm: passwordConfirm,
      );
      emit(AuthAuthenticated(user));
      await fcm?.registerForUser();
    } catch (e) {
      emit(AuthFailure(api.messageFromError(e)));
      emit(const AuthGuest());
    }
  }

  Future<void> logout() async {
    await fcm?.unregister();
    await auth.logout();
    await widgetSync.clearOnLogout();
    emit(const AuthGuest());
  }

  void setUser(UserProfile user) => emit(AuthAuthenticated(user));
}
