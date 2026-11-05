import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt_mobile/core/theme.dart';
import 'package:takt_mobile/shared/models/models.dart';
import 'package:takt_mobile/shared/widgets/app_icon.dart';
import 'package:takt_mobile/shared/widgets/kanban_column.dart';
import 'package:takt_mobile/shared/widgets/takt_app_bar.dart';
import 'package:takt_mobile/shared/widgets/user_avatar.dart';

/// README device shots → `docs/screenshots/readme/mobile-*.png`.
/// `flutter test test/readme_ui_screenshots_test.dart --update-goldens`

const _out = '../../docs/screenshots/readme';

Future<bool> _loadCyrillicFont() async {
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
    return true;
  }
  return false;
}

ThemeData _shotTheme() {
  final base = buildLightTheme();
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'TaktShot'),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'TaktShot'),
  );
}

TaskAssignee _assignee(String id, String name) => TaskAssignee(id: id, name: name);

TaskItem _task({
  required String id,
  required String title,
  required String statusId,
  required String priority,
  required String description,
  required List<TaskAssignee> assignees,
  bool done = false,
}) {
  final now = DateTime.now().toUtc();
  return TaskItem(
    id: id,
    title: title,
    statusId: statusId,
    priority: priority,
    position: 0,
    description: description,
    assignees: assignees,
    statusEnteredAt: now.subtract(const Duration(hours: 5)).toIso8601String(),
    createdAt: now.subtract(const Duration(days: 2)).toIso8601String(),
    closedAt: done ? now.subtract(const Duration(hours: 1)).toIso8601String() : null,
  );
}

Widget _phoneShell({required Widget body, required String title, required int tab}) {
  return Scaffold(
    backgroundColor: const Color(0xFFF4F7F8),
    appBar: TaktAppBar(title: title),
    body: body,
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.check_circle_outline), label: 'Мои задачи'),
        NavigationDestination(icon: Icon(Icons.view_column_outlined), label: 'Доска'),
        NavigationDestination(icon: Icon(Icons.person_outline), label: 'Профиль'),
      ],
    ),
  );
}

