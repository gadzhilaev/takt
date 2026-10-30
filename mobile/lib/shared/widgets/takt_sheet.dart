import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'takt_ui.dart';

/// Bottom sheet styled like the rest of Takt (surface, hairline, compact actions).
Future<bool?> showTaktSheet({
  required BuildContext context,
  required String title,
  required Widget body,
  required String confirmLabel,
  String cancelLabel = 'Отмена',
  bool Function()? onConfirm,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return showModalBottomSheet<bool>(
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
      final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: dark ? TaktColors.foregroundDark : TaktColors.graphite,
                  ),
                ),
                const SizedBox(height: 14),
                body,
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TaktButton(
                        label: cancelLabel,
                        variant: TaktButtonVariant.secondary,
                        expand: true,
                        onPressed: () => Navigator.pop(ctx, false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TaktButton(
                        label: confirmLabel,
                        expand: true,
                        onPressed: () {
                          if (onConfirm != null && !onConfirm()) return;
                          Navigator.pop(ctx, true);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<void> showTaktInfoSheet({
  required BuildContext context,
  required String title,
  required Widget body,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return showModalBottomSheet<void>(
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
      final maxH = MediaQuery.sizeOf(ctx).height * 0.72;
      return SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: dark ? TaktColors.foregroundDark : TaktColors.graphite,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(child: SingleChildScrollView(child: body)),
                const SizedBox(height: 16),
                TaktButton(
                  label: 'Закрыть',
                  variant: TaktButtonVariant.secondary,
                  expand: true,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
