import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/takt_select.dart';
import '../../rhythm/data/rhythm_options.dart';

/// «Сводка руководителю» в настройках проекта (для администратора).
class DigestSettingsCard extends StatelessWidget {
  const DigestSettingsCard({super.key, required this.value, required this.onChanged});

  final DigestSchedule value;
  final ValueChanged<DigestSchedule> onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? TaktColors.foregroundDark : TaktColors.graphite;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    final accent = dark ? TaktColors.accentDark : TaktColors.accent;
    final fieldBg = dark ? TaktColors.surface2Dark : Colors.white;

    Widget box(String label, bool v, ValueChanged<bool> on) => CheckboxListTile(
          value: v,
          onChanged: (x) => on(x ?? false),
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          activeColor: accent,
          title: Text(label, style: TextStyle(fontSize: 14, color: fg)),
        );

    return Material(
      color: fieldBg,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Сводка руководителю',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Что сделано, что застряло и где узкое место — администраторам и подписчикам.',
                    style: TextStyle(fontSize: 12, height: 1.3, color: muted),
                  ),
                ],
              ),
            ),
            box('По пятницам', value.weekly, (v) => onChanged(value.copyWith(weekly: v))),
            box('Каждый день', value.daily, (v) => onChanged(value.copyWith(daily: v))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TaktSelectField<String>(
                label: 'Время',
                value: value.time,
                options: [
                  for (final t in rhythmTimes(value.time)) TaktSelectOption(value: t, label: t),
                ],
                onChanged: (t) => onChanged(value.copyWith(time: t)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
