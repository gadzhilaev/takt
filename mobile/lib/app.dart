import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/api_client.dart';
import 'core/push/fcm_bootstrap.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'core/token_storage.dart';
import 'features/auth/cubit/auth_cubit.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/board/cubit/board_cubit.dart';
import 'features/board/data/board_repository.dart';
import 'features/notifications/data/notifications_repository.dart';
import 'features/profile/data/profile_repository.dart';
import 'features/projects/data/projects_repository.dart';
import 'features/widget_sync/widget_sync.dart';

class TaktApp extends StatefulWidget {
  const TaktApp({
    super.key,
    required this.tokens,
    required this.api,
    required this.fcm,
  });

  final TokenStorage tokens;
  final ApiClient api;
  final FcmBootstrap fcm;

  /// Set before runApp / from FCM / widget launch.
  static String? pendingDeepLink;

  @override
  State<TaktApp> createState() => _TaktAppState();
}

class _TaktAppState extends State<TaktApp> {
  late final WidgetSync _widgetSync;
  late final AuthRepository _authRepo;
  late final AuthCubit _authCubit;
  late final BoardCubit _boardCubit;
  late final NotificationsRepository _notifications;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _widgetSync = WidgetSync();
    _authRepo = AuthRepository(api: widget.api, tokens: widget.tokens);
    _notifications = NotificationsRepository(widget.api);
    _authCubit = AuthCubit(
      auth: _authRepo,
      api: widget.api,
      widgetSync: _widgetSync,
      fcm: widget.fcm,
    )..bootstrap();
    final projects = ProjectsRepository(widget.api);
    _boardCubit = BoardCubit(
      board: BoardRepository(widget.api),
      projects: projects,
      api: widget.api,
      widgetSync: _widgetSync,
    );
    _router = createRouter(_authCubit);
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumeDeepLink());
  }

  void _consumeDeepLink() {
    final link = TaktApp.pendingDeepLink;
    if (link == null || link.isEmpty) return;
    TaktApp.pendingDeepLink = null;
    if (_authCubit.state is AuthAuthenticated) {
      _router.go(link.startsWith('/') ? link : '/board');
    }
  }

  @override
  void dispose() {
    _authCubit.close();
    _boardCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: widget.api),
        RepositoryProvider.value(value: _authRepo),
        RepositoryProvider.value(value: ProjectsRepository(widget.api)),
        RepositoryProvider.value(value: BoardRepository(widget.api)),
        RepositoryProvider.value(value: _notifications),
        RepositoryProvider.value(value: ProfileRepository(widget.api)),
        RepositoryProvider.value(value: _widgetSync),
        RepositoryProvider.value(value: widget.fcm),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _authCubit),
          BlocProvider.value(value: _boardCubit),
        ],
        child: BlocListener<AuthCubit, AuthState>(
          listener: (context, state) {
            if (state is AuthAuthenticated) _consumeDeepLink();
          },
          child: MaterialApp.router(
            title: 'Takt',
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: ThemeMode.system,
            routerConfig: _router,
            debugShowCheckedModeBanner: false,
          ),
        ),
      ),
    );
  }
}
