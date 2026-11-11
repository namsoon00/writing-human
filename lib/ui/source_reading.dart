import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../data/model.dart';
import '../source/source_intake.dart';
import 'paper.dart';

typedef SourceReadingResult = ({int paragraph, bool follow, bool edit});

class SourceReading extends StatefulWidget {
  const SourceReading({
    super.key,
    required this.title,
    required this.source,
    required this.paragraphIndex,
    required this.style,
    this.coverIndex,
  });

  final String title, source;
  final int paragraphIndex;
  final int? coverIndex;
  final WritingStyle style;

  @override
  State<SourceReading> createState() => _SourceReadingState();
}

class _SourceReadingState extends State<SourceReading> {
  late final List<String> paragraphs = splitSourceParagraphs(widget.source);
  late int index = widget.paragraphIndex.clamp(0, paragraphs.length - 1);

  void _finish({bool follow = false, bool edit = false}) =>
      Navigator.pop(context, (paragraph: index, follow: follow, edit: edit));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: appPaper,
    body: PaperBackdrop(
      color: paperColors[widget.style.paperIndex],
      grainOpacity: paperGrainOpacity[widget.style.paperIndex],
      binding: widget.style.bookDetails.binding,
      coverIndex: widget.coverIndex,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final margins = writingPagePadding(box.biggest);
            return Column(
              children: [
                Row(
                  children: [
                    TextButton(onPressed: _finish, child: const Text('닫기')),
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: brandInk),
                      ),
                    ),
                    IconButton(
                      tooltip: '원문 편집',
                      onPressed: () => _finish(edit: true),
                      icon: const Icon(CupertinoIcons.pencil, size: 18),
                    ),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    key: ValueKey(index),
                    padding: EdgeInsets.fromLTRB(
                      margins.left,
                      12,
                      margins.right,
                      margins.bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Divider(color: line),
                        const SizedBox(height: 12),
                        const Text('원문', style: TextStyle(color: brandInk)),
                        const SizedBox(height: 20),
                        Text(
                          paragraphs[index],
                          key: const ValueKey('source-reading-paragraph'),
                          style: writingTextStyle(
                            widget.style.fontIndex,
                            useDevelopmentTypeface:
                                widget.style.useDevelopmentTypeface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (paragraphs.length > 1) ...[
                      IconButton(
                        tooltip: '이전 문단',
                        onPressed: index > 0
                            ? () => setState(() => index--)
                            : null,
                        icon: const Icon(CupertinoIcons.chevron_left, size: 16),
                      ),
                      Text('문단 ${index + 1} / ${paragraphs.length}'),
                      IconButton(
                        tooltip: '다음 문단',
                        onPressed: index + 1 < paragraphs.length
                            ? () => setState(() => index++)
                            : null,
                        icon: const Icon(
                          CupertinoIcons.chevron_right,
                          size: 16,
                        ),
                      ),
                    ],
                    TextButton(
                      onPressed: () => _finish(follow: true),
                      child: const Text('따라 쓰기'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class PagePassageSheet extends StatefulWidget {
  const PagePassageSheet({super.key, this.passage});
  final PagePassage? passage;

  @override
  State<PagePassageSheet> createState() => _PagePassageSheetState();
}

class _PagePassageSheetState extends State<PagePassageSheet> {
  late final source = TextEditingController(text: widget.passage?.source);
  late final citation = TextEditingController(text: widget.passage?.citation);
  String? citationError;

  @override
  void dispose() {
    source.dispose();
    citation.dispose();
    super.dispose();
  }

  void _save() {
    final label = citation.text.trim();
    if (label.length > 500) {
      setState(() => citationError = '출처를 조금 줄여 주세요.');
      return;
    }
    Navigator.pop(context, (
      source: normalizeSource(source.text),
      citation: label,
    ));
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.passage == null ? '필사 추가' : '원문 편집',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('passage-source'),
            controller: source,
            minLines: 3,
            maxLines: 5,
            maxLength: sourceLengthLimit,
            decoration: const InputDecoration(labelText: '원문'),
          ),
          TextField(
            key: const ValueKey('passage-citation'),
            controller: citation,
            maxLength: 500,
            onChanged: (_) {
              if (citationError != null) setState(() => citationError = null);
            },
            decoration: InputDecoration(
              labelText: '출처',
              errorText: citationError,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: _save,
                child: Text(widget.passage == null ? '이 줄에서 시작' : '저장'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
