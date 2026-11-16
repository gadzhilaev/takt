import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/takt_select.dart';
import '../data/rhythm_options.dart';

/// Блок «Ежедневный чек-ин» в настройках проекта (для администратора).
class RhythmSettingsCard extends StatelessWidget {
  const RhythmSettingsCard({super.key, required this.value, required this.onChanged});

  final RhythmSettings value;
  final ValueChanged<RhythmSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? TaktColors.foregroundDark : TaktColors.graphite;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    final accent = dark ? TaktColors.accentDark : TaktColors.accent;
    final fieldBg = dark ? TaktColors.surface2Dark : Colors.white;
    final border = dark ? TaktColors.borderStrongDark : TaktColors.borderStrong;

    return Material(
      color: fieldBg,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            value: value.enabled,
            onChanged: (v) => onChanged(value.copyWith(enabled: v ?? false)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            activeColor: accent,
            title: Text(
              'Ежедневный чек-ин',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg),
            ),
            subtitle: Text(
              'Каждый отвечает по своим задачам одним нажатием — доска обновляется сама.',
              style: TextStyle(fontSize: 12, height: 1.3, color: muted),
            ),
          ),
          if (value.enabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TaktSelectField<String>(
                          label: 'Время',
                          value: value.time,
                          options: [
                            for (final t in rhythmTimes(value.time))
                              TaktSelectOption(value: t, label: t),
                          ],
                          onChanged: (t) => onChanged(value.copyWith(time: t)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TaktSelectField<String>(
                          label: 'Часовой пояс',
                          value: value.timezone,
                          options: [
                            for (final (v, l) in rhythmTimezoneOptions(value.timezone))
                              TaktSelectOption(value: v, label: l),
                          ],
                          onChanged: (tz) => onChanged(value.copyWith(timezone: tz)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Дни', style: TextStyle(fontSize: 13, color: muted)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final (d, label) in rhythmWeekdays)
                        _DayChip(
                          label: label,
                          selected: value.days.contains(d),
                          accent: accent,
                          border: border,
                          idle: muted,
                          onTap: () =>
                              onChanged(value.copyWith(days: toggleRhythmDay(value.days, d))),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.border,
    required this.idle,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final Color border;
  final Color idle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? accent : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TaktRadii.md),
          side: BorderSide(color: selected ? accent : border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(TaktRadii.md),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 36,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : idle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
