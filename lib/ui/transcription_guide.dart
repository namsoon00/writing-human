import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'editable_geometry.dart';

class TranscriptionGuide {
  const TranscriptionGuide({
    required this.paragraph,
    required this.initialText,
  });

  factory TranscriptionGuide.resume({
    required String paragraph,
    required String text,
  }) {
    final source = paragraph.trimLeft();
    if (_matchedLength(source, text.trimLeft()) == null) {
      // A saved page can contain earlier paragraphs. Only resume a matching
      // suffix that starts at a line boundary.
      final paragraphBreak = text.lastIndexOf('\n\n');
      final lineBreak = text.lastIndexOf('\n');
      for (final start in {
        if (paragraphBreak >= 0) paragraphBreak + 2,
        if (lineBreak >= 0) lineBreak + 1,
      }) {
        final written = text.substring(start).trimLeft();
        if (written.isNotEmpty && _matchedLength(source, written) != null) {
          return TranscriptionGuide(
            paragraph: paragraph,
            initialText: text.substring(0, start),
          );
        }
      }
    }
    return TranscriptionGuide(paragraph: paragraph, initialText: '');
  }

  final String paragraph, initialText;

  // A single return or a blank line both separate paragraphs on the page.
  static int? _matchedLength(String source, String written) {
    var original = 0;
    var typed = 0;
    while (typed < written.length) {
      if (original == source.length ||
          source.codeUnitAt(original) != written.codeUnitAt(typed)) {
        return null;
      }
      final newline = written.codeUnitAt(typed) == 10;
      original++;
      typed++;
      if (newline) {
        while (original < source.length && source.codeUnitAt(original) == 10) {
          original++;
        }
        while (typed < written.length && written.codeUnitAt(typed) == 10) {
          typed++;
        }
      }
    }
    return original;
  }

  int? consumed(String text) => text.startsWith(initialText)
      ? _matchedLength(
          paragraph.trimLeft(),
          text.substring(initialText.length).trimLeft(),
        )
      : null;

  String remaining(TextEditingValue value) {
    final text = value.text;
    if (!text.startsWith(initialText)) return '';
    final composing = value.composing;
    final inComposition = value.isComposingRangeValid && !composing.isCollapsed;
    if (inComposition &&
        (composing.start < initialText.length ||
            composing.end != text.length)) {
      return '';
    }
    final committed = text
        .substring(initialText.length, inComposition ? composing.start : null)
        .trimLeft();
    final source = paragraph.trimLeft();
    final matched = _matchedLength(source, committed);
    if (matched == null) return '';

    // Leave room for the real composing glyphs on the same line.
    final suffix = source.substring(matched);
    if (!inComposition) return suffix;
    return suffix.characters
        .skip(composing.textInside(text).characters.length)
        .toString();
  }
}

/// Draws the next glyphs after the real field's end, in its own paint layer.
/// The editable's text length, hit testing, selection and IME remain native.
class TranscriptionGuidePainter extends CustomPainter {
  TranscriptionGuidePainter({
    required this.guide,
    required this.controller,
    required this.scroll,
    required this.fieldKey,
    required this.style,
    required this.bottomPadding,
    required this.layout,
    required this.onExtent,
  }) : super(repaint: Listenable.merge([controller, scroll]));

  final TranscriptionGuide guide;
  final TextEditingController controller;
  final ScrollController scroll;
  final GlobalKey fieldKey;
  final TextStyle style;
  final double bottomPadding;
  final TextPainter layout;
  final ValueChanged<double> onExtent;

  @override
  void paint(Canvas canvas, Size size) {
    final value = controller.value;
    final remainder = guide.remaining(value);
    if (remainder.isEmpty) {
      onExtent(0);
      return;
    }
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
    final scrollOffset = scroll.hasClients ? scroll.offset : 0.0;
    onExtent(
      math.max(
        0.0,
        (lineTop + scrollOffset + layout.height - visibleHeight).ceilToDouble(),
      ),
    );
    if (lineTop >= visibleHeight) return;
    canvas.save();
    canvas.transform(transform.storage);
    canvas.clipRect(Rect.fromLTWH(0, 0, editable.size.width, visibleHeight));
    layout.paint(canvas, Offset(0, lineTop));
    canvas.restore();
  }

  @override
  bool shouldRepaint(TranscriptionGuidePainter oldDelegate) =>
      guide != oldDelegate.guide ||
      style != oldDelegate.style ||
      controller != oldDelegate.controller ||
      scroll != oldDelegate.scroll ||
      fieldKey != oldDelegate.fieldKey ||
      bottomPadding != oldDelegate.bottomPadding;
}
