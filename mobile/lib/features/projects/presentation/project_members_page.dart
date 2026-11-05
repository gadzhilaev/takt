import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/takt_app_bar.dart';
import '../../../shared/widgets/takt_sheet.dart';
import '../../../shared/widgets/takt_ui.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../board/cubit/board_cubit.dart';
import '../data/projects_repository.dart';

class ProjectMembersPage extends StatefulWidget {
  const ProjectMembersPage({super.key, required this.projectId});

  final String projectId;

  @override
  State<ProjectMembersPage> createState() => _ProjectMembersPageState();
}

class _ProjectMembersPageState extends State<ProjectMembersPage> {
  Project? _project;
  List<LeaveRequest> _pending = const [];
  String? _error;

  static const _hPad = 16.0;

  @override
  void initState() {
    super.initState();
    Project? cached;
    for (final p in context.read<BoardCubit>().state.projects) {
      if (p.id == widget.projectId) {
        cached = p;
        break;
      }
    }
    _project = cached;
    _load(silent: cached != null);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && _project == null) {
      setState(() => _error = null);
    }
    final repo = context.read<ProjectsRepository>();
    final uid = context.read<BoardCubit>().currentUserId;
    try {
      final project = await repo.getProject(widget.projectId);
      List<LeaveRequest> pending = const [];
      final isOwner =
          uid != null && project.members.any((m) => m.userId == uid && m.role == 'admin');
      if (isOwner) {
        try {
          pending = (await repo.listLeaveRequests(project.id))
              .where((r) => r.status == 'pending')
              .toList();
        } catch (_) {
          pending = const [];
        }
      }
      if (!mounted) return;
      setState(() {
        _project = project;
        _pending = pending;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_project == null) {
        setState(() => _error = e.toString());
      }
    }
  }

  bool get _isOwner {
    final uid = context.read<BoardCubit>().currentUserId;
    final p = _project;
    if (uid == null || p == null) return false;
    return p.members.any((m) => m.userId == uid && m.role == 'admin');
  }

