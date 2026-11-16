import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../data/model.dart';
import 'paper.dart';
import 'paper_tool.dart';
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
    required this.tool,
  });

  final TextEditingController controller;
  final ScrollController scroll;
  final EditableTextState? Function() editable;
  final BookDetailChoice choice;
  final ValueChanged<TextRange> onStroke;
  final PaperTool tool;

  @override
  State<PaperHighlighter> createState() => _PaperHighlighterState();
}

class _PaperHighlighterState extends State<PaperHighlighter> {
  final _paintKey = GlobalKey();
  final _range = ValueNotifier<TextRange?>(null);
  ({TextRange character, String text})? _origin;
  int? _pointer;
  late Offset _startPosition;

  bool get _composing {
    final value = widget.controller.value;
    return value.isComposingRangeValid && !value.composing.isCollapsed;
  }

  void _start(PointerDownEvent event) {
    if (_pointer != null) {
      _cancel();
      return;
    }
    final render = widget.editable()?.renderEditable;
    if (event.buttons != kPrimaryButton || render == null || _composing) {
      return;
    }
    final point = event.position;
    final text = widget.controller.text;
    final offset = render.getPositionForPoint(point).offset;
    final character = _characterAt(render, point, offset, text);
    _pointer = event.pointer;
    _startPosition = point;
    if (character != null) _origin = (character: character, text: text);
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

  void _trace(PointerMoveEvent event) {
    if (_pointer != event.pointer) return;
    final origin = _origin;
    if (origin == null) {
      if ((event.position - _startPosition).distance >= 4) {
        _scrollBy(-event.delta.dy);
      }
      return;
    }
    final render = widget.editable()?.renderEditable;
    if (render == null) return;
    final previous = _range.value;
    if (previous == null && (event.position - _startPosition).distance < 4) {
      return;
    }
    final offset = render.getPositionForPoint(event.position).offset;
    final character = _characterAt(render, event.position, offset, origin.text);
    if (character == null) return;
    _range.value = TextRange(
      start: math.min(
        previous?.start ?? origin.character.start,
        character.start,
      ),
      end: math.max(previous?.end ?? origin.character.end, character.end),
    );
  }

  void _end(PointerUpEvent event) {
    if (_pointer != event.pointer) return;
    final range = _range.value;
    _cancel();
    if (range != null && !_composing) widget.onStroke(range);
  }

  void _scrollBy(double delta) {
    if (delta != 0 && widget.scroll.hasClients) {
      widget.scroll.position.pointerScroll(delta);
    }
  }

  void _cancel() {
    _pointer = null;
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
  }

  @override
  void dispose() {
    widget.controller.removeListener(_inputChanged);
    _range.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: _start,
    onPointerMove: _trace,
    onPointerUp: _end,
    onPointerCancel: (event) {
      if (_pointer == event.pointer) _cancel();
    },
    onPointerSignal: (event) {
      if (event is PointerScrollEvent && _pointer == null) {
        GestureBinding.instance.pointerSignalResolver.register(
          event,
          (_) => _scrollBy(event.scrollDelta.dy),
        );
      }
    },
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
                  color: widget.tool == PaperTool.eraser
                      ? muted
                      : passageWashStyle(widget.choice).backgroundColor!,
                  erasing: widget.tool == PaperTool.eraser,
                ),
                child: SizedBox.expand(
                  key: ValueKey(
                    widget.tool == PaperTool.eraser
                        ? 'paper-eraser-preview'
                        : 'paper-highlight-preview',
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
    required this.erasing,
  }) : super(repaint: scroll);

  final GlobalKey surfaceKey;
  final EditableTextState? Function() editable;
  final TextRange range;
  final ScrollController scroll;
  final Color color;
  final bool erasing;

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
    if (erasing) {
      ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
    }
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
      range != oldDelegate.range ||
      color != oldDelegate.color ||
      erasing != oldDelegate.erasing;
}
