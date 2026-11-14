import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderEditable;

import '../data/model.dart';
import '../source/originals.dart';
import '../source/transcription_comparison.dart';
import 'editable_geometry.dart';

/// Draws the next glyphs after the real field's end, in its own paint layer.
/// The editable's text length, hit testing, selection and IME remain native.
class TranscriptionGuidePainter extends CustomPainter {
  TranscriptionGuidePainter({
    required this.originals,
    this.guided,
    this.comparison,
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
  final TranscriptionComparison? comparison;
  final FocusNode focus;
  final TextEditingController controller;
  final ScrollController scroll;
  final GlobalKey fieldKey;
  final TextStyle style;
  final double bottomPadding;
  final TextPainter layout;

  TextEditingValue? _lastValue;
  ({String text, int? maxLines})? _lastPreview;

  String remainderFor(TextEditingValue value) => _previewFor(value).text;

  ({String text, int? maxLines}) _previewFor(TextEditingValue value) {
    if (_lastValue == value) return _lastPreview!;
    _lastValue = value;
    return _lastPreview = _computePreview(value);
  }

  ({String text, int? maxLines}) _computePreview(TextEditingValue value) {
    const empty = (text: '', maxLines: 1);
    final caret = value.selection;
    if (guided == null &&
        (!caret.isCollapsed || caret.extentOffset != value.text.length)) {
      return empty;
    }
    final composing = value.composing;
    final isComposing = value.isComposingRangeValid && !composing.isCollapsed;
    final composingAtEnd = isComposing && composing.end == value.text.length;
    if (guided == null && isComposing && !composingAtEnd) return empty;
    final committed = composingAtEnd ? composing.start : value.text.length;
    final skipped = composingAtEnd
        ? composing.textInside(value.text).characters.length
        : 0;
    if (guided case final source?) {
      final end = source.writingRange?.end ?? source.text.length;
      final match = matchGuidedOriginal(source, value.text, committed);
      final text = match == null
          ? (comparison ?? TranscriptionComparison(source)).remainderFor(
              value.text.substring(0, committed),
              composingLength: skipped,
            )
          : source.text
                .substring(match.end, end)
                .characters
                .skip(skipped)
                .toString();
      return (text: text, maxLines: null);
    }
    final match = matchOriginal(originals, value.text, committed);
    if (match == null) return empty;
    return (
      text: match.remainder.characters.skip(skipped).take(120).toString(),
      maxLines: 1,
    );
  }

  double scrollExtent(double pixels) {
    if (guided == null) return 0;
    final editable = findEditable(fieldKey.currentContext?.findRenderObject());
    if (editable == null || !editable.hasSize) return 0;
    final lineTop = _layoutAtEnd(editable);
    if (lineTop == null) return 0;
    return lineTop + pixels + layout.height - editable.size.height;
  }

  double? _layoutAtEnd(RenderEditable editable) {
    final value = controller.value;
    final (text: remainder, :maxLines) = _previewFor(value);
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
    return caret.dy - editable.preferredLineHeight;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (!focus.hasFocus && guided == null) return;
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
      originals != oldDelegate.originals ||
      guided != oldDelegate.guided ||
      comparison != oldDelegate.comparison ||
      focus != oldDelegate.focus ||
      style != oldDelegate.style ||
      controller != oldDelegate.controller ||
      scroll != oldDelegate.scroll ||
      fieldKey != oldDelegate.fieldKey ||
      bottomPadding != oldDelegate.bottomPadding;
}

/// Adds the painted guide to the native editable's scrollable range.
class TranscriptionScrollController extends ScrollController {
  TranscriptionScrollController({required super.initialScrollOffset});

  TranscriptionGuidePainter? guide;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _TranscriptionScrollPosition(
    controller: this,
    physics: physics,
    context: context,
    initialPixels: initialScrollOffset,
    keepScrollOffset: keepScrollOffset,
    oldPosition: oldPosition,
  );
}

class _TranscriptionScrollPosition extends ScrollPositionWithSingleContext {
  _TranscriptionScrollPosition({
    required this.controller,
    required super.physics,
    required super.context,
    required super.initialPixels,
    required super.keepScrollOffset,
    super.oldPosition,
  });

  final TranscriptionScrollController controller;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final guideExtent = controller.guide?.scrollExtent(pixels) ?? 0;
    return super.applyContentDimensions(
      minScrollExtent,
      math.max(maxScrollExtent, guideExtent),
    );
  }
}
