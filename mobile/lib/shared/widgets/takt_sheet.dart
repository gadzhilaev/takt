import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'takt_ui.dart';

/// Центрированное модальное окно (не bottom sheet / не «выпадающий список»).
Future<T?> showTaktDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext dialogContext) builder,
  bool barrierDismissible = true,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return showDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black.withValues(alpha: dark ? 0.55 : 0.35),
    builder: builder,
  );
}

Widget _taktDialogShell({
  required BuildContext context,
  required String title,
  required Widget body,
  required List<Widget> actions,
  double maxWidth = 400,
  double? maxHeightFactor,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final surface = dark ? TaktColors.surfaceDark : TaktColors.surface;
  final border = dark ? TaktColors.borderDark : TaktColors.border;
  final fg = dark ? TaktColors.foregroundDark : TaktColors.graphite;
  final size = MediaQuery.sizeOf(context);
  final inset = MediaQuery.viewInsetsOf(context);
  final maxH = size.height * (maxHeightFactor ?? 0.78);

  return Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    insetPadding: EdgeInsets.fromLTRB(20, 24, 20, 24 + inset.bottom),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxH),
      child: Material(
        color: surface,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: dark ? 0.45 : 0.18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TaktRadii.lg),
          side: BorderSide(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.25,
                  color: fg,
                ),
              ),
              const SizedBox(height: 14),
              Flexible(child: body),
              const SizedBox(height: 16),
              ...actions,
            ],
          ),
        ),
      ),
    ),
  );
}

/// Окно подтверждения / формы (раньше было bottom sheet).
Future<bool?> showTaktSheet({
  required BuildContext context,
  required String title,
  required Widget body,
  required String confirmLabel,
  String cancelLabel = 'Отмена',
  bool Function()? onConfirm,
}) {
  return showTaktDialog<bool>(
    context: context,
    builder: (ctx) {
      return _taktDialogShell(
        context: ctx,
        title: title,
        body: SingleChildScrollView(child: body),
        actions: [
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
      );
    },
  );
}

Future<void> showTaktInfoSheet({
  required BuildContext context,
  required String title,
  required Widget body,
}) {
  return showTaktDialog<void>(
    context: context,
    builder: (ctx) {
      return _taktDialogShell(
        context: ctx,
        title: title,
        body: SingleChildScrollView(child: body),
        actions: [
          TaktButton(
            label: 'Закрыть',
            variant: TaktButtonVariant.secondary,
            expand: true,
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      );
    },
  );
}
