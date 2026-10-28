import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/cubit/auth_cubit.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/board/cubit/board_cubit.dart';
import '../features/board/presentation/board_page.dart';
import '../features/notifications/presentation/notifications_page.dart';
import '../features/profile/presentation/profile_page.dart';

GoRouter createRouter(AuthCubit authCubit) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _AuthListenable(authCubit),
    redirect: (context, state) {
      final auth = authCubit.state;
      final loggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';
      if (auth is AuthUnknown || auth is AuthLoading) return null;
      if (auth is AuthGuest) return loggingIn ? null : '/login';
      if (auth is AuthAuthenticated && loggingIn) return '/board';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
      GoRoute(
        path: '/board',
        builder: (context, state) {
          final projectId = state.uri.queryParameters['project'];
          final taskId = state.uri.queryParameters['task'];
          if (projectId != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.read<BoardCubit>().openProject(projectId);
            });
          }
          return BoardPage(deepTaskId: taskId);
        },
      ),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsPage()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
    ],
  );
}

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._cubit) {
    _cubit.stream.listen((_) => notifyListeners());
  }
  final AuthCubit _cubit;
}
