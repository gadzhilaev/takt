import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/takt_select.dart';
import '../../../shared/widgets/urgency_badge.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../cubit/board_cubit.dart';

class TaskSheet extends StatefulWidget {
  const TaskSheet({super.key, required this.task});
  final TaskItem task;

  @override
  State<TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<TaskSheet> {
  bool _editing = false;
  late final TextEditingController _title;
  late final TextEditingController _description;
  late String _priority;
  late String _statusId;
  late Set<String> _assigneeIds;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.task.title);
    _description = TextEditingController(text: widget.task.description ?? '');
    _priority = widget.task.priority == 'low' ? 'medium' : widget.task.priority;
    _statusId = widget.task.statusId;
    _assigneeIds = widget.task.assignees.map((a) => a.id).toSet();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final board = context.watch<BoardCubit>().state;
    final members = board.project?.members ?? const <ProjectMember>[];
    final statusName = board.columns
        .where((c) => c.id == (_editing ? _statusId : widget.task.statusId))
        .map((c) => c.name)
        .firstOrNull;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 10,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: dark ? TaktColors.borderDark : TaktColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _editing ? 'Редактирование' : 'Задача',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            letterSpacing: -0.2,
                          ),
                    ),
                  ),
                  if (!_editing)
                    TextButton(
                      onPressed: () => setState(() => _editing = true),
                      child: const Text('Изменить'),
                    )
                  else
                    TextButton(
                      onPressed: () => setState(() => _editing = false),
                      child: const Text('Отмена'),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              const Divider(height: 1),
              const SizedBox(height: 12),
              if (_editing) ...[
                TextField(controller: _title, decoration: const InputDecoration(labelText: 'Название')),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Описание'),
                ),
                const SizedBox(height: 12),
                TaktSelectField<String>(
                  label: 'Срочность',
                  value: _priority,
                  options: const [
                    TaktSelectOption(value: 'urgent', label: 'Срочно'),
                    TaktSelectOption(value: 'high', label: 'Важно'),
                    TaktSelectOption(value: 'medium', label: 'Обычная'),
                  ],
                  onChanged: (v) => setState(() => _priority = v),
                ),
                const SizedBox(height: 12),
                TaktSelectField<String>(
                  label: 'Столбец',
                  value: _statusId,
                  options: board.columns
                      .map((c) => TaktSelectOption(value: c.id, label: c.name))
                      .toList(),
                  onChanged: (v) => setState(() => _statusId = v),
                ),
                const SizedBox(height: 16),
                Text('Исполнители', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: members.map((m) {
                    final selected = _assigneeIds.contains(m.userId);
                    return FilterChip(
                      avatar: TaktUserAvatar(name: m.name, avatarUrl: m.avatarUrl, size: 20, fontSize: 8),
                      label: Text(m.name, style: const TextStyle(fontSize: 13)),
                      selected: selected,
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _assigneeIds.add(m.userId);
                          } else {
                            _assigneeIds.remove(m.userId);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    final cubit = context.read<BoardCubit>();
                    final updated = TaskItem(
                      id: widget.task.id,
                      title: _title.text.trim(),
                      description:
                          _description.text.trim().isEmpty ? null : _description.text.trim(),
                      statusId: _statusId,
                      priority: _priority,
                      position: widget.task.position,
                      projectId: widget.task.projectId,
                      assignees: members
                          .where((m) => _assigneeIds.contains(m.userId))
                          .map(
                            (m) => TaskAssignee(
                              id: m.userId,
                              name: m.name,
                              avatarUrl: m.avatarUrl,
                            ),
                          )
                          .toList(),
                      closedAt: widget.task.closedAt,
                    );
                    if (_statusId != widget.task.statusId) {
                      await cubit.moveToColumn(widget.task, _statusId);
                    }
                    await cubit.updateTask(updated);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Сохранить'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    final done = board.columns.where((c) => c.isDone).toList();
                    if (done.isEmpty) return;
                    await context.read<BoardCubit>().moveToColumn(widget.task, done.first.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Завершить'),
                ),
              ] else ...[
                Text(
                  widget.task.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        height: 1.3,
                      ),
                ),
                const SizedBox(height: 10),
                UrgencyBadge(priority: widget.task.priority),
                const SizedBox(height: 16),
                _MetaLabel(text: 'Описание', muted: muted),
                const SizedBox(height: 4),
                Text(
                  (widget.task.description?.trim().isNotEmpty ?? false)
                      ? widget.task.description!
                      : 'Без описания',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: (widget.task.description?.trim().isNotEmpty ?? false)
                        ? (dark ? TaktColors.foregroundDark : TaktColors.graphite)
                        : muted,
                  ),
                ),
                const SizedBox(height: 16),
                _MetaLabel(text: 'Столбец', muted: muted),
                const SizedBox(height: 4),
                Text(statusName ?? '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 16),
                _MetaLabel(text: 'Исполнители', muted: muted),
                const SizedBox(height: 8),
                if (widget.task.assignees.isEmpty)
                  Text('Не назначены', style: TextStyle(fontSize: 14, color: muted))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.task.assignees
                        .map(
                          (a) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TaktUserAvatar(name: a.name, avatarUrl: a.avatarUrl, size: 24, fontSize: 9),
                              const SizedBox(width: 6),
                              Text(a.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaLabel extends StatelessWidget {
  const _MetaLabel({required this.text, required this.muted});
  final String text;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted, letterSpacing: 0.1),
    );
  }
}
