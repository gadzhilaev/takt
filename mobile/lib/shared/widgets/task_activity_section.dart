import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api_client.dart';
import '../../core/format_created_at.dart';
import '../../core/theme.dart';
import '../../features/board/data/board_repository.dart';
import '../models/models.dart';
import 'takt_ui.dart';
import 'user_avatar.dart';

class TaskActivitySection extends StatefulWidget {
  const TaskActivitySection({super.key, required this.taskId});

  final String taskId;

  @override
  State<TaskActivitySection> createState() => _TaskActivitySectionState();
}

class _TaskActivitySectionState extends State<TaskActivitySection> {
  List<TaskActivityItem>? _items;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TaskActivitySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskId != widget.taskId) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await context.read<BoardRepository>().listActivity(widget.taskId);
      if (!mounted) return;
      setState(() {
        _items = items;
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

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    final fg = dark ? TaktColors.foregroundDark : TaktColors.graphite;
    final items = _items ?? const <TaskActivityItem>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TaktFieldLabel('История'),
        const SizedBox(height: 8),
        if (_loading)
          Text('Загрузка…', style: TextStyle(fontSize: 14, color: muted))
        else if (_error != null)
          Text(_error!, style: TextStyle(fontSize: 13, color: TaktColors.danger))
        else if (items.isEmpty)
          Text('Пока нет событий', style: TextStyle(fontSize: 14, color: muted))
        else
          ...items.map((item) {
            final timeLabel = formatCreatedAt(item.createdAt);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TaktUserAvatar(
                    name: item.userName,
                    avatarUrl: item.userAvatarUrl,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            style: TextStyle(fontSize: 13, height: 1.35, color: fg),
                            children: [
                              TextSpan(
                                text: item.userName,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              TextSpan(text: ' ${item.summary}'),
                            ],
                          ),
                        ),
                        if (timeLabel != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(timeLabel, style: TextStyle(fontSize: 11, color: muted)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
