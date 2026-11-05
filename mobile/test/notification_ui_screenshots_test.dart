import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt_mobile/core/theme.dart';
import 'package:takt_mobile/features/auth/presentation/notifications_intro_page.dart';
import 'package:takt_mobile/shared/models/models.dart';
import 'package:takt_mobile/shared/widgets/app_icon.dart';
import 'package:takt_mobile/shared/widgets/takt_app_bar.dart';
import 'package:takt_mobile/shared/widgets/takt_ui.dart';

Future<void> _loadCyrillicFont() async {
  const candidates = [
    '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
    '/Library/Fonts/Arial Unicode.ttf',
    '/System/Library/Fonts/Supplemental/Arial.ttf',
  ];
  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = await file.readAsBytes();
    final loader = FontLoader('TaktShot')
      ..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
    await loader.load();
    return;
  }
  fail('No system font with Cyrillic found for screenshots');
}

ThemeData _shotTheme() {
  final base = buildLightTheme();
  final text = base.textTheme.apply(fontFamily: 'TaktShot');
  return base.copyWith(
    textTheme: text,
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'TaktShot'),
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: (base.appBarTheme.titleTextStyle ?? text.titleLarge)?.copyWith(
        fontFamily: 'TaktShot',
        color: TaktColors.graphite,
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      toolbarTextStyle: text.bodyMedium?.copyWith(fontFamily: 'TaktShot'),
    ),
  );
}

class _NotificationsShot extends StatelessWidget {
  const _NotificationsShot();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      const AppNotification(
        id: '1',
        title: 'Разработать материалы для урока школьников',
        kind: 'task_assigned',
        createdAt: '2026-11-05T12:00:00Z',
        body: 'Сабина Велиева назначила вам задачу\nПроект УПК',
        projectName: 'УПК',
        isRead: false,
      ),
      const AppNotification(
        id: '2',
        title: 'Поменять пароль от Shadow Defender',
        kind: 'task_assigned',
        createdAt: '2026-11-01T10:30:00Z',
        body: 'Рахман назначил вам задачу\nПроект УПК',
        projectName: 'УПК',
        isRead: true,
      ),
    ];
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    final accent = dark ? TaktColors.accentDark : TaktColors.accent;
    final fg = dark ? TaktColors.foregroundDark : TaktColors.graphite;

    return Scaffold(
      appBar: const TaktAppBar(title: 'Уведомления'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          for (final n in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                decoration: BoxDecoration(
                  color: n.isRead
                      ? (dark ? TaktColors.surfaceDark : TaktColors.surface)
                      : (dark ? TaktColors.accentSoftDark : TaktColors.accentSoft),
                  borderRadius: BorderRadius.circular(TaktRadii.lg),
                  border: Border.all(
                    color: n.isRead
                        ? (dark ? TaktColors.borderDark : TaktColors.border)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: dark ? TaktColors.surface2Dark : TaktColors.surface2,
                        shape: BoxShape.circle,
                      ),
                      child: AppIcon(AppIcon.notificationKind(n.kind), size: 18, color: accent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  taktNotificationKindLabel(n.kind),
                                  style: TextStyle(
                                    fontFamily: 'TaktShot',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: fg,
                                  ),
                                ),
                              ),
                              Text(
                                n.isRead ? '4 дн.' : '28 мин',
                                style: TextStyle(
                                  fontFamily: 'TaktShot',
                                  fontSize: 11,
                                  color: muted,
                                ),
                              ),
                              if (!n.isRead) ...[
                                const SizedBox(width: 6),
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            n.title,
                            style: TextStyle(
                              fontFamily: 'TaktShot',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: fg,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            taktParseNotificationBody(n.body).detail,
                            style: TextStyle(fontFamily: 'TaktShot', fontSize: 12.5, color: muted),
                          ),
                          Text(
                            'Проект УПК',
                            style: TextStyle(fontFamily: 'TaktShot', fontSize: 12.5, color: muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadCyrillicFont();
  });

  testWidgets('screenshot permission prompt', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        theme: _shotTheme(),
        home: DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: 'TaktShot'),
          child: const NotificationsIntroPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/push_permission_prompt.png'),
    );
  });

  testWidgets('screenshot notifications list', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        theme: _shotTheme(),
        home: DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: 'TaktShot'),
          child: const _NotificationsShot(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/notifications_list.png'),
    );
  });
}
