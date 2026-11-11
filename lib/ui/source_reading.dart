import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/book_detail_style.dart';
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
    this.onParagraphChanged,
    this.onEdit,
  });

  final String source;
  final BookDetailChoice choice;
  final int paragraphIndex;
  final double maxTextHeight;
  final bool compact, writing;
  final ValueChanged<int>? onParagraphChanged;
  final VoidCallback? onEdit;

  @override
  State<SourceReading> createState() => _SourceReadingState();
}

class _SourceReadingState extends State<SourceReading> {
  static final _paragraphBreak = RegExp(r'\n[^\S\n]*\n(?:[^\S\n]*\n)*');
  late List<String> _paragraphs = _readParagraphs();

  List<String> _readParagraphs() => widget.source
      .trim()
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split(_paragraphBreak);

  @override
  void didUpdateWidget(SourceReading oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) _paragraphs = _readParagraphs();
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.paragraphIndex.clamp(0, _paragraphs.length - 1);
    return TextFieldTapRegion(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: SourceSlip(
          choice: widget.choice,
          compact: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _paragraphs.length == 1
                          ? '원문'
                          : '원문  ${index + 1} / ${_paragraphs.length}',
                      key: const ValueKey('source-reading-position'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                  ),
                  if (_paragraphs.length > 1) ...[
                    IconButton(
                      tooltip: '이전 문단',
                      onPressed: index > 0 && widget.onParagraphChanged != null
                          ? () => widget.onParagraphChanged!(index - 1)
                          : null,
                      icon: const Icon(CupertinoIcons.chevron_left, size: 16),
                    ),
                    IconButton(
                      tooltip: '다음 문단',
                      onPressed:
                          index + 1 < _paragraphs.length &&
                              widget.onParagraphChanged != null
                          ? () => widget.onParagraphChanged!(index + 1)
                          : null,
                      icon: const Icon(CupertinoIcons.chevron_right, size: 16),
                    ),
                  ],
                  IconButton(
                    tooltip: '원문 편집',
                    onPressed: widget.onEdit,
                    icon: const Icon(CupertinoIcons.pencil, size: 17),
                  ),
                ],
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: _paragraphs.length > 1 ? widget.maxTextHeight : 0,
                  maxHeight: widget.maxTextHeight,
                ),
                child: SingleChildScrollView(
                  key: ValueKey((widget.source, index)),
                  primary: false,
                  child: Text(
                    _paragraphs[index],
                    key: const ValueKey('source-reading-paragraph'),
                    style: TextStyle(
                      fontFamily: appFontFamily,
                      fontFamilyFallback: appFontFallback,
                      color: widget.writing ? const Color(0xff655648) : ink,
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
