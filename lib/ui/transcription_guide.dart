import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderEditable;

import '../source/transcription_comparison.dart';
import 'editable_geometry.dart';

/// Paint the remaining source after the actual input, without modifying it.
class TranscriptionGuidePainter extends CustomPainter {
  TranscriptionGuidePainter({
    required this.comparison,
    this.startOffset = 0,
    required this.controller,
    required this.scroll,
    required this.fieldKey,
    required this.style,
    required this.bottomPadding,
    required this.layout,
  }) : super(repaint: Listenable.merge([controller, scroll]));

  final TranscriptionComparison comparison;
  final int startOffset;
  final TextEditingController controller;
  final ScrollController scroll;
  final GlobalKey fieldKey;
  final TextStyle style;
  final double bottomPadding;
  final TextPainter layout;

  TextEditingValue? _lastValue;
  String _lastRemainder = '';

  String remainderFor(TextEditingValue value) {
    if (_lastValue == value) return _lastRemainder;
    _lastValue = value;
    final composing = value.composing;
    final composingAtEnd =
        value.isComposingRangeValid &&
        !composing.isCollapsed &&
        composing.end == value.text.length;
    final committed = composingAtEnd ? composing.start : value.text.length;
    return _lastRemainder = comparison.remainderFor(
      value.text.substring(startOffset.clamp(0, committed), committed),
      composingLength: composingAtEnd
          ? composing.textInside(value.text).characters.length
          : 0,
    );
  }

  double scrollExtent(double pixels) {
    final editable = findEditable(fieldKey.currentContext?.findRenderObject());
    if (editable == null || !editable.hasSize) return 0;
    final lineTop = _layoutAtEnd(editable);
    if (lineTop == null) return 0;
    return lineTop + pixels + layout.height - editable.size.height;
  }

  double? _layoutAtEnd(RenderEditable editable) {
    final value = controller.value;
    final remainder = remainderFor(value);
    final width = editable.size.width - editable.cursorWidth - 1;
    if (remainder.isEmpty || width <= 0) return null;
    final caret = editable
        .getEndpointsForSelection(
          TextSelection.collapsed(offset: value.text.length),
        )
        .single
        .point;
    final occupied =
        (editable.textDirection == TextDirection.ltr
                ? caret.dx
                : width - caret.dx)
            .clamp(0.0, width);
    layout
      ..text = TextSpan(
        style: style,
        children: [
          if (occupied > 0) const WidgetSpan(child: SizedBox.shrink()),
          TextSpan(text: remainder),
        ],
      )
      ..textDirection = editable.textDirection
      ..textScaler = editable.textScaler
      ..locale = editable.locale
      ..strutStyle = editable.strutStyle
      ..textHeightBehavior = editable.textHeightBehavior
      ..setPlaceholderDimensions([
        if (occupied > 0)
          PlaceholderDimensions(
            size: Size(occupied, 0),
            alignment: PlaceholderAlignment.bottom,
          ),
      ])
      ..layout(maxWidth: width);
    return caret.dy - editable.preferredLineHeight;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final field = fieldKey.currentContext?.findRenderObject();
    final editable = findEditable(field);
    if (field == null || editable == null || !editable.hasSize) return;
    final lineTop = _layoutAtEnd(editable);
    if (lineTop == null) return;
    final transform = editable.getTransformTo(field);
    final origin = MatrixUtils.transformPoint(transform, Offset.zero);
    final visibleHeight = size.height - origin.dy - bottomPadding;
    if (visibleHeight <= 0 || lineTop >= visibleHeight) return;
    canvas.save();
    canvas.transform(transform.storage);
    canvas.clipRect(Rect.fromLTWH(0, 0, editable.size.width, visibleHeight));
    layout.paint(canvas, Offset(0, lineTop));
    canvas.restore();
  }

  @override
  bool shouldRepaint(TranscriptionGuidePainter oldDelegate) =>
      comparison != oldDelegate.comparison ||
      startOffset != oldDelegate.startOffset ||
      style != oldDelegate.style ||
      controller != oldDelegate.controller ||
      scroll != oldDelegate.scroll ||
      fieldKey != oldDelegate.fieldKey ||
      bottomPadding != oldDelegate.bottomPadding ||
      layout != oldDelegate.layout;
}
