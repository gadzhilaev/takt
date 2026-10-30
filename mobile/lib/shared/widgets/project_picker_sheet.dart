import 'package:flutter/material.dart';

import '../../shared/widgets/app_icon.dart';
import '../../core/theme.dart';
import '../models/models.dart';
import '../project_visibility.dart';
import 'takt_mark.dart';

Future<String?> showProjectPickerSheet({
  required BuildContext context,
  required List<Project> projects,
  required String? currentId,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final visible = taktVisibleProjects(projects);
  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: dark ? TaktColors.surfaceDark : TaktColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.58,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Проект',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: dark ? TaktColors.foregroundDark : TaktColors.graphite,
                  ),
                ),
              ),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  child: Text(
                    'Нет доступных проектов',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: dark ? TaktColors.mutedDark : TaktColors.muted),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
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
                            color: dark ? TaktColors.foregroundDark : TaktColors.graphite,
                          ),
                        ),
                        trailing: selected
                            ? AppIcon(AppIcons.check, size: 18, color: dark ? TaktColors.accentDark : TaktColors.accent,
                              )
                            : null,
                        onTap: () => Navigator.pop(ctx, p.id),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
