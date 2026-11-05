import '../../core/kanban_colors.dart';

/// Next fitting board accent not already used by columns.
String suggestUnusedColumnColor(Iterable<String?> used) =>
    KanbanColors.suggestUnusedAccent(used);
