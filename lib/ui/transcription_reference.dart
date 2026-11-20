import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;

import '../data/model.dart';
import '../source/transcription_comparison.dart';
import 'paper.dart';

/// Scrolls the selected original independently of the editable paper.
class TranscriptionReference extends StatefulWidget {
  const TranscriptionReference({
    super.key,
    required this.original,
    required this.comparison,
    required this.controller,
    required this.style,
  });

  final RegisteredOriginal original;
  final TranscriptionComparison? comparison;
  final TextEditingController controller;
  final TextStyle style;

  @override
  State<TranscriptionReference> createState() => _TranscriptionReferenceState();
}

class _TranscriptionReferenceState extends State<TranscriptionReference> {
  final _scroll = ScrollController(keepScrollOffset: false);
  final _paragraph = GlobalKey();
  Object? _lastPosition;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _follow(int offset, Object position) {
    if (position == _lastPosition) return;
    _lastPosition = position;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || position != _lastPosition) return;
      final paragraph = _paragraph.currentContext?.findRenderObject();
      if (paragraph is! RenderParagraph || !paragraph.hasSize) return;
      final top = paragraph
          .getOffsetForCaret(TextPosition(offset: offset), Rect.zero)
          .dy;
      final target = top.clamp(0.0, _scroll.position.maxScrollExtent);
      if ((_scroll.offset - target).abs() > 0.5) _scroll.jumpTo(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.original;
    final passage = source.text
        .substring(source.writingRange?.start ?? 0, source.writingRange?.end)
        .trimLeft();
    final scaler = MediaQuery.textScalerOf(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: line)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Semantics(
          label: '따라 쓰는 원문',
          child: TextFieldTapRegion(child: _textReference(passage, scaler)),
        ),
      ),
    );
  }

  Widget _textReference(String passage, TextScaler scaler) => LayoutBuilder(
    builder: (context, constraints) => ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final caret = value.selection.extentOffset.clamp(0, value.text.length);
        final committed =
            value.isComposingRangeValid && !value.composing.isCollapsed
            ? math.min(caret, value.composing.start)
            : caret;
        final offset =
            widget.comparison?.sourceOffsetFor(
              value.text.substring(0, committed),
            ) ??
            0;
        if (widget.comparison != null) {
          _follow(offset, (
            offset,
            passage,
            constraints.biggest,
            scaler,
            widget.style,
          ));
        }
        return SingleChildScrollView(
          controller: _scroll,
          primary: false,
          child: RichText(
            key: _paragraph,
            textScaler: scaler,
            text: TextSpan(
              style: widget.style,
              children: [
                TextSpan(
                  text: passage.substring(0, offset),
                  style: const TextStyle(color: muted),
                ),
                TextSpan(text: passage.substring(offset)),
              ],
            ),
          ),
        );
      },
    ),
  );
}
