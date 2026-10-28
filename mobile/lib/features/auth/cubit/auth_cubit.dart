import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api_client.dart';
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
    required AuthRepository auth,
    required ApiClient api,
    required WidgetSync widgetSync,
  })  : _auth = auth,
        _api = api,
        _widgetSync = widgetSync,
        super(const AuthUnknown());

  final AuthRepository _auth;
  final ApiClient _api;
  final WidgetSync _widgetSync;

  Future<void> bootstrap() async {
    emit(const AuthLoading());
    try {
      final user = await _auth.restoreSession();
      if (user == null) {
        emit(const AuthGuest());
      } else {
        emit(AuthAuthenticated(user));
      }
    } catch (e) {
      emit(AuthFailure(_api.messageFromError(e)));
      emit(const AuthGuest());
    }
  }

  Future<void> login(String email, String password) async {
    emit(const AuthLoading());
    try {
      final user = await _auth.login(email: email, password: password);
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthFailure(_api.messageFromError(e)));
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
      final user = await _auth.register(
        name: name,
        email: email,
        password: password,
        passwordConfirm: passwordConfirm,
      );
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthFailure(_api.messageFromError(e)));
      emit(const AuthGuest());
    }
  }

  Future<void> logout() async {
    await _auth.logout();
    await _widgetSync.clearOnLogout();
    emit(const AuthGuest());
  }

  void setUser(UserProfile user) => emit(AuthAuthenticated(user));
}
