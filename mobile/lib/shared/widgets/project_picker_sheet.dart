import 'package:flutter/material.dart';

import '../../shared/widgets/app_icon.dart';
import '../../core/theme.dart';
import '../models/models.dart';
import '../project_visibility.dart';
import 'takt_mark.dart';
import 'takt_sheet.dart';
import 'takt_ui.dart';

Future<String?> showProjectPickerSheet({
  required BuildContext context,
  required List<Project> projects,
  required String? currentId,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final visible = taktVisibleProjects(projects);
  final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
  final fg = dark ? TaktColors.foregroundDark : TaktColors.graphite;

  return showTaktDialog<String>(
    context: context,
    builder: (ctx) {
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
                          'Проект',
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
                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                    child: Text(
                      'Нет доступных проектов',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      itemCount: visible.length,
                      itemBuilder: (context, i) {
                        final p = visible[i];
                        final selected = p.id == currentId;
                        return ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TaktRadii.md)),
                          selected: selected,
                          selectedTileColor: dark ? TaktColors.accentSoftDark : TaktColors.accentSoft,
                          leading: const TaktMark(size: 22),
                          title: Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                              color: fg,
                            ),
                          ),
                          trailing: selected
                              ? AppIcon(
                                  AppIcons.check,
                                  size: 18,
                                  color: dark ? TaktColors.accentDark : TaktColors.accent,
                                )
                              : null,
                          onTap: () => Navigator.pop(ctx, p.id),
                        );
                      },
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: TaktButton(
                    label: 'Отмена',
                    variant: TaktButtonVariant.secondary,
                    expand: true,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
