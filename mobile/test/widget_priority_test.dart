import 'package:flutter_test/flutter_test.dart';
import 'package:takt_mobile/shared/models/models.dart';

int rank(String p) {
  switch (p) {
    case 'urgent':
      return 0;
    case 'high':
      return 1;
    default:
      return 2;
  }
}

void main() {
  test('widget task order: urgent then high then medium, stable by position', () {
    final tasks = [
      const TaskItem(id: '1', title: 'a', statusId: 's', priority: 'medium', position: 10),
      const TaskItem(id: '2', title: 'b', statusId: 's', priority: 'urgent', position: 20),
      const TaskItem(id: '3', title: 'c', statusId: 's', priority: 'high', position: 5),
      const TaskItem(id: '4', title: 'd', statusId: 's', priority: 'urgent', position: 1),
    ];
    tasks.sort((a, b) {
      final pa = rank(a.priority);
      final pb = rank(b.priority);
      if (pa != pb) return pa.compareTo(pb);
      return a.position.compareTo(b.position);
    });
    expect(tasks.map((t) => t.id).toList(), ['4', '2', '3', '1']);
  });
}
