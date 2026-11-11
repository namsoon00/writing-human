import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Extends the existing text field's scroll range through the untyped guide.
class GuideScrollController extends ScrollController {
  GuideScrollController({super.initialScrollOffset});

  double _guideExtent = 0;

  double get textExtent => (position as _GuideScrollPosition).textExtent;

  bool setGuideExtent(double extent) {
    if (_guideExtent == extent) return false;
    _guideExtent = extent;
    return true;
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _GuideScrollPosition(
    controller: this,
    physics: physics,
    context: context,
    initialPixels: initialScrollOffset,
    oldPosition: oldPosition,
  );
}

class _GuideScrollPosition extends ScrollPositionWithSingleContext {
  _GuideScrollPosition({
    required this.controller,
    required super.physics,
    required super.context,
    required super.initialPixels,
    super.oldPosition,
  });

  final GuideScrollController controller;
  double textExtent = 0;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    textExtent = maxScrollExtent;
    return super.applyContentDimensions(
      minScrollExtent,
      math.max(textExtent, controller._guideExtent),
    );
  }
}
