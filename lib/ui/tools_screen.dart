import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../data/library_controller.dart';
import '../data/model.dart';
import 'paper.dart';
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
            if (tool == PaperTool.highlighter)
              _washSettings(book, wash)
            else if (tool == PaperTool.eraser)
              const Text(
                '밑칠한 곳을 문지르면 지워져요.\n글씨는 그대로 남아요.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.6, color: muted),
              )
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
              const Divider(height: 16),
              _fontChoices(style),
              const Divider(height: 12),
              FontSizeControl(
                style: effectiveStyle,
                onPreviewChanged: (value) =>
                    setState(() => _previewFontSize = value),
                onChanged: (value) => controller.setStyle(
                  controller.library.style.copy(fontSize: value),
                ),
              ),
              const Divider(height: 12),
              _toggle(
                panel,
                '줄 가이드',
                style.guides,
                (value) => controller.setStyle(style.copy(guides: value)),
              ),
            ],
          ],
        ),
      );
      final surface = PaperPanel(
        color: panel,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 3, 12, 3),
              child: PaperPanelHeader(
                '쓰기 도구',
                canClose: controller.saveError == null,
                allowWritingReturn: false,
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  // Keep the result in view while the controls scroll. Large
                  // accessibility text and short screens use one full scroll.
                  final pinPreview =
                      box.maxHeight >= 460 &&
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
      return PopScope(canPop: controller.saveError == null, child: surface);
    },
  );

  Widget _fontChoices(WritingStyle style) {
    Widget option(
      String name,
      TextStyle textStyle,
      bool selected,
      VoidCallback choose,
    ) => Semantics(
      selected: selected,
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          foregroundColor: selected ? brandInk : ink,
        ),
        onPressed: choose,
        child: Container(
          padding: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? brandInk : Colors.transparent,
                width: 1.5,
              ),
            ),
          ),
          child: Text(name, textAlign: TextAlign.center, style: textStyle),
        ),
      ),
    );

    final choices = [
      option(
        developmentFontLabel,
        const TextStyle(
          fontFamily: developmentSerif,
          fontFamilyFallback: appFontFallback,
          fontSize: 14,
        ),
        style.useDevelopmentTypeface,
        () => controller.setStyle(style.copy(useDevelopmentTypeface: true)),
      ),
      for (var i = 0; i < fontNames.length; i++)
        option(
          fontNames[i],
          TextStyle(
            fontFamily: i == 2 ? 'NanumGothic' : serif,
            fontFamilyFallback: appFontFallback,
            fontSize: 14,
            fontWeight: i == 1 ? FontWeight.w700 : FontWeight.w400,
          ),
          !style.useDevelopmentTypeface && style.fontIndex == i,
          () => controller.setStyle(
            style.copy(fontIndex: i, useDevelopmentTypeface: false),
          ),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('글꼴', style: TextStyle(fontSize: 14, color: muted)),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, box) {
            final scaled = MediaQuery.textScalerOf(context).scale(14);
            if (box.maxWidth >= 320 && scaled <= 16) {
              const widths = [10, 9, 13, 9];
              return Row(
                children: [
                  for (var i = 0; i < choices.length; i++)
                    Expanded(flex: widths[i], child: choices[i]),
                ],
              );
            }
            const spacing = 4.0;
            final columns = box.maxWidth >= scaled * 9 + spacing ? 2 : 1;
            return Wrap(
              spacing: spacing,
              children: [
                for (final choice in choices)
                  SizedBox(
                    width: (box.maxWidth - (columns - 1) * spacing) / columns,
                    child: choice,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _tools(
    PaperTool selected,
    Color inkColor,
    BookDetailChoice wash,
  ) => LayoutBuilder(
    builder: (context, box) {
      const spacing = 8.0;
      final minimumWidth = MediaQuery.textScalerOf(context).scale(16) * 3 + 32;
      final columns = ((box.maxWidth + spacing) / (minimumWidth + spacing))
          .floor()
          .clamp(1, PaperTool.values.length);
      final width = (box.maxWidth - (columns - 1) * spacing) / columns;
      return Wrap(
        key: const ValueKey('tool-picker'),
        spacing: spacing,
        runSpacing: 8,
        children: [
          for (final tool in PaperTool.values)
            SizedBox(
              width: width,
              child: Builder(
                builder: (context) {
                  final active = selected == tool;
                  final enabled = wash.enabled || tool == PaperTool.writing;
                  final label = tool == PaperTool.writing ? '펜' : tool.label;
                  return Semantics(
                    button: true,
                    selected: active,
                    enabled: enabled,
                    label: label,
                    onTap: enabled ? () => _select(tool) : null,
                    excludeSemantics: true,
                    child: Material(
                      color: active
                          ? Colors.white.withValues(alpha: .18)
                          : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: active
                            ? BorderSide(color: brandInk.withValues(alpha: .4))
                            : BorderSide.none,
                      ),
                      child: InkWell(
                        key: ValueKey('choose-paper-tool-${tool.name}'),
                        onTap: enabled ? () => _select(tool) : null,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
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

  Widget _washSettings(Book? book, BookDetailChoice wash) {
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
        const SizedBox(height: 12),
        Text(
          '종이에서 글자를 따라 그으면 밑칠돼요.',
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
    final scaler = MediaQuery.textScalerOf(context);
    final maxStyle = textStyle.copyWith(fontSize: WritingStyle.maxFontSize);
    const spacing = 1.4;
    final strut = StrutStyle.fromTextStyle(
      maxStyle.copyWith(height: spacing),
      forceStrutHeight: true,
    );
    return Semantics(
      label: switch (tool) {
        PaperTool.writing => '펜 글씨 견본',
        PaperTool.highlighter => '형광펜 밑칠 견본',
        PaperTool.eraser => '밑칠을 지운 견본',
      },
      child: Container(
        key: const ValueKey('tool-paper-specimen'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: color, image: paperGrain(color, .22)),
        child: LayoutBuilder(
          builder: (context, box) {
            const longSample = ['마음에 남은 문장을', '천천히 옮겨 씁니다.'];
            const shortSample = ['마음에 남은 글을', '천천히 옮겨 써요.'];
            // Reserve the largest sample even while the slider is still moving.
            final maxSample = TextPainter(
              text: TextSpan(text: longSample.join('\n'), style: maxStyle),
              strutStyle: strut,
              textScaler: scaler,
              textDirection: Directionality.of(context),
            )..layout(maxWidth: box.maxWidth);
            final lines = maxSample.computeLineMetrics().length > 2
                ? shortSample
                : longSample;
            final sample = lines.join('\n');
            if (identical(lines, shortSample)) {
              maxSample
                ..text = TextSpan(text: sample, style: maxStyle)
                ..layout(maxWidth: box.maxWidth);
            }
            final reservedHeight = maxSample.height;
            maxSample.dispose();
            return ConstrainedBox(
              constraints: BoxConstraints(minHeight: reservedHeight),
              child: CustomPaint(
                painter: style.guides
                    ? _SpecimenGuides(
                        scaler.scale(WritingStyle.maxFontSize) * spacing,
                      )
                    : null,
                child: Text.rich(
                  pencilTextSpan(
                    value: TextEditingValue(text: sample),
                    marks: tool == PaperTool.highlighter
                        ? [PencilMark(lines[0].length + 1, lines[0].length + 7)]
                        : const [],
                    choice: style.bookDetails.pencil,
                    style: textStyle,
                  ),
                  key: const ValueKey('tool-specimen-text'),
                  strutStyle: strut,
                ),
              ),
            );
          },
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
      final sync = onSync;
      return PaperPanel(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 6, 12, 8),
              child: PaperPanelHeader('책장 설정'),
            ),
            Expanded(
              child: ListView(
                key: const ValueKey('library-settings-list'),
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  _settingsHeading('서재 기본값'),
                  const SizedBox(height: 8),
                  const Text('기본 종이', style: TextStyle(fontSize: 17)),
                  const SizedBox(height: 3),
                  const Text(
                    '책 없이 쓴 글과 내지를 따로 고르지 않은 책에 써요.',
                    style: _settingsNoteStyle,
                  ),
                  const SizedBox(height: 12),
                  _PaperStocks(
                    selected: style.paperIndex,
                    onSelected: (index) =>
                        controller.setStyle(style.copy(paperIndex: index)),
                  ),
                  _settingsLink(
                    '기본 장식',
                    '책갈피·장서표·밑칠',
                    () => Navigator.of(context).push(
                      paperPanelRoute<void>(
                        (_) => PaperPanel(
                          child: BookDetailTools(controller: controller),
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  _settingsGroup(
                    '소리와 효과',
                    [
                      _toggle(
                        paper,
                        '글씨 쓰는 소리',
                        style.writingSound,
                        (value) => controller.setStyle(
                          style.copy(writingSound: value),
                        ),
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
                    ],
                    subtitle: const Text(
                      '글씨 쓰는 소리, 잉크 반응, 종이 넘김',
                      style: _settingsNoteStyle,
                    ),
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  _settingsHeading(sync == null ? '기록' : '기록과 기기'),
                  const SizedBox(height: 4),
                  _settingsLink('기록 관리', '백업·내보내기·휴지통', onArchive),
                  if (sync != null) ...[
                    const Divider(height: 1),
                    _settingsLink('기기 동기화', '다른 기기에서 이어 쓰기', sync),
                  ],
                ],
              ),
            ),
            if (controller.saveError != null)
              PaperSettingsSaveNotice(onRetry: controller.retrySave),
          ],
        ),
      );
    },
  );
}

const _settingsNoteStyle = TextStyle(fontSize: 14, color: muted, height: 1.4);

Widget _settingsHeading(String label) => Semantics(
  header: true,
  child: Text(label, style: const TextStyle(fontSize: 15, color: brandInk)),
);

Widget _settingsLink(String title, String subtitle, VoidCallback onTap) =>
    ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontSize: 17)),
      subtitle: Text(subtitle, style: _settingsNoteStyle),
      trailing: const Icon(CupertinoIcons.chevron_right, size: 15),
      onTap: onTap,
    );

class _PaperStocks extends StatelessWidget {
  const _PaperStocks({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 6.0;
      const labelSize = 14.0;
      final minWidth =
          MediaQuery.textScalerOf(context).scale(labelSize) * 3 + 12;
      final columns = constraints.maxWidth >= 4 * minWidth + 3 * gap ? 4 : 2;
      final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
      final corners = BorderRadius.circular(3);
      return Material(
        type: MaterialType.transparency,
        child: Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var index = 0; index < paperNames.length; index++)
              Semantics(
                button: true,
                selected: selected == index,
                child: InkWell(
                  borderRadius: corners,
                  onTap: () {
                    if (selected != index) onSelected(index);
                  },
                  child: Ink(
                    width: width,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: selected == index
                          ? panelSelectedColor(paper)
                          : null,
                      borderRadius: corners,
                      border: Border.all(
                        color: selected == index
                            ? brandInk
                            : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          height: 43,
                          width: double.infinity,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: paperColors[index],
                            image: paperGrain(
                              paperColors[index],
                              paperGrainOpacity[index],
                            ),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(color: line),
                          ),
                          child: selected == index
                              ? const Icon(
                                  CupertinoIcons.checkmark,
                                  size: 17,
                                  color: brandInk,
                                )
                              : null,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          paperNames[index],
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: labelSize),
                        ),
                      ],
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

Widget _settingsGroup(
  String title,
  List<Widget> children, {
  bool initiallyExpanded = false,
  Widget? subtitle,
}) => ExpansionTile(
  title: Text(title),
  subtitle: subtitle,
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
