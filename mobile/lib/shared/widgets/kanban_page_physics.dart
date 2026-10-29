import 'package:flutter/material.dart';

/// Clamps overscroll so the last/first Kanban column does not rubber-band hard.
class KanbanPagePhysics extends PageScrollPhysics {
  const KanbanPagePhysics({super.parent});

  @override
  KanbanPagePhysics applyTo(ScrollPhysics? ancestor) {
    return KanbanPagePhysics(parent: buildParent(ancestor));
  }

  @override
  double get dragStartDistanceMotionThreshold => 3.5;

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 0.9,
        stiffness: 180,
        damping: 28,
      );
}
