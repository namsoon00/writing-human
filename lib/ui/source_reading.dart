import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/book_detail_style.dart';
import '../source/source_intake.dart';
import 'book_details.dart';
import 'paper_palette.dart';

/// A reading pane above the independent writing field.
class SourceReading extends StatefulWidget {
  const SourceReading({
    super.key,
    required this.source,
    required this.choice,
    required this.paragraphIndex,
    required this.maxTextHeight,
    required this.compact,
    required this.writing,
    this.guiding = false,
    this.onParagraphChanged,
    this.onEdit,
    this.onToggleGuide,
  });

  final String source;
  final BookDetailChoice choice;
  final int paragraphIndex;
  final double maxTextHeight;
  final bool compact, writing, guiding;
  final void Function(int index, String paragraph)? onParagraphChanged;
  final VoidCallback? onEdit;
  final ValueChanged<String>? onToggleGuide;

  @override
  State<SourceReading> createState() => _SourceReadingState();
}

class _SourceReadingState extends State<SourceReading> {
  late List<String> _paragraphs = splitSourceParagraphs(widget.source);

  @override
  void didUpdateWidget(SourceReading oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _paragraphs = splitSourceParagraphs(widget.source);
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.paragraphIndex.clamp(0, _paragraphs.length - 1);
    final paragraph = _paragraphs[index];
    final toolbar = Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('toggle-transcription-guide'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                foregroundColor: brandInk,
                minimumSize: const Size(0, 48),
              ),
              onPressed: widget.onToggleGuide == null
                  ? null
                  : () => widget.onToggleGuide!(paragraph),
              child: Text(widget.guiding ? '원문 보기' : '따라 쓰기'),
            ),
          ),
        ),
        if (_paragraphs.length > 1) ...[
          IconButton(
            tooltip: '이전 문단',
            onPressed: index > 0 && widget.onParagraphChanged != null
                ? () => widget.onParagraphChanged!(
                    index - 1,
                    _paragraphs[index - 1],
                  )
                : null,
            icon: const Icon(CupertinoIcons.chevron_left, size: 16),
          ),
          IconButton(
            tooltip: '다음 문단',
            onPressed:
                index + 1 < _paragraphs.length &&
                    widget.onParagraphChanged != null
                ? () => widget.onParagraphChanged!(
                    index + 1,
                    _paragraphs[index + 1],
                  )
                : null,
            icon: const Icon(CupertinoIcons.chevron_right, size: 16),
          ),
        ],
        if (!widget.guiding)
          IconButton(
            tooltip: '원문 편집',
            onPressed: widget.onEdit,
            icon: const Icon(CupertinoIcons.pencil, size: 17),
          ),
      ],
    );
    return TextFieldTapRegion(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: widget.guiding
            ? toolbar
            : SourceSlip(
                choice: widget.choice,
                compact: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    toolbar,
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: _paragraphs.length > 1
                            ? widget.maxTextHeight
                            : 0,
                        maxHeight: widget.maxTextHeight,
                      ),
                      child: SingleChildScrollView(
                        key: ValueKey((widget.source, index)),
                        primary: false,
                        child: Text(
                          paragraph,
                          key: const ValueKey('source-reading-paragraph'),
                          style: TextStyle(
                            fontFamily: appFontFamily,
                            fontFamilyFallback: appFontFallback,
                            color: widget.writing
                                ? const Color(0xff655648)
                                : ink,
                            fontSize: widget.compact ? 16 : 19,
                            height: 1.65,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
