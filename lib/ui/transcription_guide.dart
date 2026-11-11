import 'package:flutter/material.dart';
import 'editable_geometry.dart';

class TranscriptionGuide {
  const TranscriptionGuide({
    required this.paragraph,
    required this.initialText,
  });

  final String paragraph, initialText;

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
    if (!source.startsWith(committed)) return '';

    // Leave room for the real composing glyphs on the same line.
    final suffix = source.substring(committed.length).characters;
    final composingLength = inComposition
        ? composing.textInside(text).characters.length
        : 0;
    return suffix.skip(composingLength).take(1024).toString();
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
  }) : super(repaint: Listenable.merge([controller, scroll]));

  final TranscriptionGuide guide;
  final TextEditingController controller;
  final ScrollController scroll;
  final GlobalKey fieldKey;
  final TextStyle style;
  final double bottomPadding;

  @override
  void paint(Canvas canvas, Size size) {
    final value = controller.value;
    final remainder = guide.remaining(value);
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
    if (visibleHeight <= 0 || lineTop >= visibleHeight) return;
    final width = editable.size.width - editable.cursorWidth - 1;
    if (width <= 0) return;
    final occupied =
        (editable.textDirection == TextDirection.ltr
                ? caret.dx
                : width - caret.dx)
            .clamp(0.0, width);
    final painter = TextPainter(
      text: TextSpan(
        style: style,
        children: [
          if (occupied > 0) const WidgetSpan(child: SizedBox.shrink()),
          TextSpan(text: remainder),
        ],
      ),
      textDirection: editable.textDirection,
      textScaler: editable.textScaler,
      locale: editable.locale,
      strutStyle: editable.strutStyle,
      textHeightBehavior: editable.textHeightBehavior,
    );
    if (occupied > 0) {
      painter.setPlaceholderDimensions([
        PlaceholderDimensions(
          size: Size(occupied, 0),
          alignment: PlaceholderAlignment.bottom,
        ),
      ]);
    }
    painter.layout(maxWidth: width);
    canvas.save();
    canvas.transform(transform.storage);
    canvas.clipRect(Rect.fromLTWH(0, 0, editable.size.width, visibleHeight));
    painter.paint(canvas, Offset(0, lineTop));
    canvas.restore();
    painter.dispose();
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
