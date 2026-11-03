import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_icon.dart';
import '../../../core/theme.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/takt_app_bar.dart';
import '../../../shared/widgets/takt_select.dart';
import '../../../shared/widgets/takt_sheet.dart';
import '../../../shared/widgets/takt_ui.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../cubit/board_cubit.dart';

class TaskFormPage extends StatefulWidget {
  const TaskFormPage({
    super.key,
    this.taskId,
    this.initialStatusId,
  });

  final String? taskId;
  final String? initialStatusId;

  bool get isCreate => taskId == null;

  @override
  State<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends State<TaskFormPage> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  late String _priority;
  late String _statusId;
  late Set<String> _assigneeIds;
  bool _saving = false;
  TaskItem? _existing;

  @override
  void initState() {
    super.initState();
    final board = context.read<BoardCubit>().state;
    _priority = 'medium';
    _statusId = widget.initialStatusId ??
        board.currentColumn?.id ??
        (board.columns.isNotEmpty ? board.columns.first.id : '');
    _assigneeIds = {};

    if (widget.taskId != null) {
      for (final t in board.tasks) {
        if (t.id == widget.taskId) {
          _existing = t;
          _title.text = t.title;
          _description.text = t.description ?? '';
          _priority = t.priority == 'low' ? 'medium' : t.priority;
          _statusId = t.statusId;
          _assigneeIds = t.assignees.map((a) => a.id).toSet();
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty || _statusId.isEmpty) return;
    setState(() => _saving = true);
    final cubit = context.read<BoardCubit>();
    final board = cubit.state;
    final members = board.project?.members ?? const <ProjectMember>[];

    try {
      if (widget.isCreate) {
        await cubit.createTask(
          title: title,
          description: _description.text.trim().isEmpty ? null : _description.text.trim(),
          priority: _priority,
          assigneeIds: _assigneeIds.toList(),
          statusId: _statusId,
        );
      } else if (_existing != null) {
        if (_statusId != _existing!.statusId) {
          await cubit.moveToColumn(_existing!, _statusId);
        }
        await cubit.updateTask(
          TaskItem(
            id: _existing!.id,
            title: title,
            description: _description.text.trim().isEmpty ? null : _description.text.trim(),
            statusId: _statusId,
            priority: _priority,
            position: _existing!.position,
            projectId: _existing!.projectId,
            assignees: members
                .where((m) => _assigneeIds.contains(m.userId))
                .map((m) => TaskAssignee(id: m.userId, name: m.name, avatarUrl: m.avatarUrl))
                .toList(),
            closedAt: _existing!.closedAt,
            authorId: _existing!.authorId,
            authorName: _existing!.authorName,
          ),
        );
      }
      if (mounted) _leave(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _leave([Object? result]) {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop(result);
    } else {
      context.go(context.read<BoardCubit>().state.project != null ? '/board' : '/projects');
    }
  }

  Future<void> _pickAssignees(List<ProjectMember> members) async {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    final fg = dark ? TaktColors.foregroundDark : TaktColors.graphite;
    final result = await showTaktDialog<Set<String>>(
      context: context,
      builder: (ctx) {
        var selected = Set<String>.from(_assigneeIds);
        var query = '';
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final filtered = members.where((m) {
              if (query.trim().isEmpty) return true;
              return m.name.toLowerCase().contains(query.trim().toLowerCase());
            }).toList();
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 400,
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.72,
                ),
                child: Material(
                  color: dark ? TaktColors.surfaceDark : TaktColors.surface,
                  elevation: 8,
                  shadowColor: Colors.black.withValues(alpha: dark ? 0.45 : 0.18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(TaktRadii.lg),
                    side: BorderSide(color: dark ? TaktColors.borderDark : TaktColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Исполнители',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.25,
                                  color: fg,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Закрыть',
                              onPressed: () => Navigator.pop(ctx),
                              icon: AppIcon(AppIcons.close, size: 20, color: muted),
                            ),
                          ],
                        ),
                      ),
                      if (members.length > 6)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: TextField(
                            onChanged: (v) => setLocal(() => query = v),
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: 'Поиск',
                              prefixIcon: AppIcon(AppIcons.search, size: 20),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final m = filtered[i];
                            final on = selected.contains(m.userId);
                            return ListTile(
                              dense: true,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TaktRadii.md)),
                              selected: on,
                              selectedTileColor: dark ? TaktColors.accentSoftDark : TaktColors.accentSoft,
                              leading: TaktUserAvatar(name: m.name, avatarUrl: m.avatarUrl, size: 32),
                              title: Text(
                                m.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                                  color: fg,
                                ),
                              ),
                              trailing: AppIcon(
                                on ? AppIcons.circleCheck : AppIcons.circle,
                                size: 22,
                                color: on
                                    ? (dark ? TaktColors.accentDark : TaktColors.accent)
                                    : (dark ? TaktColors.mutedDark : TaktColors.borderStrong),
                              ),
                              onTap: () {
                                setLocal(() {
                                  if (on) {
                                    selected.remove(m.userId);
                                  } else {
                                    selected.add(m.userId);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: TaktButton(
                                label: 'Отмена',
                                variant: TaktButtonVariant.secondary,
                                expand: true,
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TaktButton(
                                label: 'Готово',
                                expand: true,
                                onPressed: () => Navigator.pop(ctx, selected),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (result != null && mounted) setState(() => _assigneeIds = result);
  }

  @override
  Widget build(BuildContext context) {
    final board = context.watch<BoardCubit>().state;
    final members = board.project?.members ?? const <ProjectMember>[];
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    final selectedMembers = members.where((m) => _assigneeIds.contains(m.userId)).toList();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        appBar: TaktAppBar(
          title: widget.isCreate ? 'Новая задача' : 'Редактирование',
          onClose: () => _leave(false),
          actions: [
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: dark ? TaktColors.accentDark : TaktColors.accent,
                      ),
                    )
                  : Text(widget.isCreate ? 'Создать' : 'Сохранить'),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          children: [
            Text('Название', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted)),
            const SizedBox(height: 6),
            TextField(
              controller: _title,
              autofocus: widget.isCreate,
              maxLines: null,
              minLines: 1,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.35,
                color: dark ? TaktColors.foregroundDark : TaktColors.graphite,
              ),
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Что нужно сделать',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),
            Text('Описание', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted)),
            const SizedBox(height: 6),
            TextField(
              controller: _description,
              minLines: 3,
              maxLines: 6,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: dark ? TaktColors.foregroundDark : TaktColors.graphite,
              ),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Подробности (необязательно)',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),
            TaktSelectField<String>(
              label: 'Столбец',
              value: board.columns.any((c) => c.id == _statusId) ? _statusId : null,
              options: [
                for (final c in board.columns) TaktSelectOption(value: c.id, label: c.name),
              ],
              onChanged: (v) => setState(() => _statusId = v),
            ),
            const SizedBox(height: 14),
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
            const SizedBox(height: 16),
            Text('Исполнители', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted)),
            const SizedBox(height: 8),
            if (members.isEmpty)
              Text('В проекте пока нет участников', style: TextStyle(fontSize: 13, color: muted))
            else ...[
              if (selectedMembers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final m in selectedMembers)
                        InputChip(
                          avatar: TaktUserAvatar(name: m.name, avatarUrl: m.avatarUrl, size: 20),
                          label: Text(
                            m.name,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: dark ? TaktColors.foregroundDark : TaktColors.graphite,
                            ),
                          ),
                          onDeleted: () => setState(() => _assigneeIds.remove(m.userId)),
                          deleteIconColor: muted,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          side: BorderSide(color: dark ? TaktColors.borderDark : TaktColors.border),
                          backgroundColor: dark ? TaktColors.surface2Dark : TaktColors.surface2,
                          labelStyle: TextStyle(
                            color: dark ? TaktColors.foregroundDark : TaktColors.graphite,
                          ),
                        ),
                    ],
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => _pickAssignees(members),
                icon: const AppIcon(AppIcons.invite, size: 18),
                label: Text(
                  selectedMembers.isEmpty ? 'Выбрать исполнителей' : 'Изменить список',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
