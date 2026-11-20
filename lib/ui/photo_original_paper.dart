import 'dart:async';
import 'dart:ui' show BoxHeightStyle;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Selects the document on the paper, away from the platform text input.
class PhotoOriginalPaper extends StatefulWidget {
  const PhotoOriginalPaper({
    super.key,
    required this.text,
    required this.selection,
    required this.style,
    required this.ink,
    required this.onSelection,
  });

  final String text;
  final TextSelection selection;
  final TextStyle style;
  final Color ink;
  final ValueChanged<TextSelection>? onSelection;

  @override
  State<PhotoOriginalPaper> createState() => _PhotoOriginalPaperState();
}

class _PhotoOriginalPaperState extends State<PhotoOriginalPaper> {
  static const _inset = 22.0;
  static const _target = 44.0;
  final _sheet = GlobalKey();
  final _layout = TextPainter();
  Timer? _autoScroll;
  void Function(Offset)? _drag;
  Offset? _pointer;

  RenderBox? get _box =>
      _sheet.currentContext?.findRenderObject() as RenderBox?;

  Offset _textPoint(Offset pointer) =>
      _box!.globalToLocal(pointer) - const Offset(0, _inset);

  TextPosition _position(Offset pointer) =>
      _layout.getPositionForOffset(_textPoint(pointer));

  TextRange _word(Offset pointer) {
    final point = _textPoint(pointer);
    final glyph = _layout.getClosestGlyphForOffset(point);
    if (glyph == null ||
        !glyph.graphemeClusterLayoutBounds.inflate(1).contains(point)) {
      return TextRange.empty;
    }
    final word = _layout.getWordBoundary(
      TextPosition(offset: glyph.graphemeClusterCodeUnitRange.start),
    );
    return word.textInside(widget.text).trim().isEmpty ? TextRange.empty : word;
  }

  void _tap(Offset pointer) {
    final word = _word(pointer);
    final selection = widget.selection;
    final sameWord = word.start == selection.start && word.end == selection.end;
    widget.onSelection?.call(
      !word.isValid || sameWord
          ? TextSelection.collapsed(offset: _position(pointer).offset)
          : TextSelection(baseOffset: word.start, extentOffset: word.end),
    );
  }

  void _startPassage(Offset pointer) {
    final word = _word(pointer);
    if (!word.isValid) return;
    widget.onSelection?.call(
      TextSelection(baseOffset: word.start, extentOffset: word.end),
    );
    _drag = (pointer) {
      final position = _position(pointer);
      final wordAtPointer = _word(pointer);
      final before = position.offset < word.start;
      widget.onSelection?.call(
        TextSelection(
          baseOffset: before ? word.end : word.start,
          extentOffset: !wordAtPointer.isValid
              ? position.offset
              : before
              ? wordAtPointer.start
              : wordAtPointer.end,
        ),
      );
    };
    _pointer = pointer;
  }

  void _move(Offset pointer) {
    if (_drag == null) return;
    _pointer = pointer;
    _drag!(pointer);
    _autoScroll ??= Timer.periodic(
      const Duration(milliseconds: 36),
      _scrollAtEdge,
    );
  }

