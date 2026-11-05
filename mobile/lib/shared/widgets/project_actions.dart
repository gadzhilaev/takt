import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/avatar_cache.dart';
import '../../core/theme.dart';
import '../../features/board/cubit/board_cubit.dart';
import '../../features/projects/data/projects_repository.dart';
import '../models/models.dart';
import 'app_icon.dart';
import 'takt_sheet.dart';
import 'user_avatar.dart';

bool isProjectOwner(Project project, String? userId) {
  if (userId == null) return false;
  return project.members.any((m) => m.userId == userId && m.role == 'admin');
}

/// Меню проекта: Участники / Переименовать / Удалить (как на главной).
Future<void> showProjectActionsMenu(
  BuildContext context, {
  required Project project,
  String? currentUserId,
  VoidCallback? onChanged,
}) async {
  final owner = isProjectOwner(project, currentUserId);
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
      final dark = Theme.of(ctx).brightness == Brightness.dark;
      final fg = dark ? TaktColors.foregroundDark : TaktColors.graphite;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionRow(
                icon: AppIcons.profile,
                label: 'Участники',
                color: fg,
                trailing: ProjectMemberAvatarStack(members: project.members),
                onTap: () => Navigator.pop(ctx, 'members'),
              ),
              if (owner)
                _ActionRow(
                  icon: AppIcons.edit,
                  label: 'Настройки',
                  color: fg,
                  onTap: () => Navigator.pop(ctx, 'rename'),
                ),
              _ActionRow(
                icon: AppIcons.delete,
                label: 'Удалить',
                color: TaktColors.urgent,
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (!context.mounted || action == null) return;
  await Future<void>.delayed(const Duration(milliseconds: 250));
  if (!context.mounted) return;

  if (action == 'members') {
    await context.push('/projects/${project.id}/members');
    onChanged?.call();
    return;
  }
  if (action == 'rename') {
    await renameProjectFlow(context, project: project, onChanged: onChanged);
    return;
  }
  if (action == 'delete') {
    if (owner) {
      await deleteProjectFlow(context, project: project, onChanged: onChanged);
    } else {
      await leaveProjectFlow(context, project: project, onChanged: onChanged);
    }
  }
}

Future<void> renameProjectFlow(
  BuildContext context, {
  required Project project,
  VoidCallback? onChanged,
}) async {
  final controller = TextEditingController(text: project.name);
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: controller.text.length,
  );
  var autoUrgency = project.autoUrgencyFromDue;
  final ok = await showModalBottomSheet<bool>(
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
      final fieldBg = dark ? TaktColors.surface2Dark : Colors.white;
      final inset = MediaQuery.viewInsetsOf(ctx).bottom;

      void submit() {
        if (controller.text.trim().isEmpty) return;
        Navigator.pop(ctx, true);
      }

      return StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: inset),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Отмена',
                          onPressed: () => Navigator.pop(ctx, false),
                          icon: AppIcon(AppIcons.close, color: muted),
                        ),
                        Expanded(
                          child: Text(
                            'Настройки проекта',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                              color: fg,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Сохранить',
                          onPressed: submit,
                          icon: AppIcon(AppIcons.check, color: accent),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => submit(),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: fg,
                      ),
                      cursorColor: accent,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: fieldBg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: accent.withValues(alpha: 0.45)),
                        ),
                      ),
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(120),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: Material(
                      color: fieldBg,
                      borderRadius: BorderRadius.circular(10),
                      child: CheckboxListTile(
                        value: autoUrgency,
                        onChanged: (v) => setModalState(() => autoUrgency = v ?? true),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        activeColor: accent,
                        title: Text(
                          'Автосрочность по дедлайну',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg),
                        ),
                        subtitle: Text(
                          '≤35% — Важно, ≤10% или просрочка — Срочно. Только повышает.',
                          style: TextStyle(fontSize: 12, height: 1.3, color: muted),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
  final name = controller.text.trim();
  controller.dispose();
  if (ok != true || !context.mounted) return;
  if (name.isEmpty) return;
  final unchangedName = name == project.name;
  final unchangedFlag = autoUrgency == project.autoUrgencyFromDue;
  if (unchangedName && unchangedFlag) return;
  final repo = context.read<ProjectsRepository>();
  final board = context.read<BoardCubit>();
  final messenger = ScaffoldMessenger.of(context);
  try {
    await repo.renameProject(
      projectId: project.id,
      name: name,
      autoUrgencyFromDue: autoUrgency,
    );
    await board.refreshProjects(forceLoading: true);
    onChanged?.call();
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('$e')));
  }
}

