import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../data/library_controller.dart';
import 'paper.dart';
import 'book_detail_tools.dart';
import 'book_appearance.dart';

/// Writing preferences and record actions from the page footer.
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({
    super.key,
    required this.controller,
    this.bookId,
    this.onBack,
    required this.onBind,
    required this.onArchive,
    this.onSync,
  });
  final LibraryController controller;
  final String? bookId;
  final VoidCallback? onBack, onSync;
  final VoidCallback onBind, onArchive;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final style = controller.library.style;
      final book = controller.library.books
          .where((b) => b.id == bookId)
          .firstOrNull;
      final panel = panelPaperColor(
        paperColors[book?.paperIndex ?? style.paperIndex],
      );
      return SafeArea(
        top: false,
        child: PaperBackdrop(
          color: panel,
          outsideColor: panel,
          grainOpacity: panelGrainOpacity,
          binding: controller.detailsFor(book).binding,
          coverIndex: book == null ? null : controller.coverIndexFor(book),
          pagesAfter: book == null
              ? 0
              : controller.library.volumePages(bookId: book.id).length,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PaperSheetHandle(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '쓰기 도구',
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
                if (book == null) ...[
                  _row(
                    '기본 종이',
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final (i, name) in paperNames.indexed)
                          _swatch(
                            label: name,
                            color: paperColors[i],
                            sheet: true,
                            selected: style.paperIndex == i,
                            onTap: () =>
                                controller.setStyle(style.copy(paperIndex: i)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
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
                      selectedColor: panelSelectedColor(panel),
                      backgroundColor: panelChipColor(panel),
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
                        selectedColor: panelSelectedColor(panel),
                        backgroundColor: panelChipColor(panel),
                        side: BorderSide(
                          color:
                              !style.useDevelopmentTypeface &&
                                  style.fontIndex == i
                              ? brandInk
                              : line,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _toggle(
                  panel,
                  '줄 가이드',
                  style.guides,
                  (value) => controller.setStyle(style.copy(guides: value)),
                ),
                const Divider(color: line),
                ExpansionTile(
                  key: const ValueKey('writing-sound-effects'),
                  title: const Text('소리와 효과'),
                  textColor: brandInk,
                  iconColor: muted,
                  collapsedTextColor: ink,
                  collapsedIconColor: muted,
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsetsDirectional.only(start: 12),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  children: [
                    _toggle(
                      panel,
                      '글씨 쓰는 소리',
                      style.writingSound,
                      (value) =>
                          controller.setStyle(style.copy(writingSound: value)),
                    ),
                    _toggle(
                      panel,
                      '잉크 반응',
                      style.penMotion,
                      (value) =>
                          controller.setStyle(style.copy(penMotion: value)),
                    ),
                    _toggle(
                      panel,
                      '종이 넘김 효과',
                      style.pageMotion,
                      (value) =>
                          controller.setStyle(style.copy(pageMotion: value)),
                    ),
                    _toggle(
                      panel,
                      '종이 넘김 소리',
                      style.pageSound,
                      (value) =>
                          controller.setStyle(style.copy(pageSound: value)),
                    ),
                  ],
                ),
                const Divider(color: line),
                const Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 2),
                  child: Semantics(
                    header: true,
                    child: Text(
                      '책과 기록',
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                  ),
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
                    book == null ? '책갈피 · 장서표 · 쪽지와 작은 흔적들' : '표지 · 내지 · 책 장식',
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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(CupertinoIcons.book, size: 20),
                  title: Text(book == null ? '책에 넣기' : '다른 책으로 옮기기'),
                  onTap: onBind,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(CupertinoIcons.archivebox, size: 20),
                  title: const Text('기록 보관'),
                  onTap: onArchive,
                ),
                if (onSync != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(CupertinoIcons.cloud, size: 20),
                    title: const Text('기기 동기화'),
                    onTap: onSync,
                  ),
                if (controller.saveError != null)
                  TextButton(
                    onPressed: controller.retrySave,
                    child: const Text('설정 저장 실패 · 다시 시도'),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _toggle(
    Color panel,
    String label,
    bool enabled,
    ValueChanged<bool> onChanged,
  ) => SwitchListTile.adaptive(
    contentPadding: EdgeInsets.zero,
    title: Text(label, style: const TextStyle(fontSize: 14)),
    value: enabled,
    activeTrackColor: panelSwitchTrack,
    activeThumbColor: panelSwitchThumb,
    inactiveThumbColor: muted,
    inactiveTrackColor: panelSelectedColor(panel),
    onChanged: onChanged,
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
            border: Border.all(color: selected ? brandInk : Colors.transparent),
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