  void _scrollAtEdge(Timer timer) {
    final box = _box;
    final pointer = _pointer;
    if (box == null || pointer == null) return;
    final viewport = RenderAbstractViewport.maybeOf(box) as RenderBox?;
    final scroll = Scrollable.maybeOf(context)?.position;
    if (viewport == null || scroll == null || !scroll.hasContentDimensions) {
      return;
    }
    final y = viewport.globalToLocal(pointer).dy;
    const margin = 36.0;
    final distance = y < margin
        ? y - margin
        : y > viewport.size.height - margin
        ? y - (viewport.size.height - margin)
        : 0.0;
    final next = (scroll.pixels + distance.clamp(-32, 32) / 3).clamp(
      scroll.minScrollExtent,
      scroll.maxScrollExtent,
    );
    if (next == scroll.pixels) return;
    scroll.jumpTo(next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pointer = _pointer;
      if (mounted && _box?.attached == true && pointer != null) {
        _drag?.call(pointer);
      }
    });
  }

  void _stop() {
    _autoScroll?.cancel();
    _autoScroll = null;
    _pointer = null;
    _drag = null;
  }

  void _setBoundary(bool start, int offset) {
    final selection = widget.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    final boundary = CharacterBoundary(widget.text);
    final next = start
        ? offset.clamp(
            0,
            boundary.getLeadingTextBoundaryAt(selection.end - 1) ?? 0,
          )
        : offset.clamp(
            boundary.getTrailingTextBoundaryAt(selection.start) ??
                widget.text.length,
            widget.text.length,
          );
    widget.onSelection?.call(
      TextSelection(
        baseOffset: start ? next : selection.start,
        extentOffset: start ? selection.end : next,
      ),
    );
  }

  void _nudge(bool start, int direction) {
    final selection = widget.selection;
    final offset = start ? selection.start : selection.end;
    final boundary = CharacterBoundary(widget.text);
    final next = direction < 0
        ? boundary.getLeadingTextBoundaryAt(offset - 1) ?? 0
        : boundary.getTrailingTextBoundaryAt(offset) ?? widget.text.length;
    _setBoundary(start, next);
  }

  Widget _handle(bool start, Offset stem, double lineHeight, double width) {
    final center = stem + Offset(0, start ? -7 : 7);
    final enabled = widget.onSelection != null;
    return Positioned(
      left: (center.dx - _target / 2).clamp(
        0.0,
        (width - _target).clamp(0.0, width),
      ),
      top: center.dy - _target / 2,
      width: _target,
      height: _target,
      child: Semantics(
        label: start ? '선택 시작' : '선택 끝',
        onIncrease: enabled ? () => _nudge(start, 1) : null,
        onDecrease: enabled ? () => _nudge(start, -1) : null,
        child: GestureDetector(
          key: ValueKey(
            start ? 'photo-selection-start' : 'photo-selection-end',
          ),
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: !enabled
              ? null
              : (details) {
                  // Keep the finger below or above the text while dragging.
                  final anchor = _box!.localToGlobal(
                    stem + Offset(0, (start ? .5 : -.5) * lineHeight),
                  );
                  final grip = details.globalPosition - anchor;
                  _drag = (pointer) =>
                      _setBoundary(start, _position(pointer - grip).offset);
                },
          onPanUpdate: !enabled
              ? null
              : (details) => _move(details.globalPosition),
          onPanEnd: (_) => _stop(),
          onPanCancel: _stop,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stop();
    _layout.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final direction = Directionality.of(context);
      final scaler = MediaQuery.textScalerOf(context);
      final span = TextSpan(text: widget.text, style: widget.style);
      _layout
        ..text = span
        ..textDirection = direction
        ..textScaler = scaler
        ..layout(maxWidth: constraints.maxWidth);
      final selection = widget.selection;
      final hasSelection =
          selection.isValid &&
          !selection.isCollapsed &&
          selection.end <= widget.text.length;
      const origin = Offset(0, _inset);
      final startPosition = TextPosition(
        offset: selection.isValid ? selection.start : 0,
      );
      final start = hasSelection
          ? origin + _layout.getOffsetForCaret(startPosition, Rect.zero)
          : null;
      final endPosition = TextPosition(
        offset: selection.isValid ? selection.end : 0,
        affinity: TextAffinity.upstream,
      );
      final end = hasSelection
          ? origin +
                _layout.getOffsetForCaret(endPosition, Rect.zero) +
                Offset(0, _layout.getFullHeightForCaret(endPosition, Rect.zero))
          : null;
      final rects = hasSelection
          ? _layout
                .getBoxesForSelection(
                  selection,
                  boxHeightStyle: BoxHeightStyle.tight,
                )
                .map((box) => box.toRect().shift(origin).inflate(1))
                .toList(growable: false)
          : const <Rect>[];
      final enabled = widget.onSelection != null && widget.text.isNotEmpty;
      return Stack(
        key: _sheet,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SelectionInk(rects, start, end, widget.ink),
            ),
          ),
          Semantics(
            customSemanticsActions: enabled
                ? {
                    const CustomSemanticsAction(label: '전체 선택'): () =>
                        widget.onSelection?.call(
                          TextSelection(
                            baseOffset: 0,
                            extentOffset: widget.text.length,
                          ),
                        ),
                  }
                : null,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTapUp: enabled
                  ? (details) => _tap(details.globalPosition)
                  : null,
              onLongPressStart: enabled
                  ? (details) => _startPassage(details.globalPosition)
                  : null,
              onLongPressMoveUpdate: enabled
                  ? (details) => _move(details.globalPosition)
                  : null,
              onLongPressEnd: enabled ? (_) => _stop() : null,
              onLongPressCancel: enabled ? _stop : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: _inset),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 120),
                  child: Text(
                    widget.text,
                    style: widget.style,
                    textScaler: scaler,
                  ),
                ),
              ),
            ),
          ),
          if (start != null)
            _handle(
              true,
              start,
              _layout.getFullHeightForCaret(startPosition, Rect.zero),
              constraints.maxWidth,
            ),
          if (end != null)
            _handle(
              false,
              end,
              _layout.getFullHeightForCaret(endPosition, Rect.zero),
              constraints.maxWidth,
            ),
        ],
      );
    },
  );
}

