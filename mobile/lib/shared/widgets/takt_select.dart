import 'package:flutter/material.dart';

import '../../shared/widgets/app_icon.dart';
import '../../core/theme.dart';

class TaktSelectOption<T> {
  const TaktSelectOption({required this.value, required this.label, this.subtitle});
  final T value;
  final String label;
  final String? subtitle;
}

/// Compact field that opens a bottom sheet picker (replaces DropdownButtonFormField).
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
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: dark ? TaktColors.surfaceDark : TaktColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (ctx) {
      var query = '';
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          final filtered = searchable && query.trim().isNotEmpty
              ? options
                  .where((o) => o.label.toLowerCase().contains(query.trim().toLowerCase()))
                  .toList()
              : options;
          return SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.58),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: dark ? TaktColors.foregroundDark : TaktColors.graphite,
                      ),
                    ),
                  ),
                  if (searchable)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: TextField(
                        autofocus: options.length > 8,
                        onChanged: (v) => setLocal(() => query = v),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Поиск',
                          prefixIcon: const AppIcon(AppIcons.search, size: 20),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                              color: dark ? TaktColors.foregroundDark : TaktColors.graphite,
                            ),
                          ),
                          subtitle: o.subtitle == null
                              ? null
                              : Text(o.subtitle!, style: TextStyle(fontSize: 12, color: dark ? TaktColors.mutedDark : TaktColors.muted)),
                          trailing: isSelected
                              ? AppIcon(AppIcons.check, size: 18, color: dark ? TaktColors.accentDark : TaktColors.accent)
                              : null,
                          onTap: () => Navigator.pop(ctx, o.value),
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
    },
  );
}
