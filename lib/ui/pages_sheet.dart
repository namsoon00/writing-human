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
    required this.onChoose,
    required this.canTrash,
    required this.onTrash,
  });
  final List<WritingPage> pages;
  final String currentId;
  final WritingStyle style;
  final String? coverTitle;
  final int coverVariant;
  final ValueChanged<PageChoice> onChoose;
  final bool Function(WritingPage) canTrash;
  final Future<bool> Function(WritingPage) onTrash;

  Future<void> _confirmTrash(
    BuildContext context,
    WritingPage page,
    int number,
  ) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _TrashPageDialog(
      page: page,
      number: number,
      onTrash: () => onTrash(page),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final title = coverTitle;
    final coverOffset = title == null ? 0 : 1;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 12, 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '쪽 목록',
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
              if (title != null && (index == 0 || index == pages.length + 1)) {
                final back = index != 0;
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onChoose((
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
                  onTap: () => onChoose((
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
              final pageIndex = index - coverOffset;
              final page = pages[pageIndex];
              final number = pageIndex + 1;
              final selected = page.id == currentId;
              final excerpt = String.fromCharCodes(page.text.runes.take(360));
              return Stack(
                fit: StackFit.expand,
                children: [
                  Semantics(
                    selected: selected,
                    label: '$number쪽${selected ? ', 현재 쪽' : ''}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onChoose((
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
                                  right: canTrash(page) ? 48 : 12,
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
                  ),
                  if (canTrash(page))
                    Positioned(
                      top: 0,
                      right: 0,
                      child: PopupMenuButton<bool>(
                        tooltip: '$number쪽 메뉴',
                        icon: const Icon(
                          CupertinoIcons.ellipsis,
                          color: brandInk,
                        ),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: true,
                            child: Text('휴지통으로 이동'),
                          ),
                        ],
                        onSelected: (_) => _confirmTrash(context, page, number),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TrashPageDialog extends StatefulWidget {
  const _TrashPageDialog({
    required this.page,
    required this.number,
    required this.onTrash,
  });

  final WritingPage page;
  final int number;
  final Future<bool> Function() onTrash;

  @override
  State<_TrashPageDialog> createState() => _TrashPageDialogState();
}

class _TrashPageDialogState extends State<_TrashPageDialog> {
  bool saving = false;
  bool failed = false;

  Future<void> _move() async {
    setState(() => saving = true);
    final saved = await widget.onTrash();
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() {
        saving = false;
        failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.page.text.trimLeft();
    final end = text.indexOf('\n');
    final firstLine = end < 0 ? text : text.substring(0, end);
    final excerpt = firstLine.isEmpty ? '빈 종이' : firstLine;
    return PopScope(
      canPop: !saving,
      child: AlertDialog(
        scrollable: true,
        title: Text('${widget.number}쪽을 휴지통으로 옮길까요?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(excerpt, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Text(
              failed
                  ? '옮기지 못했어요. 쪽은 목록에 남아 있어요.'
                  : '기록 보관의 휴지통에서 이 쪽을 복원할 수 있어요.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: saving ? null : _move,
            child: Text(
              saving
                  ? '옮기는 중'
                  : failed
                  ? '다시 시도'
                  : '이동',
            ),
          ),
        ],
      ),
    );
  }
}
