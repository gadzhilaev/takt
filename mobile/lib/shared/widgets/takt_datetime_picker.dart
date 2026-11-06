import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'takt_sheet.dart';
import 'takt_ui.dart';

const _monthNames = [
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
  'Август',
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
];

const _weekdays = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];

/// In-app date+time picker (Takt UI — not OS Material/Cupertino chrome).
/// Selection is draft-only until «Готово»; «Отмена» / dismiss discards.
Future<DateTime?> showTaktDateTimePicker({
  required BuildContext context,
  DateTime? initial,
}) async {
  final now = DateTime.now();
  var seed = initial ?? now.add(const Duration(days: 1));
  if (initial == null) {
    seed = DateTime(seed.year, seed.month, seed.day, 18, 0);
  }

  return showTaktDialog<DateTime>(
    context: context,
    builder: (ctx) => _TaktDateTimePickerDialog(initial: seed),
  );
}

class _TaktDateTimePickerDialog extends StatefulWidget {
  const _TaktDateTimePickerDialog({required this.initial});
  final DateTime initial;

  @override
  State<_TaktDateTimePickerDialog> createState() => _TaktDateTimePickerDialogState();
}

class _TaktDateTimePickerDialogState extends State<_TaktDateTimePickerDialog> {
  late DateTime _month;
  late DateTime _day;
  late int _hour;
  late int _minute;
  late final ScrollController _hourScroll;
  late final ScrollController _minuteScroll;

  static const _rowExtent = 36.0;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _month = DateTime(i.year, i.month);
    _day = DateTime(i.year, i.month, i.day);
    _hour = i.hour;
    _minute = ((i.minute / 5).round() * 5).clamp(0, 55);
    _hourScroll = ScrollController(initialScrollOffset: _hour * _rowExtent);
    _minuteScroll = ScrollController(initialScrollOffset: (_minute ~/ 5) * _rowExtent);
  }

  @override
  void dispose() {
    _hourScroll.dispose();
    _minuteScroll.dispose();
    super.dispose();
  }

  List<DateTime?> _daysInGrid() {
    final first = DateTime(_month.year, _month.month, 1);
    final startOffset = (first.weekday + 6) % 7; // Mon=0
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = <DateTime?>[];
    for (var i = 0; i < startOffset; i++) {
      cells.add(null);
    }
    for (var d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(_month.year, _month.month, d));
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? TaktColors.foregroundDark : TaktColors.graphite;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    final accent = dark ? TaktColors.accentDark : TaktColors.accent;
    final surface2 = dark ? TaktColors.surface2Dark : TaktColors.surface2;
    final border = dark ? TaktColors.borderDark : TaktColors.border;
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final cells = _daysInGrid();

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Material(
        color: dark ? TaktColors.surfaceDark : TaktColors.surface,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: dark ? 0.45 : 0.18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TaktRadii.lg),
          side: BorderSide(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Срок выполнения',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: fg),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Предыдущий месяц',
                    onPressed: () => setState(() {
                      _month = DateTime(_month.year, _month.month - 1);
                    }),
                    icon: Icon(Icons.chevron_left, color: muted),
                  ),
                  Expanded(
                    child: Text(
                      '${_monthNames[_month.month - 1]} ${_month.year}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: fg),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Следующий месяц',
                    onPressed: () => setState(() {
                      _month = DateTime(_month.year, _month.month + 1);
                    }),
                    icon: Icon(Icons.chevron_right, color: muted),
                  ),
                ],
              ),
              Row(
                children: [
                  for (final w in _weekdays)
                    Expanded(
                      child: Text(
                        w,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: muted),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              for (var row = 0; row < cells.length / 7; row++)
                Row(
                  children: [
                    for (var col = 0; col < 7; col++)
                      Expanded(
                        child: Builder(
                          builder: (_) {
                            final d = cells[row * 7 + col];
                            if (d == null) {
                              return const SizedBox(height: 36);
                            }
                            final selected = d.year == _day.year &&
                                d.month == _day.month &&
                                d.day == _day.day;
                            final isToday = d == todayKey;
                            return Padding(
                              padding: const EdgeInsets.all(2),
                              child: Material(
                                color: selected ? accent : Colors.transparent,
                                shape: CircleBorder(
                                  side: isToday && !selected
                                      ? BorderSide(color: accent)
                                      : BorderSide.none,
                                ),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => setState(() => _day = d),
                                  child: SizedBox(
                                    height: 36,
                                    child: Center(
                                      child: Text(
                                        '${d.day}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                          color: selected ? Colors.white : fg,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TimeList(
                      label: 'Часы',
                      controller: _hourScroll,
                      itemCount: 24,
                      selectedIndex: _hour,
                      labelFor: (i) => i.toString().padLeft(2, '0'),
                      onSelect: (i) => setState(() => _hour = i),
                      fg: fg,
                      muted: muted,
                      accent: accent,
                      surface2: surface2,
                      border: border,
                      rowExtent: _rowExtent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TimeList(
                      label: 'Минуты',
                      controller: _minuteScroll,
                      itemCount: 12,
                      selectedIndex: _minute ~/ 5,
                      labelFor: (i) => (i * 5).toString().padLeft(2, '0'),
                      onSelect: (i) => setState(() => _minute = i * 5),
                      fg: fg,
                      muted: muted,
                      accent: accent,
                      surface2: surface2,
                      border: border,
                      rowExtent: _rowExtent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TaktButton(
                      label: 'Отмена',
                      variant: TaktButtonVariant.secondary,
                      expand: true,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TaktButton(
                      label: 'Готово',
                      expand: true,
                      onPressed: () {
                        Navigator.pop(
                          context,
                          DateTime(_day.year, _day.month, _day.day, _hour, _minute),
                        );
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
  }
}

class _TimeList extends StatelessWidget {
  const _TimeList({
    required this.label,
    required this.controller,
    required this.itemCount,
    required this.selectedIndex,
    required this.labelFor,
    required this.onSelect,
    required this.fg,
    required this.muted,
    required this.accent,
    required this.surface2,
    required this.border,
    required this.rowExtent,
  });

  final String label;
  final ScrollController controller;
  final int itemCount;
  final int selectedIndex;
  final String Function(int) labelFor;
  final ValueChanged<int> onSelect;
  final Color fg;
  final Color muted;
  final Color accent;
  final Color surface2;
  final Color border;
  final double rowExtent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: muted)),
        const SizedBox(height: 6),
        Container(
          height: rowExtent * 4,
          decoration: BoxDecoration(
            color: surface2,
            borderRadius: BorderRadius.circular(TaktRadii.md),
            border: Border.all(color: border),
          ),
          child: ListView.builder(
            controller: controller,
            itemExtent: rowExtent,
            itemCount: itemCount,
            itemBuilder: (context, index) {
              final selected = index == selectedIndex;
              return InkWell(
                onTap: () => onSelect(index),
                child: Center(
                  child: Text(
                    labelFor(index),
                    style: TextStyle(
                      fontSize: selected ? 17 : 15,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? accent : fg,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
