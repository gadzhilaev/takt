import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt_mobile/shared/widgets/kanban_drag_edge_scroll.dart';

void main() {
  testWidgets('edge dwell advances one page and needs center re-arm', (tester) async {
    final controller = PageController();
    final pagerKey = GlobalKey();
    late KanbanDragEdgeScroll edgeScroll;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            edgeScroll = KanbanDragEdgeScroll(
              controller: controller,
              pageCount: 4,
              edgeDwell: const Duration(milliseconds: 200),
              animationDuration: const Duration(milliseconds: 100),
            );
            return Center(
              child: SizedBox(
                key: pagerKey,
                width: 300,
                height: 200,
                child: PageView(
                  controller: controller,
                  children: const [Text('0'), Text('1'), Text('2'), Text('3')],
                ),
              ),
            );
          },
        ),
      ),
    );
    addTearDown(edgeScroll.dispose);
    addTearDown(controller.dispose);

    final box = tester.renderObject<RenderBox>(find.byKey(pagerKey));
    final origin = box.localToGlobal(Offset.zero);
    final center = origin + const Offset(150, 100);
    final right = origin + const Offset(298, 100);
    final left = origin + const Offset(1, 100);
    final context = tester.element(find.byKey(pagerKey));

    edgeScroll.onPointer(right, context);
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpAndSettle();
    expect(controller.page, 1);

    await tester.pump(const Duration(seconds: 1));
    expect(controller.page, 1);

    edgeScroll.onPointer(center, context);
    edgeScroll.onPointer(right, context);
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpAndSettle();
    expect(controller.page, 2);

    edgeScroll.onPointer(center, context);
    edgeScroll.onPointer(left, context);
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpAndSettle();
    expect(controller.page, 1);
  });
}
