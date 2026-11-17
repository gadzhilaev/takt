import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Первый запуск: онбординг «Ритм / Сводка / Виджет» показывается один раз.
class OnboardingController {
  static const seenKey = 'takt_onboarding_seen_v1';
  static const widgetTipDismissedKey = 'takt_widget_tip_dismissed_v1';
  static const checkinAnsweredKey = 'takt_checkin_answered_once_v1';

  final ValueNotifier<bool> seenListenable = ValueNotifier(false);
  final ValueNotifier<bool> widgetTipDismissedListenable = ValueNotifier(false);
  final ValueNotifier<bool> checkinAnsweredListenable = ValueNotifier(false);

  bool get seen => seenListenable.value;
  bool get widgetTipDismissed => widgetTipDismissedListenable.value;
  bool get checkinAnswered => checkinAnsweredListenable.value;

  /// Показать подсказку виджета после первого ответа на чек-ин.
  bool get shouldShowWidgetTip => checkinAnswered && !widgetTipDismissed;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    seenListenable.value = prefs.getBool(seenKey) ?? false;
    widgetTipDismissedListenable.value = prefs.getBool(widgetTipDismissedKey) ?? false;
    checkinAnsweredListenable.value = prefs.getBool(checkinAnsweredKey) ?? false;
  }

  Future<void> markSeen() async {
    seenListenable.value = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(seenKey, true);
  }

  Future<void> markCheckinAnswered() async {
    if (checkinAnsweredListenable.value) return;
    checkinAnsweredListenable.value = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(checkinAnsweredKey, true);
  }

  Future<void> dismissWidgetTip() async {
    widgetTipDismissedListenable.value = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(widgetTipDismissedKey, true);
  }
}