  Future<void> _invite() async {
    final project = _project;
    if (project == null || !_isOwner) return;

    final emailCtrl = TextEditingController();
    var linkBusy = false;
    var hint = '';
    var emailBusy = false;

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? TaktColors.surfaceDark
          : const Color(0xFFF2F4F6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final dark = Theme.of(ctx).brightness == Brightness.dark;
        final fg = dark ? TaktColors.foregroundDark : TaktColors.graphite;
        final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
        final accent = dark ? TaktColors.accentDark : TaktColors.accent;
        final inset = MediaQuery.viewInsetsOf(ctx).bottom;

        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> copyLink() async {
              setLocal(() {
                linkBusy = true;
                hint = '';
              });
              try {
                final token =
                    await context.read<ProjectsRepository>().createOrGetInviteLink(project.id);
                if (token == null || token.isEmpty) {
                  setLocal(() => hint = 'Не удалось создать ссылку');
                  return;
                }
                final link = 'https://taktapp.ru/invite/$token';
                await Clipboard.setData(ClipboardData(text: link));
                setLocal(() => hint = 'Ссылка скопирована');
              } catch (e) {
                setLocal(() => hint = '$e');
              } finally {
                setLocal(() => linkBusy = false);
              }
            }

            Future<void> sendEmail() async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty) return;
              setLocal(() {
                emailBusy = true;
                hint = '';
              });
              try {
                await context.read<ProjectsRepository>().inviteMember(
                      projectId: project.id,
                      email: email,
                    );
                emailCtrl.clear();
                setLocal(() => hint = 'Приглашение создано');
              } catch (e) {
                setLocal(() => hint = '$e');
              } finally {
                setLocal(() => emailBusy = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: inset),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Пригласить участника',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: fg,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TaktTextField(
                        controller: emailCtrl,
                        label: 'Email сотрудника',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      TaktButton(
                        label: emailBusy ? 'Отправка…' : 'Пригласить',
                        expand: true,
                        onPressed: emailBusy ? null : sendEmail,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          children: [
                            Expanded(child: Divider(color: muted.withValues(alpha: 0.35))),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                'или',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: muted,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: muted.withValues(alpha: 0.35))),
                          ],
                        ),
                      ),
                      TaktButton(
                        label: linkBusy ? 'Готовим ссылку…' : 'Скопировать ссылку для вступления',
                        variant: TaktButtonVariant.secondary,
                        expand: true,
                        onPressed: linkBusy ? null : copyLink,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Отправьте ссылку в мессенджер — после входа человек попадёт в проект.',
                        style: TextStyle(fontSize: 12, color: muted, height: 1.35),
                      ),
                      if (hint.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          hint,
                          style: TextStyle(
                            fontSize: 12,
                            color: hint.contains('Не удалось') || hint.startsWith('Dio')
                                ? TaktColors.urgent
                                : accent,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    emailCtrl.dispose();
  }

  Future<void> _memberMenu(ProjectMember member) async {
    final project = _project;
    final uid = context.read<BoardCubit>().currentUserId;
    if (project == null || uid == null) return;
    if (member.userId == uid || !_isOwner) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? TaktColors.surfaceDark
          : const Color(0xFFF2F4F6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.pop(ctx, 'remove'),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                child: Row(
                  children: [
                    AppIcon(AppIcons.delete, size: 22, color: TaktColors.urgent),
                    SizedBox(width: 14),
                    Text(
                      'Удалить из проекта',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: TaktColors.urgent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    if (action != 'remove' || !mounted) return;

    final ok = await showTaktSheet(
      context: context,
      title: 'Удалить участника',
      confirmLabel: 'Удалить',
      body: Text('Убрать ${member.name} из проекта «${project.name}»?'),
    );
    if (ok != true || !mounted) return;
    final repo = context.read<ProjectsRepository>();
    final board = context.read<BoardCubit>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.removeMember(projectId: project.id, userId: member.userId);
      await board.refreshProjects(forceLoading: true);
      await _load(silent: true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _decideLeave(LeaveRequest req, {required bool approve}) async {
    final project = _project;
    if (project == null) return;
    final repo = context.read<ProjectsRepository>();
    final board = context.read<BoardCubit>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (approve) {
        await repo.approveLeaveRequest(projectId: project.id, requestId: req.id);
      } else {
        await repo.rejectLeaveRequest(projectId: project.id, requestId: req.id);
      }
      await board.refreshProjects(forceLoading: true);
      await _load(silent: true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final project = _project;
    final count = project?.members.length ?? 0;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    final fg = dark ? TaktColors.foregroundDark : TaktColors.graphite;
    final accent = dark ? TaktColors.accentDark : TaktColors.accent;
    final uid = context.read<BoardCubit>().currentUserId;

    return Scaffold(
      appBar: TaktAppBar(
        title: project == null ? 'Участники' : 'Проект «${project.name}»',
        centerTitle: true,
        showMark: false,
        leading: IconButton(
          tooltip: 'Назад',
          onPressed: () => context.pop(),
          icon: AppIcon(AppIcons.chevronLeft, color: fg),
        ),
        // Баланс к leading, чтобы заголовок был по центру экрана.
        actions: const [SizedBox(width: 48)],
      ),
      body: _error != null && project == null
          ? Center(child: Text(_error!))
          : project == null
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(_hPad, 12, _hPad, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              count == 1 ? '1 участник' : '$count участников',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: muted,
                              ),
                            ),
                          ),
                          if (_isOwner)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _invite,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                child: Text(
                                  'Добавить',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: accent,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(_hPad, 0, 4, 24),
                        itemCount: project.members.length +
                            (_isOwner && _pending.isNotEmpty ? 1 + _pending.length : 0),
                        itemBuilder: (context, i) {
                          if (i < project.members.length) {
                            final m = project.members[i];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  TaktUserAvatar(
                                    name: m.name,
                                    avatarUrl: m.avatarUrl,
                                    size: 32,
                                    fontSize: 12,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          m.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: fg,
                                          ),
                                        ),
                                        if (m.role == 'admin')
                                          Text(
                                            'Владелец',
                                            style: TextStyle(fontSize: 12, color: muted),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (_isOwner && m.userId != uid)
                                    IconButton(
                                      tooltip: 'Ещё',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _memberMenu(m),
                                      icon: AppIcon(AppIcons.more, size: 18, color: muted),
                                    ),
                                ],
                              ),
                            );
                          }
                          final pendingIndex = i - project.members.length;
                          if (pendingIndex == 0) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(0, 16, 12, 8),
                              child: Text(
                                'Заявки на выход',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: muted,
                                ),
                              ),
                            );
                          }
                          final req = _pending[pendingIndex - 1];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                TaktUserAvatar(
                                  name: req.userName,
                                  avatarUrl: req.avatarUrl,
                                  size: 32,
                                  fontSize: 12,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    req.userName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: fg,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _decideLeave(req, approve: false),
                                  child: const Text('Нет'),
                                ),
                                TextButton(
                                  onPressed: () => _decideLeave(req, approve: true),
                                  child: Text('Удалить', style: TextStyle(color: accent)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
