import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// One deliberate horizontal gesture turns one sheet. Vertical scrolling,
/// taps and long presses still go to the native editor.
class PaperSwipe extends StatefulWidget {
  const PaperSwipe({
    super.key,
    required this.child,
    this.onPrevious,
    this.onNext,
    this.touchOnly = false,
  });
  final Widget child;
  final VoidCallback? onPrevious, onNext;
  final bool touchOnly;
  @override
  State<PaperSwipe> createState() => _PaperSwipeState();
}

class _PaperSwipeState extends State<PaperSwipe> {
  double distance = 0;
  late final HorizontalDragGestureRecognizer drag;

  @override
  void initState() {
    super.initState();
    drag = HorizontalDragGestureRecognizer(debugOwner: this)
      ..dragStartBehavior = DragStartBehavior.down
      ..onStart = (_) {
        distance = 0;
      }
      ..onUpdate = (details) {
        distance += details.delta.dx;
      }
      ..onCancel = () {
        distance = 0;
      }
      ..onEnd = (details) {
        final dx = distance, speed = details.primaryVelocity ?? 0;
        distance = 0;
        if (dx.abs() < 64 && !(dx.abs() >= 36 && speed.abs() >= 500)) {
          return;
        }
        if (speed.abs() >= 500 && dx * speed < 0) return;
        if (dx < 0) widget.onNext?.call();
        if (dx > 0) widget.onPrevious?.call();
      };
  }

  bool get enabled => widget.onPrevious != null || widget.onNext != null;

  @override
  void dispose() {
    drag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SwipeRegion(
    onDown: (event) {
      if (enabled &&
          (!widget.touchOnly || event.kind != PointerDeviceKind.mouse)) {
        drag.addPointer(event);
      }
    },
    onPanZoom: (event) {
      if (enabled) drag.addPointerPanZoom(event);
    },
    child: widget.child,
  );
}

class _SwipeRegion extends SingleChildRenderObjectWidget {
  const _SwipeRegion({
    required this.onDown,
    required this.onPanZoom,
    required super.child,
  });
  final PointerDownEventListener onDown;
  final PointerPanZoomStartEventListener onPanZoom;
  @override
  _SwipeHitBox createRenderObject(BuildContext context) =>
      _SwipeHitBox(onDown, onPanZoom);
  @override
  void updateRenderObject(BuildContext context, _SwipeHitBox renderObject) {
    renderObject
      ..onDown = onDown
      ..onPanZoom = onPanZoom;
  }
}

class _SwipeHitBox extends RenderProxyBox {
  _SwipeHitBox(this.onDown, this.onPanZoom);
  PointerDownEventListener onDown;
  PointerPanZoomStartEventListener onPanZoom;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    // Register the horizontal recognizer before the editor's pan recognizer.
    // It only wins on horizontal intent; native tap/long-press/vertical scroll
    // recognizers can still win. No editing value or pointer is synthesized.
    result.add(BoxHitTestEntry(this, position));
    hitTestChildren(result, position: position);
    return true;
  }

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    if (event is PointerDownEvent) onDown(event);
    if (event is PointerPanZoomStartEvent) onPanZoom(event);
  }
}
