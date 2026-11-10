import 'package:flutter/material.dart';
import '../data/model.dart';
import 'paper.dart';
import 'pencil_marks.dart';

/// A painted neighbour, never another editor or a source of save events.
class PageReadPreview extends StatefulWidget {
  const PageReadPreview({super.key, required this.page, required this.style});
  final WritingPage page;
  final WritingStyle style;
  @override
  State<PageReadPreview> createState() => _PageReadPreviewState();
}

class _PageReadPreviewState extends State<PageReadPreview> {
  late final scroll = ScrollController(initialScrollOffset: widget.page.scroll);
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final padding = writingPagePadding(constraints.biggest);
      final style = widget.style;
      final empty = widget.page.text.isEmpty;
      return ClipRect(
        child: Stack(
          children: [
            if (style.guides)
              Positioned.fill(
                child: CustomPaint(
                  painter: WritingGuides(
                    enabled: true,
                    top: padding.top,
                    left: padding.left,
                    right: padding.right,
                    lineHeight:
                        MediaQuery.textScalerOf(context).scale(23) * 1.8,
                    scroll: widget.page.scroll,
                  ),
                ),
              ),
            SingleChildScrollView(
              controller: scroll,
              physics: const NeverScrollableScrollPhysics(),
              padding: padding,
              child: SizedBox(
                width: double.infinity,
                child: Text.rich(
                  empty
                      ? const TextSpan(text: '마음에 남은 문장을\n천천히 옮겨 적어보세요.')
                      : pencilTextSpan(
                          value: TextEditingValue(text: widget.page.text),
                          marks: widget.page.pencilMarks,
                          choice: style.bookDetails.pencil,
                        ),
                  key: ValueKey('page-preview-text:${widget.page.id}'),
                  style: writingTextStyle(
                    style.fontIndex,
                    size: empty ? 21 : 23,
                    color: empty ? muted : penColors[style.penIndex],
                    useDevelopmentTypeface: style.useDevelopmentTypeface,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
