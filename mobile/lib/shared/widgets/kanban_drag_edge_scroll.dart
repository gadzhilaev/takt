import 'dart:async';

import 'package:flutter/material.dart';

/// While a task is dragged, scroll the Kanban [PageController] when the
/// pointer sits near the left/right edge — so columns behind the current
/// page (e.g. «К выполнению») become droppable, not only the peeked next one.
class KanbanDragEdgeScroll {
  KanbanDragEdgeScroll({
    required this.controller,
    required this.pageCount,
    this.edgePx = 56,
    this.stepInterval = const Duration(milliseconds: 380),
  });

  final PageController controller;
  final int pageCount;
  final double edgePx;
  final Duration stepInterval;

  Timer? _timer;
  int _dir = 0;
  bool _animating = false;

  void onPointer(Offset global, BuildContext pagerContext) {
    if (pageCount <= 1) return;
    final box = pagerContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final local = box.globalToLocal(global);
    final w = box.size.width;
    var dir = 0;
    if (local.dx < edgePx) {
      dir = -1;
    } else if (local.dx > w - edgePx) {
      dir = 1;
    }
    if (dir == _dir) return;
    _dir = dir;
    _timer?.cancel();
    _timer = null;
    if (dir == 0) return;
    _step();
    _timer = Timer.periodic(stepInterval, (_) => _step());
  }

  void stop() {
    _dir = 0;
    _timer?.cancel();
    _timer = null;
    _animating = false;
  }

  void dispose() => stop();

  void _step() {
    if (_dir == 0 || _animating || !controller.hasClients) return;
    final page = controller.page?.round() ?? controller.initialPage;
    final next = (page + _dir).clamp(0, pageCount - 1);
    if (next == page) return;
    _animating = true;
    controller
        .animateToPage(
          next,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() => _animating = false);
  }
}