class _SelectionInk extends CustomPainter {
  const _SelectionInk(this.boxes, this.start, this.end, this.ink);

  final List<Rect> boxes;
  final Offset? start, end;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final highlight = Paint()..color = ink.withValues(alpha: .18);
    for (final box in boxes) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(3)),
        highlight,
      );
    }
    final mark = Paint()
      ..color = ink
      ..strokeWidth = 1.5;
    if (start case final point?) _drawHandle(canvas, point, -7, mark);
    if (end case final point?) _drawHandle(canvas, point, 7, mark);
  }

  void _drawHandle(Canvas canvas, Offset stem, double dy, Paint mark) {
    final dot = stem + Offset(0, dy);
    canvas.drawLine(stem, dot, mark);
    canvas.drawCircle(dot, 5.5, mark);
  }

  @override
  bool shouldRepaint(_SelectionInk oldDelegate) =>
      ink != oldDelegate.ink ||
      start != oldDelegate.start ||
      end != oldDelegate.end ||
      !listEquals(boxes, oldDelegate.boxes);
}

/// Provides the keyboard and IME on the same sheet while correcting text.
class PhotoOriginalCorrection extends StatefulWidget {
  const PhotoOriginalCorrection({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.style,
    required this.ink,
    required this.readOnly,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle style;
  final Color ink;
  final bool readOnly;

  @override
  State<PhotoOriginalCorrection> createState() =>
      _PhotoOriginalCorrectionState();
}

class _PhotoOriginalCorrectionState extends State<PhotoOriginalCorrection> {
  final _editable = GlobalKey<EditableTextState>();

  void _placeCursor(TapUpDetails details) {
    final state = _editable.currentState;
    if (state == null || widget.readOnly) return;
    // Keep the IME in charge while Korean text is being composed.
    final value = widget.controller.value;
    if (value.composing.isCollapsed || !value.isComposingRangeValid) {
      final position = state.renderEditable.getPositionForPoint(
        details.globalPosition,
      );
      state.userUpdateTextEditingValue(
        value.copyWith(
          selection: TextSelection.fromPosition(position),
          composing: TextRange.empty,
        ),
        SelectionChangedCause.tap,
      );
    }
    state.requestKeyboard();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 22),
    child: Semantics(
      enabled: !widget.readOnly,
      onFocus: widget.readOnly
          ? null
          : () => _editable.currentState?.requestKeyboard(),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        excludeFromSemantics: true,
        onTapUp: _placeCursor,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 120),
          child: EditableText(
            key: _editable,
            controller: widget.controller,
            focusNode: widget.focusNode,
            style: widget.style,
            cursorColor: widget.ink,
            backgroundCursorColor: Colors.transparent,
            selectionColor: widget.ink.withValues(alpha: .18),
            readOnly: widget.readOnly,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            contextMenuBuilder: (_, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    ),
  );
}
