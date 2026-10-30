import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../shared/widgets/app_icon.dart';
import '../../core/theme.dart';
import '../../features/projects/data/projects_repository.dart';
import '../models/models.dart';
import '../project_visibility.dart';
import 'user_avatar.dart';

/// Project list with expandable members — mirrors web sidebar.
class ProjectHub extends StatefulWidget {
  const ProjectHub({
    super.key,
    required this.projects,
    required this.onOpenProject,
    required this.onCreateProject,
    this.currentUserId,
    this.onProjectsChanged,
  });

  final List<Project> projects;
  final String? currentUserId;
  final ValueChanged<String> onOpenProject;
  final VoidCallback onCreateProject;
  final VoidCallback? onProjectsChanged;

  @override
  State<ProjectHub> createState() => _ProjectHubState();
}

class _ProjectHubState extends State<ProjectHub> {
  final Set<String> _expanded = {};
  final Map<String, List<LeaveRequest>> _leaveByProject = {};
  bool _loadingLeaves = false;

  @override
  void initState() {
    super.initState();
    _loadLeaveRequests();
  }

  @override
  void didUpdateWidget(covariant ProjectHub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projects != widget.projects) {
      _loadLeaveRequests();
    }
  }

  List<Project> get _visible => taktVisibleProjects(widget.projects);

  Future<void> _loadLeaveRequests() async {
    final uid = widget.currentUserId;
    if (uid == null || uid.isEmpty) return;
    final adminProjects = _visible.where((p) {
      return p.members.any((m) => m.userId == uid && m.role == 'admin');
    }).toList();
    if (adminProjects.isEmpty) return;
    setState(() => _loadingLeaves = true);
    final repo = context.read<ProjectsRepository>();
    final next = <String, List<LeaveRequest>>{};
    for (final p in adminProjects) {
      try {
        next[p.id] = await repo.listLeaveRequests(p.id);
      } catch (_) {
        next[p.id] = const [];
      }
    }
    if (!mounted) return;
    setState(() {
      _leaveByProject
        ..clear()
        ..addAll(next);
      _loadingLeaves = false;
    });
  }

  Future<void> _removeMember(Project project, ProjectMember member) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить участника'),
        content: Text('Убрать ${member.name} из проекта «${project.name}»?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<ProjectsRepository>().removeMember(
            projectId: project.id,
            userId: member.userId,
          );
      widget.onProjectsChanged?.call();
      await _loadLeaveRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${member.name} удалён из проекта')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _requestLeave(Project project) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Покинуть проект'),
        content: Text(
          'Отправить заявку создателю проекта «${project.name}»? '
          'Вас удалят после подтверждения.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Отправить')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<ProjectsRepository>().requestLeave(project.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заявка отправлена создателю проекта')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _decideLeave(Project project, LeaveRequest req, {required bool approve}) async {
    try {
      final repo = context.read<ProjectsRepository>();
      if (approve) {
        await repo.approveLeaveRequest(projectId: project.id, requestId: req.id);
      } else {
        await repo.rejectLeaveRequest(projectId: project.id, requestId: req.id);
      }
      widget.onProjectsChanged?.call();
      await _loadLeaveRequests();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? 'Участник удалён' : 'Заявка отклонена'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final projects = _visible;
    final uid = widget.currentUserId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Мои проекты',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: dark ? TaktColors.mutedDark : TaktColors.muted,
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onCreateProject,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(
                        AppIcons.add,
                        size: 16,
                        color: dark ? TaktColors.accentDark : TaktColors.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Создать',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: dark ? TaktColors.accentDark : TaktColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: projects.isEmpty
              ? Center(
                  child: Text(
                    'Нет доступных проектов',
                    style: TextStyle(color: dark ? TaktColors.mutedDark : TaktColors.muted),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  itemCount: projects.length,
                  itemBuilder: (context, i) {
                    final p = projects[i];
                    final open = _expanded.contains(p.id);
                    final isOwner =
                        uid != null && p.members.any((m) => m.userId == uid && m.role == 'admin');
                    final adminCount = p.members.where((m) => m.role == 'admin').length;
                    final pending = _leaveByProject[p.id] ?? const <LeaveRequest>[];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => widget.onOpenProject(p.id),
                                    child: Text(
                                      p.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.15,
                                        color: dark
                                            ? TaktColors.foregroundDark
                                            : TaktColors.graphite,
                                      ),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    setState(() {
                                      if (open) {
                                        _expanded.remove(p.id);
                                      } else {
                                        _expanded.add(p.id);
                                      }
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${p.members.length}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: dark ? TaktColors.mutedDark : TaktColors.muted,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        AppIcon(
                                          // Closed → down (tap to expand); open → right.
                                          open ? AppIcons.chevronRight : AppIcons.chevronDown,
                                          size: 18,
                                          color: dark ? TaktColors.mutedDark : TaktColors.muted,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (open) ...[
                            Padding(
                              padding: const EdgeInsets.only(left: 12, right: 8, bottom: 8),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: dark ? TaktColors.borderDark : TaktColors.border,
                                    ),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      for (final m in p.members)
                                        _MemberRow(
                                          member: m,
                                          dark: dark,
                                          canRemove: isOwner && m.userId != uid,
                                          canLeave: uid != null &&
                                              m.userId == uid &&
                                              !(m.role == 'admin' && adminCount <= 1),
                                          onRemove: () => _removeMember(p, m),
                                          onLeave: () => _requestLeave(p),
                                        ),
                                      if (isOwner && pending.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          _loadingLeaves ? 'Заявки…' : 'Заявки на выход',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: dark ? TaktColors.mutedDark : TaktColors.muted,
                                          ),
                                        ),
                                        for (final req in pending.where((r) => r.status == 'pending'))
                                          _LeaveRow(
                                            request: req,
                                            dark: dark,
                                            onApprove: () => _decideLeave(p, req, approve: true),
                                            onReject: () => _decideLeave(p, req, approve: false),
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.dark,
    required this.canRemove,
    required this.canLeave,
    required this.onRemove,
    required this.onLeave,
  });

  final ProjectMember member;
  final bool dark;
  final bool canRemove;
  final bool canLeave;
  final VoidCallback onRemove;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          TaktUserAvatar(name: member.name, avatarUrl: member.avatarUrl, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              member.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.2,
                color: dark ? TaktColors.foregroundDark : TaktColors.graphite,
              ),
            ),
          ),
          if (member.role == 'admin')
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                'владелец',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: muted,
                ),
              ),
            ),
          if (canRemove)
            // InkWell — без Material tooltip «Удалить», который всплывал поверх списка.
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: AppIcon(AppIcons.delete, size: 15, color: muted),
              ),
            ),
          if (canLeave)
            TextButton(
              onPressed: onLeave,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Выйти', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class _LeaveRow extends StatelessWidget {
  const _LeaveRow({
    required this.request,
    required this.dark,
    required this.onApprove,
    required this.onReject,
  });

  final LeaveRequest request;
  final bool dark;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          TaktUserAvatar(name: request.userName, avatarUrl: request.avatarUrl, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              request.userName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.2,
                color: dark ? TaktColors.foregroundDark : TaktColors.graphite,
              ),
            ),
          ),
          TextButton(
            onPressed: onReject,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Нет', style: TextStyle(fontSize: 12)),
          ),
          TextButton(
            onPressed: onApprove,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: dark ? TaktColors.accentDark : TaktColors.accent,
            ),
            child: const Text('Одобрить', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
