import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/takt_app_bar.dart';
import '../../../shared/widgets/takt_ui.dart';
import '../data/notifications_repository.dart';
import '../../../shared/widgets/app_icon.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<AppNotification>? _items;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await context.read<NotificationsRepository>().list();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = context.read<ApiClient>().messageFromError(e);
        _loading = false;
      });
    }
  }

  Future<void> _open(AppNotification n) async {
    if (!n.isRead) {
      try {
        await context.read<NotificationsRepository>().markRead(n.id);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _items = _items
            ?.map((x) => x.id == n.id
                ? AppNotification(
                    id: x.id,
                    title: x.title,
                    kind: x.kind,
                    createdAt: x.createdAt,
                    body: x.body,
                    taskId: x.taskId,
                    projectId: x.projectId,
                    isRead: true,
                  )
                : x)
            .toList();
      });
    }
    if (!mounted) return;
    if (n.taskId != null && n.taskId!.isNotEmpty) {
      context.push('/task/${n.taskId}');
    } else if (n.projectId != null && n.projectId!.isNotEmpty) {
      context.go('/board?project=${n.projectId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final unread = _items?.where((n) => !n.isRead).length ?? 0;

    return Scaffold(
      appBar: TaktAppBar(
        title: 'Уведомления',
        onBack: () => context.pop(),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () async {
                await context.read<NotificationsRepository>().markAllRead();
                await _reload();
              },
              child: const Text('Прочитать все'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: _loading
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              )
            : _error != null
                ? ListView(
                    children: [
                      const SizedBox(height: 80),
                      TaktEmptyState(
                        title: 'Не удалось загрузить',
                        subtitle: _error,
                        icon: AppIcons.alert,
                        action: TaktButton(
                          label: 'Повторить',
                          variant: TaktButtonVariant.secondary,
                          onPressed: _reload,
                        ),
                      ),
                    ],
                  )
                : (_items == null || _items!.isEmpty)
                    ? ListView(
                        children: [
                          const SizedBox(height: 40),
                          const TaktEmptyState(
                            title: 'Пока нет уведомлений',
                            subtitle: 'Здесь появятся назначения, изменения статусов и приглашения',
                            icon: AppIcons.notifications,
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                        itemCount: _items!.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final n = _items![i];
                          return _NotificationTile(
                            notification: n,
                            dark: dark,
                            onTap: () => _open(n),
                          );
                        },
                      ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.dark,
    required this.onTap,
  });

  final AppNotification notification;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = taktSanitizeNotificationText(notification.title);
    final body = taktSanitizeNotificationText(notification.body);
    final time = taktRelativeTime(notification.createdAt);
    final accent = dark ? TaktColors.accentDark : TaktColors.accent;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    final surface = dark ? TaktColors.surfaceDark : TaktColors.surface;
    final border = dark ? TaktColors.borderDark : TaktColors.border;

    return Material(
      color: notification.isRead
          ? surface
          : (dark ? TaktColors.accentSoftDark : TaktColors.accentSoft),
      borderRadius: BorderRadius.circular(TaktRadii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TaktRadii.md),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TaktRadii.md),
            border: Border.all(color: border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: dark ? TaktColors.surface2Dark : TaktColors.surface2,
                  borderRadius: BorderRadius.circular(TaktRadii.sm),
                ),
                child: AppIcon(
                  AppIcon.notificationKind(notification.kind),
                  size: 18,
                  color: accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title.isEmpty ? 'Уведомление' : title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w600,
                              height: 1.35,
                              letterSpacing: -0.1,
                              color: dark ? TaktColors.foregroundDark : TaktColors.graphite,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, top: 4),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                            ),
                          ),
                      ],
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, height: 1.35, color: muted),
                      ),
                    ],
                    if (time.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        time,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: muted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
