import 'package:flutter/material.dart';

import '../../core/kanban_colors.dart';
import '../../core/theme.dart';

class UrgencyBadge extends StatelessWidget {
  const UrgencyBadge({super.key, required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final u = KanbanColors.urgency(priority, dark: dark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1),
      decoration: BoxDecoration(
        color: u.bg,
        borderRadius: BorderRadius.circular(TaktRadii.sm),
      ),
      child: Text(
        u.label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          height: 1.2,
          letterSpacing: 0.05,
          color: u.fg,
        ),
      ),
    );
  }
}