Widget _loginShot() {
  return Scaffold(
    backgroundColor: const Color(0xFFF4F7F8),
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE9F1F3), Color(0xFFF4F7F8), Color(0xFFE9EDF2)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset('assets/brand/takt-logo.svg', height: 40),
                  const SizedBox(height: 24),
                  Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: TaktColors.graphite.withValues(alpha: 0.08)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Вход',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'TaktShot',
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: TaktColors.graphite,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Войдите, чтобы открыть доску команды',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'TaktShot', fontSize: 14, color: TaktColors.muted),
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Padding(
                                padding: EdgeInsets.all(12),
                                child: AppIcon(AppIcons.mail, size: 20),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Пароль',
                              prefixIcon: const Padding(
                                padding: EdgeInsets.all(12),
                                child: AppIcon(AppIcons.lock, size: 20),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: () {},
                            child: const Text('Войти', style: TextStyle(fontFamily: 'TaktShot')),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text('или', style: TextStyle(fontFamily: 'TaktShot', color: TaktColors.muted)),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(onPressed: () {}, child: const Text('Продолжить с Apple', style: TextStyle(fontFamily: 'TaktShot'))),
                          const SizedBox(height: 8),
                          OutlinedButton(onPressed: () {}, child: const Text('Продолжить с VK ID', style: TextStyle(fontFamily: 'TaktShot'))),
                          const SizedBox(height: 8),
                          OutlinedButton(onPressed: () {}, child: const Text('Продолжить с Яндекс ID', style: TextStyle(fontFamily: 'TaktShot'))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text.rich(
                    TextSpan(
                      style: TextStyle(fontFamily: 'TaktShot', fontSize: 14, color: TaktColors.muted),
                      children: [
                        const TextSpan(text: 'Нет аккаунта? '),
                        TextSpan(text: 'Создать', style: TextStyle(color: TaktColors.accent, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var ready = false;

  setUpAll(() async {
    if (!Platform.isMacOS) return;
    ready = await _loadCyrillicFont();
  });

  testWidgets('readme mobile-login', (tester) async {
    if (!ready) {
      markTestSkipped('README mobile goldens require macOS + Cyrillic font');
      return;
    }
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _shotTheme(),
        home: DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: 'TaktShot'),
          child: _loginShot(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('$_out/mobile-login.png'));
  });

  testWidgets('readme mobile-kanban', (tester) async {
    if (!ready) {
      markTestSkipped('README mobile goldens require macOS + Cyrillic font');
      return;
    }
    await tester.binding.setSurfaceSize(const Size(390, 844));
    const col = StatusColumn(id: 's1', name: 'В работе', position: 1, color: '#347FA4');
    final tasks = [
      _task(
        id: '1',
        title: 'Доработать карточки задач',
        statusId: 's1',
        priority: 'high',
        description: 'Приоритет, исполнители и время в столбце.',
        assignees: [_assignee('a', 'Алина Смирнова'), _assignee('i', 'Игорь Лебедев')],
      ),
      _task(
        id: '2',
        title: 'Настроить Web Push',
        statusId: 's1',
        priority: 'high',
        description: 'VAPID, soft-prompt и тост при назначении.',
        assignees: [_assignee('p', 'Пётр Орлов'), _assignee('m', 'Мария Волкова')],
      ),
      _task(
        id: '3',
        title: 'Сверить mobile с web-доской',
        statusId: 's1',
        priority: 'medium',
        description: 'Вкладки «Мои задачи» / «Доска».',
        assignees: [_assignee('i', 'Игорь Лебедев')],
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _shotTheme(),
        home: DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: 'TaktShot'),
          child: _phoneShell(
            title: 'Запуск продукта',
            tab: 1,
            body: KanbanColumnPane(
              column: col,
              tasks: tasks,
              dark: false,
              onOpenTask: (_) {},
              onAdd: () {},
              draggable: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('$_out/mobile-kanban.png'));
  });

  testWidgets('readme mobile-my-tasks', (tester) async {
    if (!ready) {
      markTestSkipped('README mobile goldens require macOS + Cyrillic font');
      return;
    }
    await tester.binding.setSurfaceSize(const Size(390, 844));
    const col = StatusColumn(id: 's0', name: 'К выполнению', position: 0, color: '#607FA4');
    final tasks = [
      _task(
        id: '1',
        title: 'Собрать сценарии онбординга',
        statusId: 's0',
        priority: 'high',
        description: 'Пройти регистрацию и первый проект.',
        assignees: [_assignee('d', 'Демо пользователь'), _assignee('a', 'Алина Смирнова')],
      ),
      _task(
        id: '2',
        title: 'Проверить приглашения по ссылке',
        statusId: 's0',
        priority: 'urgent',
        description: 'Открыть приглашение без аккаунта.',
        assignees: [_assignee('d', 'Демо пользователь'), _assignee('p', 'Пётр Орлов')],
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _shotTheme(),
        home: DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: 'TaktShot'),
          child: _phoneShell(
            title: 'Мои задачи',
            tab: 0,
            body: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                Text('Запуск продукта', style: TextStyle(fontFamily: 'TaktShot', fontSize: 13, color: TaktColors.muted)),
                const SizedBox(height: 8),
                KanbanColumnPane(
                  column: col,
                  tasks: tasks,
                  dark: false,
                  onOpenTask: (_) {},
                  draggable: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('$_out/mobile-my-tasks.png'));
  });

  testWidgets('readme mobile-profile', (tester) async {
    if (!ready) {
      markTestSkipped('README mobile goldens require macOS + Cyrillic font');
      return;
    }
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _shotTheme(),
        home: DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: 'TaktShot'),
          child: _phoneShell(
            title: 'Профиль',
            tab: 2,
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Row(
                  children: [
                    const TaktUserAvatar(name: 'Демо пользователь', size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Демо пользователь',
                            style: TextStyle(
                              fontFamily: 'TaktShot',
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: TaktColors.graphite,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'demo@example.com',
                            style: TextStyle(fontFamily: 'TaktShot', fontSize: 13, color: TaktColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _profileTile(AppIcons.notifications, 'Уведомления', 'Разрешены'),
                _profileTile(AppIcons.assignment, 'Мои проекты', '3 проекта'),
                _profileTile(AppIcons.theme, 'Тема', 'Системная'),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {},
                  child: const Text('Выйти', style: TextStyle(fontFamily: 'TaktShot')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('$_out/mobile-profile.png'));
  });
}

Widget _profileTile(String icon, String title, String trailing) {
  return Card(
    margin: const EdgeInsets.only(bottom: 8),
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: TaktColors.border),
    ),
    child: ListTile(
      leading: AppIcon(icon, size: 20, color: TaktColors.muted),
      title: Text(title, style: const TextStyle(fontFamily: 'TaktShot', fontSize: 15)),
      trailing: Text(
        trailing,
        style: TextStyle(fontFamily: 'TaktShot', fontSize: 13, color: TaktColors.muted),
      ),
    ),
  );
}
