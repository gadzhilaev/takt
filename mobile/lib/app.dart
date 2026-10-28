import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/api_client.dart';
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
  const TaktApp({super.key});

  @override
  State<TaktApp> createState() => _TaktAppState();
}

class _TaktAppState extends State<TaktApp> {
  late final TokenStorage _tokens;
  late final ApiClient _api;
  late final WidgetSync _widgetSync;
  late final AuthRepository _authRepo;
  late final AuthCubit _authCubit;
  late final BoardCubit _boardCubit;

  @override
  void initState() {
    super.initState();
    _tokens = TokenStorage();
    _api = ApiClient(tokens: _tokens);
    _widgetSync = WidgetSync();
    _authRepo = AuthRepository(api: _api, tokens: _tokens);
    _authCubit = AuthCubit(auth: _authRepo, api: _api, widgetSync: _widgetSync)..bootstrap();
    final projects = ProjectsRepository(_api);
    _boardCubit = BoardCubit(
      board: BoardRepository(_api),
      projects: projects,
      api: _api,
      widgetSync: _widgetSync,
    );
  }

  @override
  void dispose() {
    _authCubit.close();
    _boardCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = createRouter(_authCubit);
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: _api),
        RepositoryProvider.value(value: _authRepo),
        RepositoryProvider.value(value: ProjectsRepository(_api)),
        RepositoryProvider.value(value: BoardRepository(_api)),
        RepositoryProvider.value(value: NotificationsRepository(_api)),
        RepositoryProvider.value(value: ProfileRepository(_api)),
        RepositoryProvider.value(value: _widgetSync),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _authCubit),
          BlocProvider.value(value: _boardCubit),
        ],
        child: MaterialApp.router(
          title: 'Takt',
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: ThemeMode.system,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
