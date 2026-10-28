import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/models/models.dart';
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

  String _priorityLabel(String p) {
    switch (p) {
      case 'urgent':
        return 'Срочно';
      case 'high':
        return 'Важно';
      default:
        return 'Обычная';
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = context.watch<BoardCubit>().state;
    final members = board.project?.members ?? const <ProjectMember>[];
    final statusName = board.columns
        .where((c) => c.id == widget.task.statusId)
        .map((c) => c.name)
        .firstOrNull;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
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
                  color: Theme.of(context).dividerColor,
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
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (!_editing)
                  TextButton.icon(
                    onPressed: () => setState(() => _editing = true),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Редактировать'),
                  )
                else
                  TextButton(
                    onPressed: () => setState(() => _editing = false),
                    child: const Text('Готово'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
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
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _priority,
                decoration: const InputDecoration(labelText: 'Срочность'),
                items: const [
                  DropdownMenuItem(value: 'urgent', child: Text('Срочно')),
                  DropdownMenuItem(value: 'high', child: Text('Важно')),
                  DropdownMenuItem(value: 'medium', child: Text('Обычная')),
                ],
                onChanged: (v) => setState(() => _priority = v ?? 'medium'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _statusId,
                decoration: const InputDecoration(labelText: 'Столбец'),
                items: board.columns
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                    .toList(),
                onChanged: (v) => setState(() => _statusId = v ?? _statusId),
              ),
              const SizedBox(height: 16),
              Text('Исполнители', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: members.map((m) {
                  final selected = _assigneeIds.contains(m.userId);
                  return FilterChip(
                    label: Text(m.name),
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text('Описание', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(
                (widget.task.description?.trim().isNotEmpty ?? false)
                    ? widget.task.description!
                    : 'Без описания',
                style: TextStyle(
                  color: (widget.task.description?.trim().isNotEmpty ?? false)
                      ? null
                      : Theme.of(context).hintColor,
                ),
              ),
              const SizedBox(height: 16),
              Text('Столбец', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(statusName ?? '—'),
              const SizedBox(height: 12),
              Text('Срочность', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(_priorityLabel(widget.task.priority)),
              const SizedBox(height: 12),
              Text('Исполнители', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              if (widget.task.assignees.isEmpty)
                Text('Не назначены', style: TextStyle(color: Theme.of(context).hintColor))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: widget.task.assignees
                      .map((a) => Chip(label: Text(a.name), visualDensity: VisualDensity.compact))
                      .toList(),
                ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}
