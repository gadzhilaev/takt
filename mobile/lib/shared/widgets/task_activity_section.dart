import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api_client.dart';
import '../../core/format_created_at.dart';
import '../../core/theme.dart';
import '../../features/board/data/board_repository.dart';
import '../models/models.dart';
import 'user_avatar.dart';

bool _isColumnMove(TaskActivityItem item) {
  final a = item.action.toLowerCase();
  return a == 'moved' || a == 'status_changed' || item.field == 'status_id';
}

/// Collapsible history: only column (status) moves.
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
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TaskActivitySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskId != widget.taskId) {
      _expanded = false;
      _load();
    }
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
        _items = items.where(_isColumnMove).toList();
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
    final border = dark ? TaktColors.borderDark : TaktColors.border;
    final surface = dark ? TaktColors.surface2Dark : TaktColors.surface2;
    final items = _items ?? const <TaskActivityItem>[];

    if (!_loading && _error == null && items.isEmpty) {
      return const SizedBox.shrink();
    }

    final subtitle = _loading
        ? 'Загрузка…'
        : _error != null
            ? _error!
            : '${items.length} ${_moveCountLabel(items.length)}';

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(TaktRadii.md),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          onExpansionChanged: (v) => setState(() => _expanded = v),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TaktRadii.md),
            side: BorderSide(color: border),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TaktRadii.md),
            side: BorderSide(color: border),
          ),
          title: Text(
            'История столбцов',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg),
          ),
          subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: muted)),
          trailing: Icon(
            _expanded ? Icons.expand_less : Icons.expand_more,
            color: muted,
          ),
          children: [
            if (_error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_error!, style: TextStyle(fontSize: 13, color: TaktColors.danger)),
              )
            else if (_loading)
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Загрузка…', style: TextStyle(fontSize: 14, color: muted)),
              )
            else
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
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
                            if (formatCreatedAt(item.createdAt) != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  formatCreatedAt(item.createdAt)!,
                                  style: TextStyle(fontSize: 11, color: muted),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

String _moveCountLabel(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return 'перенос';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'переноса';
  return 'переносов';
}
