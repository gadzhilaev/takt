import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../shared/models/models.dart';
import '../data/notifications_repository.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<List<AppNotification>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<NotificationsRepository>().list();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        actions: [
          TextButton(
            onPressed: () async {
              await context.read<NotificationsRepository>().markAllRead();
              setState(() => _future = context.read<NotificationsRepository>().list());
            },
            child: const Text('Прочитать все'),
          ),
        ],
      ),
      body: FutureBuilder<List<AppNotification>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text(context.read<ApiClient>().messageFromError(snap.error!)));
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return const Center(child: Text('Пока нет уведомлений'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = items[i];
              return ListTile(
                title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.w400 : FontWeight.w600)),
                subtitle: n.body == null ? null : Text(n.body!, maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () async {
                  await context.read<NotificationsRepository>().markRead(n.id);
                  if (!context.mounted) return;
                  if (n.projectId != null) {
                    context.go('/board?project=${n.projectId}${n.taskId != null ? '&task=${n.taskId}' : ''}');
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
