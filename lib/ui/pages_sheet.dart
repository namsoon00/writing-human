import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../data/model.dart';
import 'paper.dart';

typedef PageChoice = ({String? pageId, bool append});

class PagesSheet extends StatelessWidget {
  const PagesSheet({
    super.key,
    required this.pages,
    required this.currentId,
    required this.style,
  });
  final List<WritingPage> pages;
  final String currentId;
  final WritingStyle style;
  @override
  Widget build(BuildContext context) => SafeArea(
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
              itemCount: pages.length + 1,
              itemBuilder: (context, index) {
                if (index == pages.length) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () =>
                        Navigator.pop(context, (pageId: null, append: true)),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: line),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.plus, color: brandInk, size: 25),
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
                final page = pages[index];
                final selected = page.id == currentId;
                final excerpt = String.fromCharCodes(page.text.runes.take(360));
                return Semantics(
                  selected: selected,
                  label: '${page.number}쪽${selected ? ', 현재 페이지' : ''}',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pop(context, (
                      pageId: page.id,
                      append: false,
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
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Expanded(
                                child: ClipRect(
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: Text(
                                      excerpt.isEmpty ? '빈 종이' : excerpt,
                                      maxLines: 8,
                                      overflow: TextOverflow.clip,
                                      style: writingTextStyle(
                                        style.fontIndex,
                                        size: 12,
                                        color: excerpt.isEmpty ? muted : ink,
                                        useDevelopmentTypeface:
                                            style.useDevelopmentTypeface,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${page.number}쪽${selected ? ' · 현재' : ''}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: brandInk,
                                ),
                              ),
                            ],
                          ),
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
