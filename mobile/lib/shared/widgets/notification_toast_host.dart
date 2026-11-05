import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/push/fcm_bootstrap.dart';
import '../../core/theme.dart';
import '../../features/auth/cubit/auth_cubit.dart';
import '../../features/notifications/data/notifications_repository.dart';
import 'app_icon.dart';
import 'takt_ui.dart';

/// Bottom in-app toasts for new notifications (API poll + FCM foreground).
class NotificationToastHost extends StatefulWidget {
  const NotificationToastHost({super.key, required this.child});

  final Widget child;

  @override
  State<NotificationToastHost> createState() => _NotificationToastHostState();
}

class _NotificationToastHostState extends State<NotificationToastHost> with WidgetsBindingObserver {
  final _toasts = <_ToastData>[];
  Set<String>? _seenIds;
  Timer? _poll;
  bool _pollInFlight = false;
  VoidCallback? _fcmListener;
  FcmBootstrap? _fcm;

  static const _pollInterval = Duration(seconds: 45);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    if (!mounted) return;
    _fcm = context.read<FcmBootstrap>();
    _fcmListener = () {
      final msg = _fcm?.foregroundMessage.value;
      if (msg == null) return;
      _fcm?.foregroundMessage.value = null;
      _pushFcm(msg);
    };
    _fcm!.foregroundMessage.addListener(_fcmListener!);
    _schedulePoll();
    unawaited(_pollApi());
  }

  void _schedulePoll() {
    _poll?.cancel();
    _poll = Timer.periodic(_pollInterval, (_) => unawaited(_pollApi()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _schedulePoll();
      unawaited(_pollApi());
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _poll?.cancel();
      _poll = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    if (_fcmListener != null) {
      _fcm?.foregroundMessage.removeListener(_fcmListener!);
    }
    super.dispose();
  }

  Future<void> _pollApi() async {
    if (!mounted || _pollInFlight) return;
    final auth = context.read<AuthCubit>().state;
    if (auth is! AuthAuthenticated) return;
    _pollInFlight = true;
    try {
      // Toast needs only newest unread — keep payload small.
      final items = await context.read<NotificationsRepository>().list(
            unreadOnly: true,
            pageSize: 15,
          );
      if (!mounted) return;
      if (_seenIds == null) {
        _seenIds = items.map((e) => e.id).toSet();
        return;
      }
      final fresh = items.where((n) => !_seenIds!.contains(n.id)).toList();
      for (final n in fresh) {
        _seenIds!.add(n.id);
      }
      for (final n in fresh.reversed) {
        final title = taktSanitizeNotificationText(n.title);
        final body = taktSanitizeNotificationText(n.body);
        _enqueue(
          _ToastData(
            id: n.id,
            title: title.isEmpty ? 'Уведомление' : title,
            body: body.isEmpty ? null : body,
            taskId: n.taskId,
            projectId: n.projectId,
          ),
        );
      }
    } catch (_) {
      /* ignore poll errors — next tick or FCM will retry */
    } finally {
      _pollInFlight = false;
    }
  }

  void _pushFcm(RemoteMessage message) {
    final title = message.notification?.title ?? message.data['title'] as String? ?? 'Takt';
    final body = message.notification?.body ?? message.data['body'] as String?;
    final id = message.messageId ?? 'fcm-${DateTime.now().millisecondsSinceEpoch}';
    final route = FcmBootstrap.routeFromMessage(message);
    String? taskId;
    String? projectId;
    if (route != null) {
      final uri = Uri.tryParse(route);
      taskId = uri?.queryParameters['task'] ??
          (route.startsWith('/task/') ? route.split('/').last : null);
      projectId = uri?.queryParameters['project'];
    }
    _enqueue(
      _ToastData(
        id: id,
        title: title,
        body: body,
        taskId: taskId,
        projectId: projectId,
        route: route,
      ),
    );
  }

  void _enqueue(_ToastData toast) {
    setState(() {
      _toasts.insert(0, toast);
      if (_toasts.length > 4) _toasts.removeLast();
    });
    Future<void>.delayed(const Duration(seconds: 6), () {
      if (!mounted) return;
      setState(() => _toasts.removeWhere((t) => t.id == toast.id));
    });
  }

  void _open(_ToastData t) {
    setState(() => _toasts.removeWhere((x) => x.id == t.id));
    if (t.route != null && t.route!.isNotEmpty) {
      context.go(t.route!);
      return;
    }
    if (t.taskId != null && t.taskId!.isNotEmpty) {
      context.push('/task/${t.taskId}');
    } else if (t.projectId != null && t.projectId!.isNotEmpty) {
      context.go('/board?project=${t.projectId}');
    } else {
      context.push('/notifications');
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        widget.child,
        if (_toasts.isNotEmpty)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12 + MediaQuery.paddingOf(context).bottom,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final t in _toasts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: dark ? TaktColors.surface2Dark : Colors.white,
                      elevation: 4,
                      shadowColor: Colors.black26,
                      borderRadius: BorderRadius.circular(TaktRadii.lg),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(TaktRadii.lg),
                        onTap: () => _open(t),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: TaktColors.accent.withValues(alpha: dark ? 0.22 : 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: AppIcon(
                                  AppIcons.notifications,
                                  size: 18,
                                  color: dark ? const Color(0xFF6A9AAB) : TaktColors.accent,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: dark ? TaktColors.foregroundDark : TaktColors.graphite,
                                      ),
                                    ),
                                    if (t.body != null && t.body!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          t.body!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: dark ? TaktColors.mutedDark : TaktColors.muted,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => setState(() => _toasts.removeWhere((x) => x.id == t.id)),
                                icon: Icon(
                                  Icons.close,
                                  size: 18,
                                  color: dark ? TaktColors.mutedDark : TaktColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ToastData {
  _ToastData({
    required this.id,
    required this.title,
    this.body,
    this.taskId,
    this.projectId,
    this.route,
  });

  final String id;
  final String title;
  final String? body;
  final String? taskId;
  final String? projectId;
  final String? route;
}
