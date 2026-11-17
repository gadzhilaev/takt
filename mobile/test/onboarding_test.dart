import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takt_mobile/core/theme.dart';
import 'package:takt_mobile/features/onboarding/onboarding_controller.dart';
import 'package:takt_mobile/features/onboarding/onboarding_illustrations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('onboarding flag persists once', () async {
    final c = OnboardingController();
    await c.load();
    expect(c.seen, isFalse);
    await c.markSeen();
    expect(c.seen, isTrue);

    final c2 = OnboardingController();
    await c2.load();
    expect(c2.seen, isTrue);
  });

  test('widget tip shows only after check-in and until dismissed', () async {
    final c = OnboardingController();
    await c.load();
    expect(c.shouldShowWidgetTip, isFalse);
    await c.markCheckinAnswered();
    expect(c.shouldShowWidgetTip, isTrue);
    await c.dismissWidgetTip();
    expect(c.shouldShowWidgetTip, isFalse);
  });

  testWidgets('onboarding illustrations render in light and dark', (tester) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: brightness == Brightness.dark ? buildDarkTheme() : buildLightTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  OnboardingCheckinArt(),
                  OnboardingDigestArt(),
                  OnboardingWidgetArt(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Чек-ин на сегодня'), findsOneWidget);
      expect(find.textContaining('Сводка'), findsOneWidget);
      expect(find.text('Сделал'), findsWidgets);
    }
  });
}
