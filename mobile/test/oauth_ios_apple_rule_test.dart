import 'package:flutter_test/flutter_test.dart';
import 'package:takt_mobile/features/auth/data/oauth_models.dart';

Map<String, dynamic> _providers({required bool apple, required bool vk, required bool yandex}) => {
      'apple': {'id': 'apple', 'enabled': apple},
      'vk': {'id': 'vk', 'enabled': vk},
      'yandex': {'id': 'yandex', 'enabled': yandex},
    };

bool _on(Map<String, dynamic> m, String id) => (m[id] as Map)['enabled'] == true;

void main() {
  test('iOS: без Apple VK/Яндекс скрываются', () {
    final out = applyIosAppleRule(_providers(apple: false, vk: true, yandex: true), isIOS: true);
    expect(_on(out, 'apple'), isFalse);
    expect(_on(out, 'vk'), isFalse);
    expect(_on(out, 'yandex'), isFalse);
    expect((out['vk'] as Map)['reason'], 'apple_required_on_ios');
  });

  test('iOS: с Apple показываются все', () {
    final out = applyIosAppleRule(_providers(apple: true, vk: true, yandex: true), isIOS: true);
    expect(['apple', 'vk', 'yandex'].every((id) => _on(out, id)), isTrue);
  });

  test('Android не затрагивается', () {
    final out = applyIosAppleRule(_providers(apple: false, vk: true, yandex: true), isIOS: false);
    expect(_on(out, 'vk'), isTrue);
    expect(_on(out, 'yandex'), isTrue);
  });

  test('iOS: ни в одной комбинации нет VK/Яндекс без Apple', () {
    for (final a in [true, false]) {
      for (final v in [true, false]) {
        for (final y in [true, false]) {
          final out = applyIosAppleRule(_providers(apple: a, vk: v, yandex: y), isIOS: true);
          if (_on(out, 'vk') || _on(out, 'yandex')) {
            expect(_on(out, 'apple'), isTrue);
          }
        }
      }
    }
  });
}
