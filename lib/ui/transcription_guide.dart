import 'package:flutter/material.dart';

import '../data/model.dart';
import '../source/originals.dart';
import 'editable_geometry.dart';

/// Draws the next glyphs after the real field's end, in its own paint layer.
/// The editable's text length, hit testing, selection and IME remain native.
class TranscriptionGuidePainter extends CustomPainter {
  TranscriptionGuidePainter({
    required this.originals,
    this.guided,
    required this.focus,
    required this.controller,
    required this.scroll,
    required this.fieldKey,
    required this.style,
    required this.bottomPadding,
    required this.layout,
  }) : super(repaint: Listenable.merge([controller, scroll, focus]));

  final List<RegisteredOriginal> originals;
  final RegisteredOriginal? guided;
  final FocusNode focus;
  final TextEditingController controller;
  final ScrollController scroll;
  final GlobalKey fieldKey;
  final TextStyle style;
  final double bottomPadding;
  final TextPainter layout;

  String remainderFor(TextEditingValue value) {
    final caret = value.selection;
    if (!caret.isCollapsed || caret.extentOffset != value.text.length) {
      return '';
    }
    final composing = value.composing;
    final isComposing = value.isComposingRangeValid && !composing.isCollapsed;
    if (isComposing && composing.end != value.text.length) return '';
    final committed = isComposing ? composing.start : caret.extentOffset;
    final source = guided;
    final match =
        (source == null
            ? null
            : matchGuidedOriginal(source, value.text, committed)) ??
        matchOriginal(originals, value.text, committed);
    if (match == null) return '';
    final skipped = isComposing
        ? composing.textInside(value.text).characters.length
        : 0;
    return match.remainder.characters.skip(skipped).take(120).toString();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (!focus.hasFocus && (guided == null || controller.text.isNotEmpty)) {
      return;
    }
    final value = controller.value;
    final remainder = remainderFor(value);
    if (remainder.isEmpty) return;
    final field = fieldKey.currentContext?.findRenderObject();
    final editable = findEditable(field);
    if (field == null || editable == null || !editable.hasSize) return;

    final caret = editable
        .getEndpointsForSelection(
          TextSelection.collapsed(offset: value.text.length),
        )
        .single
        .point;
    final lineTop = caret.dy - editable.preferredLineHeight;
    final transform = editable.getTransformTo(field);
    final origin = MatrixUtils.transformPoint(transform, Offset.zero);
    // The field may only lay out as many lines as the user has entered. The
    // guide can continue through the blank paper below those lines.
    final visibleHeight = size.height - origin.dy - bottomPadding;
    if (visibleHeight <= 0) return;
    final width = editable.size.width - editable.cursorWidth - 1;
    if (width <= 0) return;
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
      ..maxLines = 1
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
    if (lineTop >= visibleHeight) return;
    canvas.save();
    canvas.transform(transform.storage);
    canvas.clipRect(Rect.fromLTWH(0, 0, editable.size.width, visibleHeight));
    layout.paint(canvas, Offset(0, lineTop));
    canvas.restore();
  }

  @override
  bool shouldRepaint(TranscriptionGuidePainter oldDelegate) =>
      originals != oldDelegate.originals ||
      guided != oldDelegate.guided ||
      focus != oldDelegate.focus ||
      style != oldDelegate.style ||
      controller != oldDelegate.controller ||
      scroll != oldDelegate.scroll ||
      fieldKey != oldDelegate.fieldKey ||
      bottomPadding != oldDelegate.bottomPadding;
}
