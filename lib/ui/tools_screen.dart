import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../data/library_controller.dart';
import 'paper.dart';
import 'book_detail_tools.dart';
import 'book_appearance.dart';

/// Secondary preferences, deliberately kept off the writing surface.
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({
    super.key,
    required this.controller,
    this.bookId,
    this.onBack,
  });
  final LibraryController controller;
  final String? bookId;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final style = controller.library.style;
      final book = controller.library.books
          .where((b) => b.id == bookId)
          .firstOrNull;
      return SafeArea(
        top: false,
        child: PaperBackdrop(
          color: paperColors[book?.paperIndex ?? style.paperIndex],
          grainOpacity: paperGrainOpacity[book?.paperIndex ?? style.paperIndex],
          binding: controller.detailsFor(book).binding,
          coverIndex: book == null ? null : controller.coverIndexFor(book),
          pagesAfter: book == null
              ? 0
              : controller.library.volumePages(bookId: book.id).length,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '쓰기 취향',
                        style: TextStyle(
                          fontFamily: appFontFamily,
                          fontFamilyFallback: appFontFallback,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '닫기',
                      onPressed: onBack,
                      icon: const Icon(CupertinoIcons.xmark, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _row(
                  book == null ? '기본 종이' : '이 책의 내지',
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < 4; i++)
                        _swatch(
                          label: paperNames[i],
                          color: paperColors[i],
                          sheet: true,
                          selected: (book?.paperIndex ?? style.paperIndex) == i,
                          onTap: () {
                            if (book == null) {
                              controller.setStyle(style.copy(paperIndex: i));
                            } else {
                              controller.setBookMaterials(
                                book.id,
                                paperIndex: i,
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ),
                if (book?.paperIndex != null)
                  TextButton(
                    onPressed: () => controller.setBookMaterials(
                      book!.id,
                      useDefaultPaper: true,
                    ),
                    child: const Text('기본 종이 사용'),
                  ),
                const SizedBox(height: 16),
                _row(
                  '잉크',
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < 3; i++)
                        _swatch(
                          label: ['먹빛', '브라운', '블루'][i],
                          color: penColors[i],
                          selected: style.penIndex == i,
                          onTap: () =>
                              controller.setStyle(style.copy(penIndex: i)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('글꼴', style: TextStyle(fontSize: 13, color: muted)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text(
                        developmentFontLabel,
                        style: TextStyle(fontSize: 13),
                      ),
                      selected: style.useDevelopmentTypeface,
                      onSelected: (_) => controller.setStyle(
                        style.copy(useDevelopmentTypeface: true),
                      ),
                      showCheckmark: false,
                      selectedColor: const Color(0xffeeddd3),
                      backgroundColor: paper,
                      side: BorderSide(
                        color: style.useDevelopmentTypeface ? brandInk : line,
                      ),
                    ),
                    for (var i = 0; i < 3; i++)
                      ChoiceChip(
                        label: Text(
                          fontNames[i],
                          style: TextStyle(
                            fontFamily: i == 2 ? 'NanumGothic' : serif,
                            fontSize: 13,
                          ),
                        ),
                        selected:
                            !style.useDevelopmentTypeface &&
                            style.fontIndex == i,
                        onSelected: (_) => controller.setStyle(
                          style.copy(
                            fontIndex: i,
                            useDevelopmentTypeface: false,
                          ),
                        ),
                        showCheckmark: false,
                        selectedColor: const Color(0xffeeddd3),
                        backgroundColor: paper,
                        side: BorderSide(
                          color:
                              !style.useDevelopmentTypeface &&
                                  style.fontIndex == i
                              ? burgundy
                              : line,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(color: line),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('잉크 반응', style: TextStyle(fontSize: 14)),
                  value: style.penMotion,
                  activeTrackColor: burgundy,
                  onChanged: (v) =>
                      controller.setStyle(style.copy(penMotion: v)),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('종이 넘김 효과', style: TextStyle(fontSize: 14)),
                  value: style.pageMotion,
                  activeTrackColor: burgundy,
                  onChanged: (v) =>
                      controller.setStyle(style.copy(pageMotion: v)),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('종이 넘김 소리', style: TextStyle(fontSize: 14)),
                  value: style.pageSound,
                  activeTrackColor: burgundy,
                  onChanged: (v) =>
                      controller.setStyle(style.copy(pageSound: v)),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('줄 가이드', style: TextStyle(fontSize: 14)),
                  value: style.guides,
                  activeTrackColor: burgundy,
                  onChanged: (v) => controller.setStyle(style.copy(guides: v)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    book == null ? '책의 디테일' : '책 꾸미기',
                    style: const TextStyle(
                      fontFamily: appFontFamily,
                      fontFamilyFallback: appFontFallback,
                      fontSize: 17,
                    ),
                  ),
                  subtitle: Text(
                    book == null
                        ? '책갈피 · 장서표 · 쪽지와 작은 흔적들'
                        : '표지 · 내지 · 책갈피와 쪽 디테일',
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                  trailing: const Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: muted,
                  ),
                  onTap: book != null
                      ? () => showBookAppearance(context, controller, book.id)
                      : () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          showDragHandle: true,
                          constraints: const BoxConstraints(maxWidth: 600),
                          builder: (_) =>
                              BookDetailTools(controller: controller),
                        ),
                ),
                if (controller.saveError != null)
                  TextButton(
                    onPressed: controller.retrySave,
                    child: const Text('설정 저장 실패 · 다시 시도'),
                  ),
                const SizedBox(height: 6),
                const Text(
                  '현대 한글 11,172자·자모·영문·숫자를 지원합니다.\n지원 범위 밖의 문자는 나눔명조 등으로 표시합니다.',
                  style: TextStyle(color: muted, fontSize: 11, height: 1.7),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _row(String label, Widget child) => Row(
    children: [
      Expanded(
        child: Text(label, style: const TextStyle(fontSize: 13, color: muted)),
      ),
      child,
    ],
  );

  Widget _swatch({
    required String label,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
    bool sheet = false,
  }) => Semantics(
    label: label,
    selected: selected,
    button: true,
    child: Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(sheet ? 7 : 22),
        child: Container(
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: sheet ? BoxShape.rectangle : BoxShape.circle,
            borderRadius: sheet ? BorderRadius.circular(7) : null,
            border: Border.all(color: selected ? burgundy : Colors.transparent),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              shape: sheet ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: sheet ? BorderRadius.circular(3) : null,
              border: Border.all(color: ink.withValues(alpha: .12)),
            ),
          ),
        ),
      ),
    ),
  );
}
