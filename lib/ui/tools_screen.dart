import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../data/library_controller.dart';
import '../data/model.dart';
import 'paper.dart';
import 'paper_choice.dart';
import 'paper_panel.dart';
import 'paper_tool.dart';
import 'font_size_control.dart';
import 'stationery_tool.dart';
import 'book_detail_tools.dart';
import 'book_detail_design.dart';
import 'pencil_marks.dart';

/// A paper specimen and the tools that leave a mark on it.
class ToolsScreen extends StatefulWidget {
  const ToolsScreen({
    super.key,
    required this.controller,
    required this.paperTool,
    required this.onToolSelected,
    this.bookId,
  });
  final LibraryController controller;
  final PaperTool paperTool;
  final ValueChanged<PaperTool> onToolSelected;
  final String? bookId;

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  late PaperTool _tool = widget.paperTool;
  double? _previewFontSize;
  LibraryController get controller => widget.controller;

  void _select(PaperTool tool) {
    setState(() {
      _tool = tool;
      _previewFontSize = null;
    });
    widget.onToolSelected(tool);
  }

  void _changeWash(Book? book, BookDetailChoice choice) {
    if (book == null) {
      final style = controller.library.style;
      controller.setStyle(
        style.copy(
          bookDetails: style.bookDetails.withChoice(
            BookDetailKind.pencil,
            choice,
          ),
        ),
      );
    } else {
      controller.saveBookAppearance(
        book.id,
        useDefaultPaper: book.paperIndex == null,
        changes: {BookDetailKind.pencil: choice},
      );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final style = controller.library.style;
      final book = controller.library.books
          .where((b) => b.id == widget.bookId)
          .firstOrNull;
      final effectiveStyle = controller.styleFor(book);
      final wash = effectiveStyle.bookDetails.pencil;
      final tool = wash.enabled ? _tool : PaperTool.writing;
      final marking = tool != PaperTool.writing;
      final panel = panelPaperColor(paperColors[effectiveStyle.paperIndex]);
      final preview = Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _tools(tool, penColors[style.penIndex], wash),
            const SizedBox(height: 8),
            _ToolSpecimen(
              style: effectiveStyle.copy(fontSize: _previewFontSize),
              tool: tool,
            ),
          ],
        ),
      );
      final settings = Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!wash.enabled)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('enable-paper-highlighter'),
                  onPressed: () {
                    _changeWash(book, wash.copy(enabled: true));
                    _select(PaperTool.highlighter);
                  },
                  icon: const Icon(Icons.border_color_outlined),
                  label: const Text('밑칠 켜기'),
                ),
              ),
            if (marking)
              _washSettings(book, wash, tool)
            else ...[
              _row(
                '잉크',
                Wrap(
                  children: [
                    for (var i = 0; i < penColors.length; i++)
                      _inkSwatch(
                        label: ['먹빛', '브라운', '블루'][i],
                        color: penColors[i],
                        selected: style.penIndex == i,
                        onTap: () =>
                            controller.setStyle(style.copy(penIndex: i)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _settingsGroup('글씨 설정', [
                LayoutBuilder(
                  builder: (context, box) {
                    final columns =
                        box.maxWidth >= 310 &&
                            MediaQuery.textScalerOf(context).scale(14) <= 20
                        ? 2
                        : 1;
                    final width = (box.maxWidth - (columns - 1) * 8) / columns;
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
                            weight: i == 1 ? FontWeight.w700 : FontWeight.w400,
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                FontSizeControl(
                  style: effectiveStyle,
                  showSpecimen: false,
                  onPreviewChanged: (value) =>
                      setState(() => _previewFontSize = value),
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
              ], initiallyExpanded: true),
            ],
          ],
        ),
      );
      return PaperPanel(
        color: panel,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 3, 12, 3),
              child: Row(
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: const Text(
                        '쓰기 도구',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, color: ink),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(CupertinoIcons.xmark, size: 18),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  // Keep the result in view while the controls scroll. Large
                  // accessibility text and short screens use one full scroll.
                  final pinPreview =
                      box.maxHeight >= 560 &&
                      MediaQuery.textScalerOf(context).scale(16) <= 22;
                  if (pinPreview) {
                    return Column(
                      children: [
                        preview,
                        Expanded(
                          child: SingleChildScrollView(
                            key: const ValueKey('tool-settings-scroll'),
                            child: settings,
                          ),
                        ),
                      ],
                    );
                  }
                  return SingleChildScrollView(
                    key: const ValueKey('tool-full-scroll'),
                    child: Column(children: [preview, settings]),
                  );
                },
              ),
            ),
            if (controller.saveError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: TextButton(
                  onPressed: controller.retrySave,
                  child: const Text('설정 저장 실패 · 다시 시도'),
                ),
              ),
          ],
        ),
      );
    },
  );

  Widget _tools(
    PaperTool selected,
    Color inkColor,
    BookDetailChoice wash,
  ) => LayoutBuilder(
    builder: (context, box) {
      final narrow =
          box.maxWidth < MediaQuery.textScalerOf(context).scale(120) * 2;
      final width = narrow ? box.maxWidth : (box.maxWidth - 16) / 2;
      return Wrap(
        key: const ValueKey('tool-picker'),
        spacing: 16,
        runSpacing: 12,
        children: [
          for (final tool in [PaperTool.writing, PaperTool.highlighter])
            SizedBox(
              width: width,
              child: Builder(
                builder: (context) {
                  final active = tool == PaperTool.writing
                      ? selected == tool
                      : selected != PaperTool.writing;
                  final enabled = wash.enabled || tool == PaperTool.writing;
                  final label = tool == PaperTool.writing ? '펜' : tool.label;
                  return Semantics(
                    button: true,
                    selected: active,
                    enabled: enabled,
                    label: label,
                    excludeSemantics: true,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: ValueKey('choose-paper-tool-${tool.name}'),
                        onTap: enabled ? () => _select(tool) : null,
                        borderRadius: BorderRadius.circular(3),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          child: Opacity(
                            opacity: enabled ? 1 : .4,
                            child: Column(
                              children: [
                                StationeryTool(
                                  tool: tool,
                                  color: tool == PaperTool.writing
                                      ? inkColor
                                      : BookDetailDesign.color(
                                          BookDetailKind.pencil,
                                          wash,
                                        ),
                                  width: 128,
                                  height: 32,
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  children: [
                                    if (active)
                                      const Icon(
                                        Icons.check,
                                        size: 17,
                                        color: brandInk,
                                      ),
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: active ? brandInk : muted,
                                      ),
                                    ),
                                  ],
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
      );
    },
  );

  Widget _washSettings(Book? book, BookDetailChoice wash, PaperTool tool) {
    final design = BookDetailDesign.of(BookDetailKind.pencil);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row(
          '색',
          Wrap(
            children: [
              for (var i = 0; i < design.colors.length; i++)
                Semantics(
                  selected: wash.tone == i,
                  child: IconButton(
                    key: ValueKey('tool-wash-tone-$i'),
                    tooltip: '밑칠 색 · ${design.tones[i]}',
                    onPressed: () => _changeWash(book, wash.copy(tone: i)),
                    icon: SizedBox(
                      width: 32,
                      height: 24,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: passageWashStyle(
                            wash.copy(tone: i),
                          ).backgroundColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: wash.tone == i
                            ? const Icon(Icons.check, size: 18, color: brandInk)
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _row(
          '농도',
          Text(
            design.variants[wash.variant],
            style: const TextStyle(fontSize: 14, color: muted),
          ),
        ),
        Slider(
          key: const ValueKey('tool-wash-density'),
          value: wash.variant.toDouble(),
          min: 0,
          max: 2,
          divisions: 2,
          label: design.variants[wash.variant],
          semanticFormatterCallback: (value) => design.variants[value.round()],
          onChanged: (value) {
            if (value.round() != wash.variant) {
              _changeWash(book, wash.copy(variant: value.round()));
            }
          },
        ),
        const Divider(height: 28),
        Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            selected: tool == PaperTool.eraser,
            child: TextButton.icon(
              key: const ValueKey('choose-paper-tool-eraser'),
              onPressed: () => _select(
                tool == PaperTool.eraser
                    ? PaperTool.highlighter
                    : PaperTool.eraser,
              ),
              icon: Icon(
                tool == PaperTool.eraser
                    ? Icons.check
                    : Icons.backspace_outlined,
                size: 19,
              ),
              label: const Text('밑칠 지우기'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          tool == PaperTool.eraser
              ? '밑칠한 곳을 문지르면 지워져요.'
              : '종이에서 글자를 따라 그으면 밑칠돼요.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, height: 1.6, color: muted),
        ),
      ],
    );
  }
}

/// Synthetic text uses the same lettering and wash renderer as the live page.
/// No editor, page or stored annotation is created for this specimen.
class _ToolSpecimen extends StatelessWidget {
  const _ToolSpecimen({required this.style, required this.tool});
  final WritingStyle style;
  final PaperTool tool;

  @override
  Widget build(BuildContext context) {
    final color = paperColors[style.paperIndex];
    final textStyle = writingTextStyle(
      style.fontIndex,
      size: style.fontSize,
      color: penColors[style.penIndex],
      useDevelopmentTypeface: style.useDevelopmentTypeface,
    );
    const lines = ['마음에 남은 문장을', '천천히 옮겨 씁니다.'];
    return Semantics(
      label: switch (tool) {
        PaperTool.writing => '펜 글씨 견본',
        PaperTool.highlighter => '형광펜 밑칠 견본',
        PaperTool.eraser => '밑칠을 지운 견본',
      },
      child: Container(
        key: const ValueKey('tool-paper-specimen'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          image: paperGrain(color, .22),
          border: Border.all(color: line, width: .7),
          boxShadow: [
            BoxShadow(
              color: brandInk.withValues(alpha: .12),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomPaint(
              painter: style.guides
                  ? _SpecimenGuides(
                      MediaQuery.textScalerOf(context).scale(style.fontSize) *
                          1.8,
                    )
                  : null,
              child: Text.rich(
                pencilTextSpan(
                  value: TextEditingValue(text: lines.join('\n')),
                  marks: tool == PaperTool.highlighter
                      ? [PencilMark(lines[0].length + 1, lines[0].length + 7)]
                      : const [],
                  choice: style.bookDetails.pencil,
                  style: textStyle,
                ),
                key: const ValueKey('tool-specimen-text'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpecimenGuides extends CustomPainter {
  const _SpecimenGuides(this.height);
  final double height;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = line.withValues(alpha: .65)
      ..strokeWidth = .6;
    for (var y = height - 1; y <= size.height; y += height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_SpecimenGuides oldDelegate) =>
      height != oldDelegate.height;
}

class LibrarySettings extends StatelessWidget {
  const LibrarySettings({
    super.key,
    required this.controller,
    required this.onArchive,
    this.onSync,
  });

  final LibraryController controller;
  final VoidCallback onArchive;
  final VoidCallback? onSync;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final style = controller.library.style;
      return PaperPanel(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 6, 12, 8),
              child: PaperPanelHeader('설정'),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(CupertinoIcons.archivebox, size: 20),
                    title: const Text('기록 관리'),
                    trailing: const Icon(
                      CupertinoIcons.chevron_right,
                      size: 16,
                    ),
                    onTap: onArchive,
                  ),
                  if (onSync != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(CupertinoIcons.cloud, size: 20),
                      title: const Text('기기 동기화'),
                      trailing: const Icon(
                        CupertinoIcons.chevron_right,
                        size: 16,
                      ),
                      onTap: onSync,
                    ),
                  _settingsGroup('소리와 효과', [
                    _toggle(
                      paper,
                      '글씨 쓰는 소리',
                      style.writingSound,
                      (value) =>
                          controller.setStyle(style.copy(writingSound: value)),
                    ),
                    _toggle(
                      paper,
                      '잉크 반응',
                      style.penMotion,
                      (value) =>
                          controller.setStyle(style.copy(penMotion: value)),
                    ),
                    _toggle(
                      paper,
                      '종이 넘김 효과',
                      style.pageMotion,
                      (value) =>
                          controller.setStyle(style.copy(pageMotion: value)),
                    ),
                    _toggle(
                      paper,
                      '종이 넘김 소리',
                      style.pageSound,
                      (value) =>
                          controller.setStyle(style.copy(pageSound: value)),
                    ),
                  ]),
                  const Divider(color: line),
                  const Text(
                    '기본 종이',
                    style: TextStyle(fontSize: 13, color: muted),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (var i = 0; i < paperNames.length; i++)
                        PaperChoice(
                          index: i,
                          selected: style.paperIndex == i,
                          onSelected: (selected) {
                            if (selected) {
                              controller.setStyle(style.copy(paperIndex: i));
                            }
                          },
                        ),
                    ],
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('책의 디테일'),
                    trailing: const Icon(
                      CupertinoIcons.chevron_right,
                      size: 16,
                    ),
                    onTap: () => Navigator.of(context).push(
                      paperPanelRoute<void>(
                        (_) => PaperPanel(
                          child: BookDetailTools(controller: controller),
                        ),
                      ),
                    ),
                  ),
                  if (controller.saveError != null)
                    TextButton(
                      onPressed: controller.retrySave,
                      child: const Text('설정 저장 실패 · 다시 시도'),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _settingsGroup(
  String title,
  List<Widget> children, {
  bool initiallyExpanded = false,
}) => ExpansionTile(
  title: Text(title),
  initiallyExpanded: initiallyExpanded,
  textColor: brandInk,
  iconColor: muted,
  collapsedTextColor: ink,
  collapsedIconColor: muted,
  tilePadding: EdgeInsets.zero,
  shape: const Border(),
  collapsedShape: const Border(),
  children: children,
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

Widget _inkSwatch({
  required String label,
  required Color color,
  required bool selected,
  required VoidCallback onTap,
}) => Semantics(
  label: label,
  selected: selected,
  button: true,
  child: Tooltip(
    message: label,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 48,
        height: 48,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: selected ? brandInk : Colors.transparent),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: InkMark(size: 30, color: color),
        ),
      ),
    ),
  ),
);
