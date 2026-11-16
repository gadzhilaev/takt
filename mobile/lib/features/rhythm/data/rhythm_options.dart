/// Варианты для настроек ритма (как на web).
const rhythmWeekdays = <(int, String)>[
  (1, 'Пн'),
  (2, 'Вт'),
  (3, 'Ср'),
  (4, 'Чт'),
  (5, 'Пт'),
  (6, 'Сб'),
  (7, 'Вс'),
];

const rhythmTimezones = <(String, String)>[
  ('Europe/Kaliningrad', 'Калининград (МСК−1)'),
  ('Europe/Moscow', 'Москва (МСК)'),
  ('Europe/Samara', 'Самара (МСК+1)'),
  ('Asia/Yekaterinburg', 'Екатеринбург (МСК+2)'),
  ('Asia/Omsk', 'Омск (МСК+3)'),
  ('Asia/Novosibirsk', 'Новосибирск (МСК+4)'),
  ('Asia/Krasnoyarsk', 'Красноярск (МСК+4)'),
  ('Asia/Irkutsk', 'Иркутск (МСК+5)'),
  ('Asia/Yakutsk', 'Якутск (МСК+6)'),
  ('Asia/Vladivostok', 'Владивосток (МСК+7)'),
  ('Asia/Magadan', 'Магадан (МСК+8)'),
  ('Asia/Kamchatka', 'Камчатка (МСК+9)'),
];

/// 06:00–21:45 с шагом 15 минут (+ текущее значение, если оно вне сетки).
List<String> rhythmTimes([String? current]) {
  final out = <String>[
    for (var h = 6; h <= 21; h++)
      for (final m in const [0, 15, 30, 45])
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}',
  ];
  if (current != null && !out.contains(current)) {
    out
      ..add(current)
      ..sort();
  }
  return out;
}

List<(String, String)> rhythmTimezoneOptions([String? current]) {
  if (current == null || rhythmTimezones.any((t) => t.$1 == current)) return rhythmTimezones;
  return [...rhythmTimezones, (current, current)];
}

/// Нельзя снять последний день.
List<int> toggleRhythmDay(List<int> days, int day) {
  final set = {...days};
  if (set.contains(day)) {
    if (set.length == 1) return set.toList();
    set.remove(day);
  } else {
    set.add(day);
  }
  return set.toList()..sort();
}
