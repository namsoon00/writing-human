import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/model.dart';
import '../source/originals.dart';
import 'paper.dart';

class SourceReading extends StatefulWidget {
  const SourceReading({
    super.key,
    required this.originals,
    this.match,
    this.onRegister,
    this.onRetry,
  });

  final List<RegisteredOriginal> originals;
  final OriginalMatch? match;
  final VoidCallback? onRegister;
  final VoidCallback? onRetry;

  @override
  State<SourceReading> createState() => _SourceReadingState();
}

class _SourceReadingState extends State<SourceReading> {
  late RegisteredOriginal? selected = widget.match?.original;

  @override
  Widget build(BuildContext context) {
    final original = selected;
    final match = original == widget.match?.original ? widget.match : null;
    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: .54,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            children: [
              Row(
                children: [
                  if (original != null)
                    IconButton(
                      tooltip: '원문 목록',
                      onPressed: () => setState(() => selected = null),
                      icon: const Icon(CupertinoIcons.chevron_left, size: 19),
                    ),
                  Expanded(
                    child: Text(
                      original?.citation.trim().isNotEmpty == true
                          ? original!.citation
                          : '원문',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (widget.onRegister != null)
                    TextButton(
                      onPressed: widget.onRegister,
                      child: const Text('원문 등록'),
                    ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(CupertinoIcons.xmark, size: 18),
                  ),
                ],
              ),
              const Divider(),
              if (widget.onRetry != null)
                TextButton(
                  onPressed: widget.onRetry,
                  child: const Text('저장 실패 · 다시 저장'),
                ),
              Expanded(
                child: original != null
                    ? _OriginalText(
                        key: ObjectKey(original),
                        original: original,
                        match: match,
                      )
                    : widget.originals.isEmpty
                    ? const Center(child: Text('등록한 원문이 없습니다.'))
                    : ListView.separated(
                        itemCount: widget.originals.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = widget.originals[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              item.text.isEmpty ? item.citation : item.text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: item.citation.isEmpty || item.text.isEmpty
                                ? null
                                : Text(
                                    item.citation,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            onTap: () => setState(() => selected = item),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OriginalText extends StatefulWidget {
  const _OriginalText({super.key, required this.original, this.match});

  final RegisteredOriginal original;
  final OriginalMatch? match;

  @override
  State<_OriginalText> createState() => _OriginalTextState();
}

class _OriginalTextState extends State<_OriginalText> {
  final scroll = ScrollController();
  bool positioned = false;

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.original.text;
    if (text.isEmpty) return const Center(child: Text('출처를 남긴 기록입니다.'));
    final match = widget.match;
    final style = writingTextStyle(0, size: 20, color: brandInk);
    final span = TextSpan(
      style: style,
      children: match == null
          ? [TextSpan(text: text)]
          : [
              TextSpan(text: text.substring(0, match.start)),
              TextSpan(
                text: text.substring(match.start, match.end),
                style: const TextStyle(backgroundColor: Color(0x30a78356)),
              ),
              TextSpan(text: text.substring(match.end)),
            ],
    );
    return LayoutBuilder(
      builder: (context, box) {
        if (!positioned && match != null) {
          positioned = true;
          final painter = TextPainter(
            text: span,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: box.maxWidth);
          final offset = painter
              .getOffsetForCaret(TextPosition(offset: match.start), Rect.zero)
              .dy;
          painter.dispose();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && scroll.hasClients) {
              scroll.jumpTo(
                (offset - box.maxHeight * .22).clamp(
                  0,
                  scroll.position.maxScrollExtent,
                ),
              );
            }
          });
        }
        return SingleChildScrollView(
          controller: scroll,
          padding: const EdgeInsets.only(bottom: 12),
          child: Text.rich(span, key: const ValueKey('source-reading-text')),
        );
      },
    );
  }
}
