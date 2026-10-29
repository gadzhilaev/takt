import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/api_client.dart';
import 'core/pending_deep_link.dart';
import 'core/push/fcm_bootstrap.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'core/theme_controller.dart';
import 'core/theme_scope.dart';
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
  static String? get pendingDeepLink => PendingDeepLink.value;
  static set pendingDeepLink(String? v) => PendingDeepLink.value = v;

  /// Called when a home-screen widget is tapped while the app is alive.
  static VoidCallback? onWidgetDeepLink;

  @override
  State<TaktApp> createState() => _TaktAppState();
}

class _TaktAppState extends State<TaktApp> {
  late final WidgetSync _widgetSync;
  late final AuthRepository _authRepo;
  late final AuthCubit _authCubit;
  late final BoardCubit _boardCubit;
  late final NotificationsRepository _notifications;
  late final ThemeController _themeController;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _widgetSync = WidgetSync();
    _themeController = ThemeController()..load();
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
    _router = createRouter(_authCubit, widget.fcm);
    TaktApp.onWidgetDeepLink = _consumeDeepLink;
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumeDeepLink());
  }

  String? _lastConsumedLink;

  void _consumeDeepLink() {
    final raw = TaktApp.pendingDeepLink;
    if (raw == null || raw.isEmpty) return;
    final link = WidgetSync.routeFromAny(raw);
    // Deduplicate rapid double delivery (platform + home_widget).
    if (link == _lastConsumedLink) {
      TaktApp.pendingDeepLink = null;
      return;
    }
    if (_authCubit.state is AuthAuthenticated) {
      TaktApp.pendingDeepLink = null;
      _lastConsumedLink = link;
      _router.go(link);
    } else {
      // Keep normalized path until login completes.
      TaktApp.pendingDeepLink = link;
    }
  }

  @override
  void dispose() {
    if (TaktApp.onWidgetDeepLink == _consumeDeepLink) {
      TaktApp.onWidgetDeepLink = null;
    }
    _authCubit.close();
    _boardCubit.close();
    _themeController.dispose();
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
        child: ThemeScope(
          controller: _themeController,
          child: BlocListener<AuthCubit, AuthState>(
            listener: (context, state) {
              if (state is AuthAuthenticated) {
                context.read<BoardCubit>().setCurrentUserId(state.user.id);
                final board = context.read<BoardCubit>();
                if (board.state.project != null) {
                  board.setCurrentUserId(state.user.id);
                  unawaited(_republish(board));
                }
                _consumeDeepLink();
              } else if (state is AuthGuest) {
                context.read<BoardCubit>().setCurrentUserId(null);
              }
            },
            child: ListenableBuilder(
              listenable: _themeController,
              builder: (context, _) {
                return MaterialApp.router(
                  title: 'Takt',
                  theme: buildLightTheme(),
                  darkTheme: buildDarkTheme(),
                  themeMode: _themeController.mode,
                  routerConfig: _router,
                  debugShowCheckedModeBanner: false,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _republish(BoardCubit board) async {
    final project = board.state.project;
    final userId = board.currentUserId;
    if (project == null || userId == null) return;
    await _widgetSync.publishBoard(
      project: project,
      columns: board.state.columns,
      tasks: board.state.tasks,
      currentUserId: userId,
      allProjects: board.state.projects,
    );
  }
}
