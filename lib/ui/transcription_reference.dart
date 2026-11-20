import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;

import '../data/model.dart';
import '../source/transcription_comparison.dart';
import 'paper.dart';
import 'original_photo.dart';

/// Scrolls the selected original independently of the editable paper.
class TranscriptionReference extends StatefulWidget {
  const TranscriptionReference({
    super.key,
    required this.original,
    required this.comparison,
    this.onOpen,
    this.startOffset = 0,
    this.sourceOffset = 0,
    this.endOffset,
    required this.controller,
    required this.style,
  });

  final RegisteredOriginal original;
  final TranscriptionComparison? comparison;
  final VoidCallback? onOpen;
  final int startOffset, sourceOffset;
  final int? endOffset;
  final TextEditingController controller;
  final TextStyle style;

  static const _verticalPadding = 4.0;

  static StrutStyle _strut(TextStyle style) =>
      StrutStyle.fromTextStyle(style, forceStrutHeight: true);

  static double heightForText({
    required TextStyle style,
    required TextScaler scaler,
    required double availableHeight,
  }) {
    final measure = TextPainter(
      text: TextSpan(style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      strutStyle: _strut(style),
    );
    final lineHeight = measure.preferredLineHeight;
    measure.dispose();
    final padding = _verticalPadding * 2;
    final lines = ((availableHeight - padding) / lineHeight).floor().clamp(
      0,
      4,
    );
    return lines == 0 ? 0 : lineHeight * lines + padding;
  }

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
    final reference = DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: line)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: TranscriptionReference._verticalPadding,
        ),
        child: Semantics(
          label: '따라 쓰는 원문',
          button: widget.onOpen != null,
          onTap: widget.onOpen,
          child: TextFieldTapRegion(
            child: passage.isEmpty
                ? (source.photoId == null
                      ? SingleChildScrollView(
                          child: Text(source.citation, style: widget.style),
                        )
                      : OriginalPhoto(
                          id: source.photoId!,
                          region: source.photoRegion,
                          fitWidth: true,
                        ))
                : source.photoId == null
                ? _textReference(passage, scaler)
                : LayoutBuilder(
                    builder: (context, box) {
                      // Keep the complete text line in the smallest keyboard layouts.
                      if (box.maxHeight < 48) {
                        return _textReference(passage, scaler);
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            key: const ValueKey('reference-photo'),
                            width: math.min(88, box.maxWidth * .24),
                            child: Semantics(
                              button: true,
                              label: '원문 사진 크게 보기',
                              child: InkWell(
                                onTap: () {
                                  final value = widget.controller.value;
                                  if (value.isComposingRangeValid &&
                                      !value.composing.isCollapsed) {
                                    return;
                                  }
                                  FocusScope.of(context).unfocus();
                                  showOriginalPhoto(
                                    context,
                                    source.photoId!,
                                    color: originalPanelColor,
                                    region: source.photoRegion,
                                  );
                                },
                                child: ClipRect(
                                  child: OriginalPhoto(
                                    id: source.photoId!,
                                    region: source.photoRegion,
                                    compact: true,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: _textReference(passage, scaler)),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: widget.onOpen,
      child: reference,
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
            (widget.sourceOffset +
                    (widget.comparison?.sourceOffsetFor(
                          value.text.substring(
                            widget.startOffset.clamp(0, value.text.length),
                            committed.clamp(
                              widget.startOffset.clamp(0, value.text.length),
                              widget.endOffset ?? value.text.length,
                            ),
                          ),
                        ) ??
                        0))
                .clamp(0, passage.length);
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
            strutStyle: TranscriptionReference._strut(widget.style),
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
