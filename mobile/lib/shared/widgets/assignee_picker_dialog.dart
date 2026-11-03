import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../models/models.dart';
import 'app_icon.dart';
import 'takt_sheet.dart';
import 'takt_ui.dart';
import 'user_avatar.dart';

/// Multi-select dialog for project members (исполнители).
Future<Set<String>?> showAssigneePickerDialog({
  required BuildContext context,
  required List<ProjectMember> members,
  required Set<String> initiallySelected,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
  final fg = dark ? TaktColors.foregroundDark : TaktColors.graphite;
  final accent = dark ? TaktColors.accentDark : TaktColors.accent;
  final soft = dark ? TaktColors.accentSoftDark : TaktColors.accentSoft;
  final border = dark ? TaktColors.borderDark : TaktColors.border;
  final surface2 = dark ? TaktColors.surface2Dark : TaktColors.surface2;

  return showTaktDialog<Set<String>>(
    context: context,
    builder: (ctx) {
      var selected = Set<String>.from(initiallySelected);
      var query = '';
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          final filtered = members.where((m) {
            if (query.trim().isEmpty) return true;
            return m.name.toLowerCase().contains(query.trim().toLowerCase());
          }).toList();
          final count = selected.length;

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
                  side: BorderSide(color: border),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Исполнители',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.25,
                                    color: fg,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  count == 0
                                      ? 'Никого не выбрано'
                                      : (count == 1 ? 'Выбран 1 человек' : 'Выбрано: $count'),
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: muted),
                                ),
                              ],
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
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: TextField(
                          onChanged: (v) => setLocal(() => query = v),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Поиск по имени',
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 10, right: 6),
                              child: AppIcon(AppIcons.search, size: 18, color: muted),
                            ),
                            prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            filled: true,
                            fillColor: surface2,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 4),
                    Flexible(
                      child: filtered.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                              child: Text(
                                'Никого не найдено',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14, color: muted),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final m = filtered[i];
                                final on = selected.contains(m.userId);
                                return _AssigneeRow(
                                  member: m,
                                  selected: on,
                                  dark: dark,
                                  fg: fg,
                                  muted: muted,
                                  accent: accent,
                                  soft: soft,
                                  border: border,
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
                    Divider(height: 1, thickness: 1, color: border),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
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
                              label: count > 0 ? 'Готово · $count' : 'Готово',
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
}

class _AssigneeRow extends StatelessWidget {
  const _AssigneeRow({
    required this.member,
    required this.selected,
    required this.dark,
    required this.fg,
    required this.muted,
    required this.accent,
    required this.soft,
    required this.border,
    required this.onTap,
  });

  final ProjectMember member;
  final bool selected;
  final bool dark;
  final Color fg;
  final Color muted;
  final Color accent;
  final Color soft;
  final Color border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(TaktRadii.md);
    return Material(
      color: selected ? soft : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: selected ? accent.withValues(alpha: dark ? 0.45 : 0.35) : border.withValues(alpha: 0.65),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              TaktUserAvatar(name: member.name, avatarUrl: member.avatarUrl, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    letterSpacing: -0.1,
                    color: fg,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _CheckMark(selected: selected, accent: accent, muted: muted, dark: dark),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckMark extends StatelessWidget {
  const _CheckMark({
    required this.selected,
    required this.accent,
    required this.muted,
    required this.dark,
  });

  final bool selected;
  final Color accent;
  final Color muted;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: accent,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: AppIcon(
          AppIcons.check,
          size: 13,
          color: dark ? TaktColors.graphite : Colors.white,
        ),
      );
    }
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: muted.withValues(alpha: 0.55), width: 1.5),
      ),
    );
  }
}
