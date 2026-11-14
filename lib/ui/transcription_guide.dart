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

  String remainderFor(TextEditingValue value) => _previewFor(value).text;

  ({String text, int maxLines}) _previewFor(TextEditingValue value) {
    const empty = (text: '', maxLines: 1);
    final caret = value.selection;
    if (!caret.isCollapsed || caret.extentOffset != value.text.length) {
      return empty;
    }
    final composing = value.composing;
    final isComposing = value.isComposingRangeValid && !composing.isCollapsed;
    if (isComposing && composing.end != value.text.length) return empty;
    final committed = isComposing ? composing.start : caret.extentOffset;
    final skipped = isComposing
        ? composing.textInside(value.text).characters.length
        : 0;
    if (guided case final source?) {
      final end = source.writingRange?.end ?? source.text.length;
      final match = matchGuidedOriginal(source, value.text, committed);
      // Keep the chosen passage after a typo. Use visible characters rather
      // than UTF-16 units to count how far the writer has moved through it.
      final remaining = match == null
          ? source.text
                .substring(source.writingRange?.start ?? 0, end)
                .trimLeft()
                .characters
                .skip(value.text.substring(0, committed).characters.length)
          : source.text.substring(match.end, end).characters;
      return (text: remaining.skip(skipped).take(400).toString(), maxLines: 6);
    }
    final match = matchOriginal(originals, value.text, committed);
    if (match == null) return empty;
    return (
      text: match.remainder.characters.skip(skipped).take(120).toString(),
      maxLines: 1,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (!focus.hasFocus && guided == null) {
      return;
    }
    final value = controller.value;
    final (text: remainder, :maxLines) = _previewFor(value);
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
      ..maxLines = maxLines
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
