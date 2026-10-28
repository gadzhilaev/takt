import 'package:flutter_test/flutter_test.dart';
import 'package:takt_mobile/core/theme.dart';

void main() {
  test('Takt accent color matches brand', () {
    expect(TaktColors.accent.toARGB32() & 0xFFFFFF, 0x315F72);
  });
}
