import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/takt_app_bar.dart';
import '../../../shared/widgets/takt_ui.dart';
import '../data/notifications_repository.dart';

enum _Filter { all, unread }

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<AppNotification>? _items;
  String? _error;
  bool _loading = true;
  _Filter _filter = _Filter.all;

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
        _items = _items?.map((x) => x.id == n.id ? x.copyWith(isRead: true) : x).toList();
      });
    }
    if (!mounted) return;
    if (n.taskId != null && n.taskId!.isNotEmpty) {
      context.push('/task/${n.taskId}');
    } else if (n.projectId != null && n.projectId!.isNotEmpty) {
      context.go('/board?project=${n.projectId}');
    }
  }

  List<AppNotification> get _filtered {
    final all = _items ?? const <AppNotification>[];
    if (_filter == _Filter.unread) return all.where((n) => !n.isRead).toList();
    return all;
  }

  List<({TaktDateGroup group, List<AppNotification> items})> get _groups {
    final map = <TaktDateGroup, List<AppNotification>>{
      TaktDateGroup.today: [],
      TaktDateGroup.yesterday: [],
      TaktDateGroup.earlier: [],
    };
    for (final n in _filtered) {
      map[taktDateGroup(n.createdAt)]!.add(n);
    }
    return [
      for (final g in TaktDateGroup.values)
        if (map[g]!.isNotEmpty) (group: g, items: map[g]!),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final unread = _items?.where((n) => !n.isRead).length ?? 0;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;

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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Все',
                  selected: _filter == _Filter.all,
                  onTap: () => setState(() => _filter = _Filter.all),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Непрочитанные',
                  selected: _filter == _Filter.unread,
                  onTap: () => setState(() => _filter = _Filter.unread),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              child: _loading
                  ? ListView(children: const [SizedBox(height: 1)])
                  : _error != null
                      ? ListView(
                          children: [
                            const SizedBox(height: 80),
                            TaktEmptyState(
                              title: _error!,
                              subtitle: null,
                              icon: AppIcons.alert,
                              action: TaktButton(
                                label: 'Повторить',
                                variant: TaktButtonVariant.secondary,
                                onPressed: _reload,
                              ),
                            ),
                          ],
                        )
                      : _filtered.isEmpty
                          ? ListView(
                              children: [
                                const SizedBox(height: 40),
                                TaktEmptyState(
                                  title: _filter == _Filter.unread
                                      ? 'Нет непрочитанных'
                                      : 'Пока нет уведомлений',
                                  subtitle: 'Здесь появятся назначения, изменения статусов и приглашения',
                                  icon: AppIcons.notifications,
                                ),
                              ],
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                              children: [
                                for (final section in _groups) ...[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                                    child: Text(
                                      taktDateGroupLabel(section.group).toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.4,
                                        color: muted,
                                      ),
                                    ),
                                  ),
                                  for (final n in section.items)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _NotificationCard(
                                        notification: n,
                                        dark: dark,
                                        onTap: () => _open(n),
                                      ),
                                    ),
                                ],
                              ],
                            ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: selected
          ? TaktColors.accent
          : (dark ? TaktColors.surface2Dark : TaktColors.surface2),
      borderRadius: BorderRadius.circular(TaktRadii.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TaktRadii.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Colors.white
                  : (dark ? TaktColors.mutedDark : TaktColors.muted),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.dark,
    required this.onTap,
  });

  final AppNotification notification;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kindLabel = taktNotificationKindLabel(notification.kind);
    final parts = taktNotificationCardParts(
      kind: notification.kind,
      title: notification.title,
      body: notification.body,
      projectName: notification.projectName,
    );
    final time = taktRelativeTime(notification.createdAt);
    final accent = dark ? TaktColors.accentDark : TaktColors.accent;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    final fg = dark ? TaktColors.foregroundDark : TaktColors.graphite;
    final surface = dark ? TaktColors.surfaceDark : TaktColors.surface;
    final border = dark ? TaktColors.borderDark : TaktColors.border;
    // Unread must contrast with the page canvas (accentSoft blends too much).
    final unreadBg = dark ? const Color(0xFF243840) : const Color(0xFFDCE8EE);
    final unreadBorder = dark ? accent.withValues(alpha: 0.45) : const Color(0xFFB5CAD6);
    final cardBg = notification.isRead ? surface : unreadBg;
    final cardBorder = notification.isRead ? border : unreadBorder;

    return Material(
      color: cardBg,
      elevation: notification.isRead ? 0 : 1,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(TaktRadii.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TaktRadii.lg),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TaktRadii.lg),
            border: Border.all(color: cardBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: dark ? TaktColors.surface2Dark : Colors.white,
                  shape: BoxShape.circle,
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
                            kindLabel,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: fg,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (time.isNotEmpty)
                              Text(
                                time,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: muted),
                              ),
                            if (!notification.isRead) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    if (parts.subject.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        parts.subject,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          color: fg,
                        ),
                      ),
                    ],
                    if (parts.detail.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        parts.detail,
                        style: TextStyle(fontSize: 12.5, height: 1.35, color: muted),
                      ),
                    ],
                    if (parts.projectLine.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        parts.projectLine,
                        style: TextStyle(fontSize: 12.5, height: 1.35, color: muted),
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
