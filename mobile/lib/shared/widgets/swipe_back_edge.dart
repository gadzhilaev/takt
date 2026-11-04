import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Интерактивный свайп от левого края: текущая страница едет за пальцем,
/// под ней виден [underlay] (куда вернёмся).
class SwipeBackEdge extends StatefulWidget {
  const SwipeBackEdge({
    super.key,
    required this.onBack,
    required this.child,
    this.underlay,
    this.enabled = true,
    this.edgeWidth = 24,
  });

  final VoidCallback onBack;
  final Widget child;
  /// Реальный предыдущий экран (или его превью). Если null — нейтральный фон.
  final Widget? underlay;
  final bool enabled;
  final double edgeWidth;

  @override
  State<SwipeBackEdge> createState() => _SwipeBackEdgeState();
}

class _SwipeBackEdgeState extends State<SwipeBackEdge> with SingleTickerProviderStateMixin {
  late final AnimationController _settle;
  double _dx = 0;
  bool _dragging = false;
  bool _completing = false;
  bool _showUnderlay = false;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController.unbounded(vsync: this);
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  double get _width {
    final w = MediaQuery.sizeOf(context).width;
    return w > 0 ? w : 1;
  }

  void _setDx(double value) {
    final next = value.clamp(0.0, _width);
    if (next == _dx) return;
    setState(() => _dx = next);
  }

  void _onDragStart(DragStartDetails _) {
    if (_completing) return;
    _settle.stop();
    setState(() {
      _dragging = true;
      _showUnderlay = true;
      _dx = 0;
    });
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!_dragging || _completing) return;
    _setDx(_dx + d.delta.dx);
  }

  Future<void> _animateTo(double target, {required bool pop}) async {
    _completing = true;
    setState(() {
      _dragging = false;
      _showUnderlay = true;
    });

    final start = _dx;
    final distance = (target - start).abs();
    final ms = (120 + (distance / _width) * 220).round().clamp(120, 340);

    late void Function() tick;
    tick = () {
      if (!mounted) return;
      setState(() => _dx = _settle.value);
    };

    _settle
      ..value = start
      ..addListener(tick);

    try {
      await _settle.animateTo(
        target,
        duration: Duration(milliseconds: ms),
        curve: Curves.easeOutCubic,
      );
    } catch (_) {
      /* disposed */
    } finally {
      _settle.removeListener(tick);
    }

    if (!mounted) return;

    if (pop) {
      widget.onBack();
      if (mounted) {
        setState(() {
          _dx = 0;
          _completing = false;
          _showUnderlay = false;
        });
      }
    } else {
      setState(() {
        _dx = 0;
        _completing = false;
        _showUnderlay = false;
      });
    }
  }

  void _onDragEnd(DragEndDetails d) {
    if (_completing) return;
    if (!_dragging && _dx == 0) return;

    final v = d.primaryVelocity ?? 0;
    final shouldPop = _dx > _width * 0.28 || v > 650;
    _animateTo(shouldPop ? _width : 0, pop: shouldPop);
  }

  void _onDragCancel() {
    if (_completing || _dx == 0) {
      setState(() {
        _dragging = false;
        if (_dx == 0) _showUnderlay = false;
      });
      return;
    }
    _animateTo(0, pop: false);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final dark = Theme.of(context).brightness == Brightness.dark;
    final fallbackBg = dark ? TaktColors.surface2Dark : const Color(0xFFE9EDF2);
    final progress = (_dx / _width).clamp(0.0, 1.0);
    final active = _dx > 0 || _dragging || _showUnderlay;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (active)
          Transform.translate(
            offset: Offset(-_width * 0.25 * (1 - progress), 0),
            child: TickerMode(
              enabled: false,
              child: IgnorePointer(
                child: widget.underlay ?? ColoredBox(color: fallbackBg),
              ),
            ),
          ),
        if (active)
          Opacity(
            opacity: 0.22 * (1 - progress),
            child: const ColoredBox(color: Colors.black),
          ),
        Transform.translate(
          offset: Offset(_dx, 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2 * progress),
                        blurRadius: 20,
                        offset: const Offset(-6, 0),
                      ),
                    ]
                  : null,
            ),
            child: widget.child,
          ),
        ),
        if (!_dragging && !_completing)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: widget.edgeWidth,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: _onDragStart,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              onHorizontalDragCancel: _onDragCancel,
            ),
          ),
        if (_dragging)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              onHorizontalDragCancel: _onDragCancel,
            ),
          ),
      ],
    );
  }
}
