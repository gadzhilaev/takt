import 'package:flutter/material.dart';

/// Branch container for [StatefulShellRoute]: keeps all branches alive and
/// slides between them like paging when the bottom nav index changes.
class SlidingBranchStack extends StatelessWidget {
  const SlidingBranchStack({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  static const _duration = Duration(milliseconds: 280);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < children.length; i++)
            AnimatedSlide(
              duration: _duration,
              curve: Curves.easeOutCubic,
              offset: Offset((i - currentIndex).toDouble(), 0),
              child: IgnorePointer(
                ignoring: i != currentIndex,
                child: TickerMode(
                  enabled: i == currentIndex,
                  child: children[i],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
