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
    this.edgeDwell = const Duration(milliseconds: 260),
    this.animationDuration = const Duration(milliseconds: 240),
  });

  final PageController controller;
  final int pageCount;
  final double edgePx;
  final Duration edgeDwell;
  final Duration animationDuration;

  Timer? _timer;
  int _dir = 0;
  bool _animating = false;
  bool _armed = true;

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
    if (dir == 0) {
      _armed = true;
      return;
    }
    if (!_armed) return;
    _timer = Timer(edgeDwell, _step);
  }

  void stop() {
    _dir = 0;
    _timer?.cancel();
    _timer = null;
    _animating = false;
    _armed = true;
  }

  void dispose() => stop();

  void _step() {
    if (_dir == 0 || _animating || !controller.hasClients) return;
    final page = controller.page?.round() ?? controller.initialPage;
    final next = (page + _dir).clamp(0, pageCount - 1);
    if (next == page) return;
    _armed = false;
    _animating = true;
    controller
        .animateToPage(
          next,
          duration: animationDuration,
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() => _animating = false);
  }
}
