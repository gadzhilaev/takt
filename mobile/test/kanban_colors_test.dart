import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt_mobile/core/kanban_colors.dart';

void main() {
  test('standard presets resolve solid backgrounds', () {
    expect(
      KanbanColors.columnBackground('#607FA4', dark: false),
      const Color(0xFFE4EAF2),
    );
    expect(
      KanbanColors.columnBackground('#347FA4', dark: false),
      const Color(0xFFE0ECF3),
    );
    expect(
      KanbanColors.columnBackground('#9062B8', dark: false),
      const Color(0xFFECE4F4),
    );
    expect(
      KanbanColors.columnBackground('#398A62', dark: false),
      const Color(0xFFE2F0E8),
    );
  });

  test('legacy standard accents alias to current presets', () {
    expect(
      KanbanColors.columnBackground('#7892B2', dark: false),
      const Color(0xFFE4EAF2),
    );
    expect(KanbanColors.columnAccent('#4B8CAF'), const Color(0xFF347FA4));
  });

  test('custom accent does not crash and differs from preset', () {
    final custom = KanbanColors.columnBackground('#FF00AA', dark: false);
    expect(custom, isNot(const Color(0xFFE4EAF2)));
  });

  test('urgency palette unchanged', () {
    final urgent = KanbanColors.urgency('urgent', dark: false);
    expect(urgent.fg, const Color(0xFFC63F3F));
    expect(urgent.bg, const Color(0xFFFCE8E8));
    final high = KanbanColors.urgency('high', dark: false);
    expect(high.fg, const Color(0xFFC47A12));
    final normal = KanbanColors.urgency('medium', dark: false);
    expect(normal.fg, const Color(0xFF326E8B));
  });
}
