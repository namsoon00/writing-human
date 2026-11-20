import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;

import '../data/model.dart';
import '../source/transcription_comparison.dart';
import '../source/photo_lines.dart';
import 'paper.dart';
import 'original_photo.dart';

/// Scrolls the selected original independently of the editable paper.
class TranscriptionReference extends StatefulWidget {
  const TranscriptionReference({
    super.key,
    required this.original,
    required this.comparison,
    required this.photoPanelColor,
    required this.controller,
    required this.style,
    this.onSavePhotoRegion,
  });

  final RegisteredOriginal original;
  final TranscriptionComparison? comparison;
  final Color photoPanelColor;
  final TextEditingController controller;
  final TextStyle style;
  final Future<bool> Function(List<double>?)? onSavePhotoRegion;

  @override
  State<TranscriptionReference> createState() => _TranscriptionReferenceState();
}

class _TranscriptionReferenceState extends State<TranscriptionReference> {
  final _scroll = ScrollController(keepScrollOffset: false);
  final _paragraph = GlobalKey();
  Object? _lastPosition;
  bool _showPhoto = false;

  @override
  void didUpdateWidget(TranscriptionReference oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.original.id != widget.original.id) _showPhoto = false;
  }

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

  void _openPhoto(String id, List<double>? region) => showOriginalPhoto(
    context,
    id,
    color: widget.photoPanelColor,
    region: region,
    onSaveRegion: widget.onSavePhotoRegion,
  );

  @override
  Widget build(BuildContext context) {
    final source = widget.original;
    final region = originalPhotoPreviewRegion(source);
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
          child: source.photoId == null
              ? _textReference(passage, scaler)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxHeight < 132;
                    final showingPhoto = _showPhoto || passage.isEmpty;
                    final canSwitch = passage.isNotEmpty;
                    final switchLabel = _showPhoto ? '글 보기' : '사진 보기';
                    void toggle() => setState(() => _showPhoto = !_showPhoto);
                    void open() => _openPhoto(source.photoId!, region);

                    return TextFieldTapRegion(
                      child: Flex(
                        direction: compact ? Axis.horizontal : Axis.vertical,
                        textDirection: compact ? TextDirection.rtl : null,
                        children: [
                          if (compact)
                            SizedBox(
                              width: 42,
                              height: constraints.maxHeight,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (canSwitch)
                                    Flexible(
                                      child: IconButton(
                                        tooltip: switchLabel,
                                        onPressed: toggle,
                                        icon: Icon(
                                          _showPhoto
                                              ? CupertinoIcons.text_alignleft
                                              : CupertinoIcons.photo,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  Flexible(
                                    child: IconButton(
                                      tooltip: '사진 크게 보기',
                                      onPressed: open,
                                      icon: const Icon(
                                        CupertinoIcons
                                            .arrow_up_left_arrow_down_right,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Wrap(
                              children: [
                                if (canSwitch)
                                  TextButton(
                                    onPressed: toggle,
                                    child: Text(switchLabel),
                                  ),
                                TextButton(
                                  onPressed: open,
                                  child: const Text('사진 크게 보기'),
                                ),
                              ],
                            ),
                          Expanded(
                            child: showingPhoto
                                ? OriginalPhoto(
                                    id: source.photoId!,
                                    region: region,
                                    fitWidth: true,
                                  )
                                : _textReference(passage, scaler),
                          ),
                        ],
                      ),
                    );
                  },
                ),
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
