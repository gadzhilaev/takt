import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/cubit/auth_cubit.dart';
import '../features/auth/presentation/forgot_password_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/notifications_intro_page.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/board/presentation/board_page.dart';
import '../features/board/presentation/task_detail_page.dart';
import '../features/board/presentation/task_form_page.dart';
import '../features/my_tasks/presentation/my_tasks_page.dart';
import '../features/notifications/presentation/notifications_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/projects/presentation/project_members_page.dart';
import '../features/projects/presentation/projects_welcome_page.dart';
import '../features/shell/app_shell.dart';
import '../features/shell/sliding_branch_stack.dart';
import '../features/widget_sync/widget_sync.dart';
import '../shared/widgets/takt_app_bar.dart';
import '../shared/widgets/takt_mark.dart';
import 'pending_deep_link.dart';
import 'push/fcm_bootstrap.dart';
import 'theme.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(AuthCubit authCubit, FcmBootstrap fcm) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: Listenable.merge([_AuthListenable(authCubit), fcm.promptSeenListenable]),
    redirect: (context, state) {
      final mapped = _mapDeepLink(state);
      if (mapped != null) return mapped;

      final auth = authCubit.state;
      final loc = state.matchedLocation;
      final onSplash = loc == '/splash';
      final loggingIn = loc == '/login' || loc == '/register' || loc == '/forgot-password';
      final onPushIntro = loc == '/enable-notifications';

      if (auth is AuthUnknown) {
        return onSplash ? null : '/splash';
      }

      // AuthLoading больше не гоняет на splash — остаёмся на текущем экране.
      if (auth is AuthLoading) {
        return null;
      }

      if (auth is AuthGuest) {
        if (onSplash) return null;
        if (onPushIntro) return '/login';
        // Defer deep link until after login — keep as pending via fullPath store.
        if (!loggingIn && _isAppPath(loc)) {
          // Guest trying to open app content → login; path preserved by TaktApp.pendingDeepLink.
          return '/login';
        }
        return loggingIn ? null : '/login';
      }

      if (auth is AuthAuthenticated) {
        if (onSplash) return null;
        if (onPushIntro) return null;
        if (!fcm.promptSeen) return '/enable-notifications';
        // Задание/сброс пароля доступен и из профиля (OAuth-only аккаунты).
        if (loc == '/forgot-password') return null;
        if (loggingIn) {
          // Prefer pending widget/push deep link over project hub.
          final pending = PendingDeepLink.value;
          if (pending != null &&
              pending.isNotEmpty &&
              pending != '/login' &&
              pending != '/register' &&
              pending != '/forgot-password') {
            return pending.startsWith('/') ? pending : WidgetSync.routeFromAny(pending);
          }
          return '/projects';
        }
        return null;
      }

      if (auth is AuthFailure) {
        if (onSplash) return null;
        return loggingIn ? null : '/login';
      }

      return null;
    },
    errorBuilder: (context, state) => _TaktNotFoundPage(error: state.error),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(
        path: '/register',
        pageBuilder: (_, state) => CupertinoPage<void>(
          key: state.pageKey,
          child: const RegisterPage(),
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (_, state) => CupertinoPage<void>(
          key: state.pageKey,
          child: const ForgotPasswordPage(),
        ),
      ),
      GoRoute(path: '/enable-notifications', builder: (_, _) => const NotificationsIntroPage()),
      GoRoute(
        path: '/projects',
        builder: (_, _) => const ProjectsWelcomePage(),
      ),
      GoRoute(
        path: '/projects/:projectId/members',
        pageBuilder: (context, state) {
          final id = state.pathParameters['projectId']!;
          return CupertinoPage(
            key: state.pageKey,
            child: ProjectMembersPage(projectId: id),
          );
        },
      ),
      StatefulShellRoute(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        navigatorContainerBuilder: (context, navigationShell, children) {
          return SlidingBranchStack(
            currentIndex: navigationShell.currentIndex,
            children: children,
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/board',
                builder: (context, state) {
                  final projectId = state.uri.queryParameters['project'];
                  final taskId = state.uri.queryParameters['task'];
                  return BoardPage(
                    deepTaskId: taskId,
                    deepProjectId: projectId,
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my-tasks',
                builder: (_, _) => const MyTasksPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfilePage(embeddedInShell: true),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/notifications',
        pageBuilder: (_, state) => CupertinoPage<void>(
          key: state.pageKey,
          child: const NotificationsPage(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/task/:taskId',
        pageBuilder: (_, state) => CupertinoPage<void>(
          key: state.pageKey,
          child: TaskDetailPage(taskId: state.pathParameters['taskId']!),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/task-edit/:taskId',
        pageBuilder: (_, state) => CupertinoPage<void>(
          key: state.pageKey,
          child: TaskFormPage(taskId: state.pathParameters['taskId']),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/task-create',
        pageBuilder: (_, state) => CupertinoPage<void>(
          key: state.pageKey,
          child: TaskFormPage(
            initialStatusId: state.uri.queryParameters['status'],
          ),
        ),
      ),
    ],
  );
}

/// Convert platform `takt://…` (or mistaken `/` / full URI locations) to in-app paths.
String? _mapDeepLink(GoRouterState state) {
  final uri = state.uri;
  if (uri.scheme == 'takt') {
    return WidgetSync.routeFromUri(uri);
  }
  final full = state.uri.toString();
  if (full.startsWith('takt:')) {
    return WidgetSync.routeFromAny(full);
  }
  // Platform sometimes delivers empty root — must not hit errorBuilder.
  if (state.matchedLocation == '/' || (uri.scheme.isEmpty && uri.path == '/')) {
    if (uri.hasQuery || uri.hasFragment) {
      return WidgetSync.routeFromAny(uri);
    }
    return '/splash';
  }
  return null;
}

bool _isAppPath(String loc) {
  return loc.startsWith('/board') ||
      loc.startsWith('/my-tasks') ||
      loc.startsWith('/profile') ||
      loc.startsWith('/projects') ||
      loc.startsWith('/task') ||
      loc.startsWith('/task-edit') ||
      loc.startsWith('/task-create') ||
      loc.startsWith('/notifications') ||
      loc.startsWith('/enable-notifications');
}

class _TaktNotFoundPage extends StatelessWidget {
  const _TaktNotFoundPage({this.error});
  final Exception? error;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? TaktColors.surface2Dark : const Color(0xFFE9EDF2),
      appBar: TaktAppBar(
        title: 'Ошибка',
        onBack: () => context.go('/projects'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            const Center(child: TaktMark(size: 40)),
            const SizedBox(height: 20),
            Text(
              'Страница не найдена',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: dark ? TaktColors.foregroundDark : TaktColors.graphite,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ссылка устарела или ведёт в недоступный раздел.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: dark ? TaktColors.mutedDark : TaktColors.muted,
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => context.go('/projects'),
              child: const Text('К проектам'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._cubit) {
    _cubit.stream.listen((_) => notifyListeners());
  }
  final AuthCubit _cubit;
}