Future<void> deleteProjectFlow(
  BuildContext context, {
  required Project project,
  VoidCallback? onChanged,
}) async {
  if (project.isDefault) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Нельзя удалить проект «Общее»')),
    );
    return;
  }
  final ok = await showTaktSheet(
    context: context,
    title: 'Удалить проект?',
    confirmLabel: 'Удалить',
    body: Text(
      'Если удалите проект «${project.name}», все задачи, столбцы и участники '
      'будут удалены безвозвратно.',
    ),
  );
  if (ok != true || !context.mounted) return;
  final repo = context.read<ProjectsRepository>();
  final board = context.read<BoardCubit>();
  final messenger = ScaffoldMessenger.of(context);
  try {
    await repo.deleteProject(project.id);
    if (board.state.project?.id == project.id) {
      board.clearProject();
      if (context.mounted) context.go('/projects');
    }
    onChanged?.call();
    messenger.showSnackBar(
      SnackBar(content: Text('Проект «${project.name}» удалён')),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('$e')));
  }
}

Future<void> leaveProjectFlow(
  BuildContext context, {
  required Project project,
  VoidCallback? onChanged,
}) async {
  final ok = await showTaktSheet(
    context: context,
    title: 'Покинуть проект?',
    confirmLabel: 'Выйти',
    body: Text(
      'Вы выйдете из проекта «${project.name}» и больше не будете видеть его задачи и доску.',
    ),
  );
  if (ok != true || !context.mounted) return;
  final repo = context.read<ProjectsRepository>();
  final board = context.read<BoardCubit>();
  final messenger = ScaffoldMessenger.of(context);
  try {
    await repo.leaveProject(project.id);
    if (board.state.project?.id == project.id) {
      board.clearProject();
      if (context.mounted) context.go('/projects');
    }
    onChanged?.call();
    messenger.showSnackBar(
      const SnackBar(content: Text('Вы вышли из проекта')),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('$e')));
  }
}

class ProjectMemberAvatarStack extends StatelessWidget {
  const ProjectMemberAvatarStack({super.key, required this.members});

  final List<ProjectMember> members;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final moreBg = dark ? const Color(0xFF5A6570) : const Color(0xFFD5DBE2);
    final moreFg = dark ? TaktColors.foregroundDark : TaktColors.graphite;
    const maxShown = 3;
    final shown = members.take(maxShown).toList();
    final extra = members.length - shown.length;
    const size = 28.0;
    const overlap = 10.0;
    final count = shown.length + (extra > 0 ? 1 : 0);

    return SizedBox(
      width: size + (count - 1) * (size - overlap),
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * (size - overlap),
              top: 0,
              child: SizedBox(
                width: size,
                height: size,
                child: ClipOval(
                  child: _BorderlessAvatar(
                    name: shown[i].name,
                    avatarUrl: shown[i].avatarUrl,
                    size: size,
                  ),
                ),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: shown.length * (size - overlap),
              top: 0,
              child: SizedBox(
                width: size,
                height: size,
                child: ClipOval(
                  child: ColoredBox(
                    color: moreBg,
                    child: Center(
                      child: Text(
                        '+$extra',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          height: 1,
                          color: moreFg,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.trailing,
  });

  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        child: Row(
          children: [
            AppIcon(icon, size: 22, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _BorderlessAvatar extends StatelessWidget {
  const _BorderlessAvatar({
    required this.name,
    required this.avatarUrl,
    required this.size,
  });

  final String name;
  final String? avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = resolveAvatarUrl(avatarUrl);
    final bg = taktAvatarColor(name);
    final fs = (size * 0.42).clamp(9.0, 16.0);
    final hit = url == null ? null : AvatarCache.instance.lookupSync(url);

    return ColoredBox(
      color: bg,
      child: hit != null
          ? Image.file(
              hit,
              fit: BoxFit.cover,
              width: size,
              height: size,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => Center(
                child: Text(
                  taktInitials(name),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fs,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                taktInitials(name),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fs,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ),
    );
  }
}
