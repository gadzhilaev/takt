import 'package:flutter/material.dart';

import '../../shared/widgets/app_icon.dart';
import '../../core/theme.dart';
import 'takt_sheet.dart';
import 'takt_ui.dart';

class TaktSelectOption<T> {
  const TaktSelectOption({required this.value, required this.label, this.subtitle});
  final T value;
  final String label;
  final String? subtitle;
}

/// Compact field that opens a centered picker window (not a dropdown menu).
class TaktSelectField<T> extends StatelessWidget {
  const TaktSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final T? value;
  final List<TaktSelectOption<T>> options;
  final ValueChanged<T> onChanged;
  final bool enabled;

  String get _display {
    for (final o in options) {
      if (o.value == value) return o.label;
    }
    return 'Выбрать';
  }

  Future<void> _open(BuildContext context) async {
    if (!enabled || options.isEmpty) return;
    final picked = await showTaktSelectSheet<T>(
      context: context,
      title: label,
      options: options,
      selected: value,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = dark ? TaktColors.borderDark : TaktColors.border;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    final fg = dark ? TaktColors.foregroundDark : TaktColors.graphite;
    final surface = dark ? TaktColors.surfaceDark : TaktColors.surface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
        ),
        const SizedBox(height: 6),
        Material(
          color: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TaktRadii.md),
            side: BorderSide(color: border),
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? () => _open(context) : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _display,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: enabled ? fg : muted,
                      ),
                    ),
                  ),
                  AppIcon(AppIcons.chevronDown, size: 22, color: muted),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<T?> showTaktSelectSheet<T>({
  required BuildContext context,
  required String title,
  required List<TaktSelectOption<T>> options,
  T? selected,
  bool searchable = false,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
  final fg = dark ? TaktColors.foregroundDark : TaktColors.graphite;

  return showTaktDialog<T>(
    context: context,
    builder: (ctx) {
      var query = '';
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          final filtered = searchable && query.trim().isNotEmpty
              ? options
                  .where((o) => o.label.toLowerCase().contains(query.trim().toLowerCase()))
                  .toList()
              : options;
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
                              title,
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
                    if (searchable)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: TextField(
                          autofocus: options.length > 8,
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
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final o = filtered[i];
                          final isSelected = o.value == selected;
                          return ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TaktRadii.md)),
                            selected: isSelected,
                            selectedTileColor: dark ? TaktColors.accentSoftDark : TaktColors.accentSoft,
                            title: Text(
                              o.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: fg,
                              ),
                            ),
                            subtitle: o.subtitle == null
                                ? null
                                : Text(o.subtitle!, style: TextStyle(fontSize: 12, color: muted)),
                            trailing: isSelected
                                ? AppIcon(
                                    AppIcons.check,
                                    size: 18,
                                    color: dark ? TaktColors.accentDark : TaktColors.accent,
                                  )
                                : null,
                            onTap: () => Navigator.pop(ctx, o.value),
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
    },
  );
}
