import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Two touches must arrive before movement wins a scroll or page turn.
class PaperTextZoom extends StatelessWidget {
  const PaperTextZoom({
    super.key,
    required this.child,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    this.enabled = true,
  });
  final Widget child;
  final bool enabled;
  final VoidCallback onStart, onEnd;
  final ValueChanged<double> onUpdate;

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    behavior: HitTestBehavior.translucent,
    gestures: {
      if (enabled)
        _TwoFingerZoom: GestureRecognizerFactoryWithHandlers<_TwoFingerZoom>(
          _TwoFingerZoom.new,
          (gesture) => gesture
            ..onStart = onStart
            ..onUpdate = onUpdate
            ..onEnd = onEnd,
        ),
    },
    child: child,
  );
}

class _TwoFingerZoom extends OneSequenceGestureRecognizer {
  VoidCallback? onStart, onEnd;
  ValueChanged<double>? onUpdate;
  final _points = <int, Offset>{};
  Offset? _firstPoint;
  double? _initialDistance;
  bool _zooming = false;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      event.kind == PointerDeviceKind.touch && super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    _points[event.pointer] = event.localPosition;
    _firstPoint ??= event.localPosition;
    if (_points.length == 2) {
      final distance = (_points.values.first - _points.values.last).distance;
      if (distance < 16) {
        resolve(GestureDisposition.rejected);
        return;
      }
      _initialDistance = distance;
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void acceptGesture(int pointer) {
    if (_initialDistance != null && !_zooming) {
      _zooming = true;
      onStart?.call();
    }
  }

  @override
  void rejectGesture(int pointer) {
    _points.remove(pointer);
    stopTrackingPointer(pointer);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      _points[event.pointer] = event.localPosition;
      if (_zooming && _points.length == 2) {
        final distance = (_points.values.first - _points.values.last).distance;
        onUpdate?.call(distance / _initialDistance!);
      } else if (!_zooming &&
          _firstPoint != null &&
          (event.localPosition - _firstPoint!).distance > kTouchSlop) {
        resolve(GestureDisposition.rejected);
      }
    }
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      if (!_zooming) resolve(GestureDisposition.rejected);
      _points.remove(event.pointer);
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    if (_zooming) onEnd?.call();
    _zooming = false;
    _initialDistance = null;
    _firstPoint = null;
    _points.clear();
  }

  @override
  String get debugDescription => 'paper text zoom';
}
