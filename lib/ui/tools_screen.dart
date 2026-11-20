import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../data/library_controller.dart';
import 'paper.dart';
import 'paper_panel.dart';
import 'paper_tool.dart';
import 'font_size_control.dart';
import 'stationery_tool.dart';
import 'book_detail_tools.dart';
import 'book_appearance.dart';

/// Writing preferences and record actions from the page footer.
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({
    super.key,
    required this.controller,
    required this.paperTool,
    required this.onToolSelected,
    this.bookId,
    this.onReadAloud,
    required this.onBind,
    required this.onArchive,
    this.onSync,
  });
  final LibraryController controller;
  final PaperTool paperTool;
  final ValueChanged<PaperTool> onToolSelected;
  final String? bookId;
  final VoidCallback? onSync;
  final ValueChanged<BuildContext>? onReadAloud;
  final VoidCallback onBind, onArchive;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final style = controller.library.style;
      final book = controller.library.books
          .where((b) => b.id == bookId)
          .firstOrNull;
      final canMark = controller.styleFor(book).bookDetails.pencil.enabled;
      final panel = panelPaperColor(
        paperColors[book?.paperIndex ?? style.paperIndex],
      );
      return PaperPanel(
        color: panel,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 6, 12, 8),
              child: PaperPanelHeader('쓰기 도구'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _tools(panel, penColors[style.penIndex], canMark),
                    const Divider(color: line, height: 28),
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
                                onTap: () => controller.setStyle(
                                  style.copy(paperIndex: i),
                                ),
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
                    const Text(
                      '글꼴',
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, box) {
                        final columns =
                            box.maxWidth >= 310 &&
                                MediaQuery.textScalerOf(context).scale(14) <= 20
                            ? 2
                            : 1;
                        final width =
                            (box.maxWidth - (columns - 1) * 8) / columns;
                        Widget option(
                          String name,
                          String family,
                          bool selected,
                          VoidCallback choose, {
                          FontWeight weight = FontWeight.w400,
                        }) => SizedBox(
                          width: width,
                          child: ChoiceChip(
                            label: SizedBox(
                              width: double.infinity,
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontFamily: family,
                                  fontFamilyFallback: appFontFallback,
                                  fontWeight: weight,
                                  fontSize: 16,
                                  height: 1.6,
                                ),
                              ),
                            ),
                            labelPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            selected: selected,
                            onSelected: (_) => choose(),
                            selectedColor: panelSelectedColor(panel),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                              side: BorderSide(color: line),
                            ),
                          ),
                        );
                        return Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            option(
                              developmentFontLabel,
                              developmentSerif,
                              style.useDevelopmentTypeface,
                              () => controller.setStyle(
                                style.copy(useDevelopmentTypeface: true),
                              ),
                            ),
                            for (var i = 0; i < 3; i++)
                              option(
                                fontNames[i],
                                i == 2 ? 'NanumGothic' : serif,
                                !style.useDevelopmentTypeface &&
                                    style.fontIndex == i,
                                () => controller.setStyle(
                                  style.copy(
                                    fontIndex: i,
                                    useDevelopmentTypeface: false,
                                  ),
                                ),
                                weight: i == 1
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    FontSizeControl(
                      style: controller.styleFor(book),
                      onChanged: (value) =>
                          controller.setStyle(style.copy(fontSize: value)),
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
                      childrenPadding: const EdgeInsetsDirectional.only(
                        start: 12,
                      ),
                      shape: const Border(),
                      collapsedShape: const Border(),
                      children: [
                        _toggle(
                          panel,
                          '글씨 쓰는 소리',
                          style.writingSound,
                          (value) => controller.setStyle(
                            style.copy(writingSound: value),
                          ),
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
                          (value) => controller.setStyle(
                            style.copy(pageMotion: value),
                          ),
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
                    if (onReadAloud != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(CupertinoIcons.speaker_2, size: 20),
                        title: const Text('낭독'),
                        onTap: () => onReadAloud!(context),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 2),
                      child: Semantics(
                        header: true,
                        child: const Text(
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
                        book == null
                            ? '책갈피 · 장서표 · 쪽지와 작은 흔적들'
                            : '표지 · 내지 · 책 장식',
                        style: const TextStyle(color: muted, fontSize: 11),
                      ),
                      trailing: const Icon(
                        CupertinoIcons.chevron_right,
                        size: 16,
                        color: muted,
                      ),
                      onTap: book != null
                          ? () =>
                                showBookAppearance(context, controller, book.id)
                          : () => Navigator.of(context).push(
                              paperPanelRoute<void>(
                                (_) => PaperPanel(
                                  color: panel,
                                  child: BookDetailTools(
                                    controller: controller,
                                  ),
                                ),
                                color: panel,
                              ),
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
                      title: const Text('기록 관리'),
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
          ],
        ),
      );
    },
  );

  Widget _tools(Color panel, Color inkColor, bool canMark) => LayoutBuilder(
    builder: (context, box) {
      final columns = MediaQuery.textScalerOf(context).scale(14) > 21 ? 1 : 3;
      final width = (box.maxWidth - (columns - 1) * 8) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final tool in PaperTool.values)
            SizedBox(
              width: width,
              child: Semantics(
                button: true,
                selected: paperTool == tool,
                enabled: canMark || tool == PaperTool.writing,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: ValueKey('choose-paper-tool-${tool.name}'),
                    onTap: canMark || tool == PaperTool.writing
                        ? () => onToolSelected(tool)
                        : null,
                    borderRadius: BorderRadius.circular(3),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: paperTool == tool
                            ? panelSelectedColor(panel).withValues(alpha: .55)
                            : Colors.transparent,
                        border: Border(
                          bottom: BorderSide(
                            color: paperTool == tool ? brandInk : line,
                            width: paperTool == tool ? 1.5 : .7,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Opacity(
                          opacity: canMark || tool == PaperTool.writing
                              ? 1
                              : .45,
                          child: Column(
                            children: [
                              StationeryTool(tool: tool, color: inkColor),
                              const SizedBox(height: 8),
                              Text(
                                tool.label,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: brandInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
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
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: sheet ? BoxShape.rectangle : BoxShape.circle,
            borderRadius: sheet ? BorderRadius.circular(7) : null,
            border: Border.all(color: selected ? brandInk : Colors.transparent),
          ),
          child: sheet
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    image: paperGrain(color, .3),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: ink.withValues(alpha: .12)),
                    boxShadow: [
                      BoxShadow(
                        color: ink.withValues(alpha: .09),
                        offset: const Offset(1, 2),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(3),
                  child: InkMark(size: 30, color: color),
                ),
        ),
      ),
    ),
  );
}
