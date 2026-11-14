import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../data/model.dart';
import 'paper.dart';
import 'book_details.dart';
import 'pencil_marks.dart';

typedef PageChoice = ({
  String? pageId,
  bool append,
  bool cover,
  bool backCover,
});

class PagesSheet extends StatelessWidget {
  const PagesSheet({
    super.key,
    required this.pages,
    required this.currentId,
    required this.style,
    required this.coverTitle,
    required this.coverVariant,
  });
  final List<WritingPage> pages;
  final String currentId;
  final WritingStyle style;
  final String? coverTitle;
  final int coverVariant;
  @override
  Widget build(BuildContext context) {
    final title = coverTitle;
    final coverOffset = title == null ? 0 : 1;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .65,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 12, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '페이지',
                      style: TextStyle(
                        fontFamily: appFontFamily,
                        fontFamilyFallback: appFontFallback,
                        fontSize: 21,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(CupertinoIcons.xmark, size: 18),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  childAspectRatio: .72,
                  mainAxisSpacing: 18,
                  crossAxisSpacing: 16,
                ),
                itemCount: pages.length + coverOffset * 2 + 1,
                itemBuilder: (context, index) {
                  if (title != null &&
                      (index == 0 || index == pages.length + 1)) {
                    final back = index != 0;
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pop(context, (
                        pageId: null,
                        append: false,
                        cover: true,
                        backCover: back,
                      )),
                      child: LayoutBuilder(
                        builder: (context, box) => Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ExcludeSemantics(
                              child: MediaQuery.withNoTextScaling(
                                child: BookCover(
                                  title: title,
                                  width: box.maxWidth * .72,
                                  variant: coverVariant,
                                  pageCount: pages.length,
                                  details: style.bookDetails,
                                  back: back,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              back ? '뒷표지' : '표지',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  if (index == pages.length + coverOffset * 2) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pop(context, (
                        pageId: null,
                        append: true,
                        cover: false,
                        backCover: false,
                      )),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: line),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.plus,
                              color: brandInk,
                              size: 25,
                            ),
                            SizedBox(height: 12),
                            Text(
                              '한 쪽 더',
                              style: TextStyle(color: brandInk, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final pageIndex = index - coverOffset;
                  final page = pages[pageIndex];
                  final number = pageIndex + 1;
                  final selected = page.id == currentId;
                  final excerpt = String.fromCharCodes(
                    page.text.runes.take(360),
                  );
                  return Semantics(
                    selected: selected,
                    label: '$number쪽${selected ? ', 현재 페이지' : ''}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pop(context, (
                        pageId: page.id,
                        append: false,
                        cover: false,
                        backCover: false,
                      )),
                      child: ExcludeSemantics(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: paperColors[style.paperIndex],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected ? brandInk : line,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: ClipRect(
                                        child: Align(
                                          alignment: Alignment.topLeft,
                                          child: Text.rich(
                                            pencilTextSpan(
                                              choice: style.bookDetails.pencil,
                                              value: TextEditingValue(
                                                text: excerpt.isEmpty
                                                    ? '빈 종이'
                                                    : excerpt,
                                              ),
                                              marks: page.pencilMarks,
                                            ),
                                            maxLines: 8,
                                            overflow: TextOverflow.clip,
                                            style: writingTextStyle(
                                              style.fontIndex,
                                              size: 12,
                                              color: excerpt.isEmpty
                                                  ? muted
                                                  : ink,
                                              useDevelopmentTypeface:
                                                  style.useDevelopmentTypeface,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    PageOrnament(
                                      choice: style.bookDetails.ornament,
                                      child: Text(
                                        '$number쪽${selected ? ' · 현재' : ''}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: brandInk,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selected)
                                Positioned(
                                  right: 12,
                                  top: 0,
                                  child: RibbonBookmark(
                                    width: 10,
                                    height: 25,
                                    choice: style.bookDetails.ribbon,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
