import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../data/model.dart';
import 'pencil_marks.dart';

/// Holds a transient stroke in page coordinates without selecting any text.
class PaperHighlighter extends StatefulWidget {
  const PaperHighlighter({
    super.key,
    required this.controller,
    required this.scroll,
    required this.editable,
    required this.choice,
    required this.onStroke,
  });

  final TextEditingController controller;
  final ScrollController scroll;
  final EditableTextState? Function() editable;
  final BookDetailChoice choice;
  final ValueChanged<TextRange> onStroke;

  @override
  State<PaperHighlighter> createState() => _PaperHighlighterState();
}

class _PaperHighlighterState extends State<PaperHighlighter> {
  final _paintKey = GlobalKey();
  final _range = ValueNotifier<TextRange?>(null);
  ({TextRange character, Offset point, String text})? _origin;

  bool get _composing {
    final value = widget.controller.value;
    return value.isComposingRangeValid && !value.composing.isCollapsed;
  }

  void _start(LongPressStartDetails details) {
    final editor = widget.editable();
    if (editor == null || _composing) return;
    editor.hideToolbar();
    if (!widget.choice.enabled) return;

    final render = editor.renderEditable;
    final point = details.globalPosition;
    final text = widget.controller.text;
    final offset = render.getPositionForPoint(point).offset;
    final character = _characterAt(render, point, offset, text);
    if (character != null) {
      _origin = (character: character, point: point, text: text);
    }
  }

  TextRange? _characterAt(
    RenderEditable render,
    Offset point,
    int offset,
    String text,
  ) {
    final local = render.globalToLocal(point);
    final boundary = CharacterBoundary(text);
    // The nearest caret could be on either side of the glyph under the finger.
    for (final index in [offset, offset - 1]) {
      if (index < 0 || index >= text.length) continue;
      final character = boundary.getTextBoundaryAt(index);
      final boxes = render.getBoxesForSelection(
        TextSelection(baseOffset: character.start, extentOffset: character.end),
      );
      if (boxes.any((box) {
        final rect = box.toRect();
        return rect.width > 0 &&
            Rect.fromLTRB(
              rect.left,
              rect.top - 4,
              rect.right,
              rect.bottom + 4,
            ).contains(local);
      })) {
        return character;
      }
    }
    return null;
  }

  void _trace(Offset point) {
    final origin = _origin;
    final render = widget.editable()?.renderEditable;
    if (origin == null || render == null) return;
    if (_composing || widget.controller.text != origin.text) {
      _cancel();
      return;
    }
    if (_range.value == null && (point - origin.point).distance < 4) return;
    final offset = render.getPositionForPoint(point).offset;
    final boundary = CharacterBoundary(origin.text);
    final character = _characterAt(render, point, offset, origin.text);
    _range.value = TextRange(
      start: math.min(
        origin.character.start,
        character?.start ?? boundary.getLeadingTextBoundaryAt(offset)!,
      ),
      end: math.max(
        origin.character.end,
        character?.end ??
            (offset == 0 ? 0 : boundary.getTrailingTextBoundaryAt(offset - 1)!),
      ),
    );
  }

  void _end(LongPressEndDetails details) {
    _trace(details.globalPosition);
    final range = _range.value;
    _cancel();
    if (range != null && widget.choice.enabled) widget.onStroke(range);
  }

  void _cancel() {
    _origin = null;
    _range.value = null;
  }

  void _inputChanged() {
    final origin = _origin;
    if (origin != null &&
        (_composing || widget.controller.text != origin.text)) {
      _cancel();
    }
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_inputChanged);
  }

  @override
  void didUpdateWidget(PaperHighlighter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_inputChanged);
      widget.controller.addListener(_inputChanged);
      _cancel();
    }
    if (!widget.choice.enabled) _cancel();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_inputChanged);
    _range.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerCancel: (_) => _cancel(),
    child: GestureDetector(
      // The editor below still receives taps and ordinary drag gestures.
      behavior: HitTestBehavior.translucent,
      excludeFromSemantics: true,
      onLongPressStart: _start,
      onLongPressMoveUpdate: (details) => _trace(details.globalPosition),
      onLongPressEnd: _end,
      onLongPressCancel: _cancel,
      child: IgnorePointer(
        child: ValueListenableBuilder(
          valueListenable: _range,
          builder: (context, range, _) => range == null
              ? const SizedBox.expand()
              : CustomPaint(
                  key: _paintKey,
                  painter: _StrokePainter(
                    surfaceKey: _paintKey,
                    editable: widget.editable,
                    range: range,
                    scroll: widget.scroll,
                    color: passageWashStyle(widget.choice).backgroundColor!,
                  ),
                  child: const SizedBox.expand(
                    key: ValueKey('paper-highlight-preview'),
                  ),
                ),
        ),
      ),
    ),
  );
}

class _StrokePainter extends CustomPainter {
  _StrokePainter({
    required this.surfaceKey,
    required this.editable,
    required this.range,
    required this.scroll,
    required this.color,
  }) : super(repaint: scroll);

  final GlobalKey surfaceKey;
  final EditableTextState? Function() editable;
  final TextRange range;
  final ScrollController scroll;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final render = editable()?.renderEditable;
    final surface = surfaceKey.currentContext?.findRenderObject();
    if (render == null || surface is! RenderBox) return;
    final boxes = render.getBoxesForSelection(
      TextSelection(baseOffset: range.start, extentOffset: range.end),
    );
    final origin = surface.globalToLocal(render.localToGlobal(Offset.zero));
    final ink = Paint()..color = color;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final box in boxes) {
      if (box.left == box.right) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          box.toRect().shift(origin),
          const Radius.circular(2),
        ),
        ink,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StrokePainter oldDelegate) =>
      range != oldDelegate.range || color != oldDelegate.color;
}
