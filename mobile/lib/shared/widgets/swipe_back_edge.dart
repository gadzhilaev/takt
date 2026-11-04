import 'package:flutter/material.dart';

/// Свайп от левого края экрана → [onBack] (как iOS back-gesture).
/// Узкая зона, чтобы не перехватывать горизонтальный PageView колонок.
class SwipeBackEdge extends StatefulWidget {
  const SwipeBackEdge({
    super.key,
    required this.onBack,
    required this.child,
    this.enabled = true,
    this.edgeWidth = 28,
  });

  final VoidCallback onBack;
  final Widget child;
  final bool enabled;
  final double edgeWidth;

  @override
  State<SwipeBackEdge> createState() => _SwipeBackEdgeState();
}

class _SwipeBackEdgeState extends State<SwipeBackEdge> {
  double _dx = 0;

  void _maybeBack(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    if (_dx > 64 || v > 500) {
      widget.onBack();
    }
    _dx = 0;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: widget.edgeWidth,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) => _dx = 0,
            onHorizontalDragUpdate: (d) {
              if (d.delta.dx > 0) _dx += d.delta.dx;
            },
            onHorizontalDragEnd: _maybeBack,
            onHorizontalDragCancel: () => _dx = 0,
          ),
        ),
      ],
    );
  }
}
