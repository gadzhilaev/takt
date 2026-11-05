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

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _month = DateTime(i.year, i.month);
    _day = DateTime(i.year, i.month, i.day);
    _hour = i.hour;
    _minute = ((i.minute / 5).round() * 5).clamp(0, 55);
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
                    child: _TimeDropdown(
                      label: 'Часы',
                      value: _hour,
                      items: [for (var h = 0; h < 24; h++) h],
                      labelFor: (h) => h.toString().padLeft(2, '0'),
                      onChanged: (v) => setState(() => _hour = v),
                      fg: fg,
                      muted: muted,
                      border: border,
                      surface2: surface2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TimeDropdown(
                      label: 'Минуты',
                      value: _minute,
                      items: [for (var m = 0; m < 60; m += 5) m],
                      labelFor: (m) => m.toString().padLeft(2, '0'),
                      onChanged: (v) => setState(() => _minute = v),
                      fg: fg,
                      muted: muted,
                      border: border,
                      surface2: surface2,
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

class _TimeDropdown extends StatelessWidget {
  const _TimeDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.labelFor,
    required this.onChanged,
    required this.fg,
    required this.muted,
    required this.border,
    required this.surface2,
  });

  final String label;
  final int value;
  final List<int> items;
  final String Function(int) labelFor;
  final ValueChanged<int> onChanged;
  final Color fg;
  final Color muted;
  final Color border;
  final Color surface2;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: muted)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: surface2,
            borderRadius: BorderRadius.circular(TaktRadii.md),
            border: Border.all(color: border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isExpanded: true,
              borderRadius: BorderRadius.circular(TaktRadii.md),
              icon: Icon(Icons.expand_more, color: muted, size: 20),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: fg),
              dropdownColor: Theme.of(context).brightness == Brightness.dark
                  ? TaktColors.surfaceDark
                  : TaktColors.surface,
              items: [
                for (final item in items)
                  DropdownMenuItem(
                    value: item,
                    child: Text(labelFor(item)),
                  ),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}
