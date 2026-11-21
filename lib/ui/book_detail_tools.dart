import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../data/library_controller.dart';
import '../data/model.dart';
import 'book_detail_design.dart';
import 'book_details.dart';
import 'paper.dart' show paperGrain;
import 'paper_panel.dart';
import 'paper_palette.dart';
import 'pencil_marks.dart';
import 'reading_details.dart';

class BookDetailTools extends StatelessWidget {
  const BookDetailTools({super.key, required this.controller});
  final LibraryController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 6, 12, 8),
          child: PaperPanelHeader('기본 장식'),
        ),
        Expanded(
          child: ListView(
            key: const PageStorageKey('default-decoration-list'),
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 4, bottom: 12),
                child: Text(
                  '책에서 따로 고르지 않은 장식에 적용돼요.\n책 없이 쓴 글에도 써요.',
                  style: TextStyle(color: muted, fontSize: 14, height: 1.4),
                ),
              ),
              for (final kind in BookDetailKind.values)
                if (kind != BookDetailKind.binding) ...[
                  if (kind != BookDetailKind.ribbon) const Divider(height: 1),
                  _item(context, kind),
                ],
            ],
          ),
        ),
        if (controller.saveError != null)
          PaperSettingsSaveNotice(onRetry: controller.retrySave),
      ],
    ),
  );

  Widget _item(BuildContext context, BookDetailKind kind) {
    final design = BookDetailDesign.of(kind),
        choice = controller.library.style.bookDetails.choice(kind);
    return ListTile(
      key: ValueKey('detail-${kind.name}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      minTileHeight: 60,
      horizontalTitleGap: 12,
      leading: BookDetailSample(
        kind: kind,
        choice: choice,
        size: const Size(44, 40),
      ),
      title: Text(design.title, style: const TextStyle(fontSize: 17)),
      subtitle: Text(
        choice.enabled
            ? '${design.variants[choice.variant]} · ${design.tones[choice.tone]}'
            : '표시 안 함',
        style: const TextStyle(color: detailMetadataInk, fontSize: 14),
      ),
      trailing: const Icon(
        CupertinoIcons.chevron_right,
        color: brandInk,
        size: 14,
      ),
      onTap: () => Navigator.of(context).push<void>(
        paperPanelRoute<void>(
          (_) => PaperPanel(
            child: _DefaultDecorationEditor(controller: controller, kind: kind),
          ),
          fullscreenDialog: false,
        ),
      ),
    );
  }
}

class _DefaultDecorationEditor extends StatelessWidget {
  const _DefaultDecorationEditor({
    required this.controller,
    required this.kind,
  });

  final LibraryController controller;
  final BookDetailKind kind;

  void _change(BookDetailChoice Function(BookDetailChoice) update) {
    final style = controller.library.style;
    final choice = update(style.bookDetails.choice(kind));
    controller.setStyle(
      style.copy(bookDetails: style.bookDetails.withChoice(kind, choice)),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final style = controller.library.style;
      final choice = style.bookDetails.choice(kind);
      final design = BookDetailDesign.of(kind);
      final ribbon = kind == BookDetailKind.ribbon;
      final target = ribbon ? '책갈피' : design.title;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 6, 12, 8),
            child: PaperPanelHeader(design.title, showBackButton: true),
          ),
          Expanded(
            child: ListView(
              key: ValueKey('default-decoration-editor-${kind.name}'),
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
              children: [
                if (!ribbon) ...[
                  Text(
                    design.description,
                    style: const TextStyle(
                      color: detailMetadataInk,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xffefe4d4),
                    border: Border.all(color: line),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Semantics(
                      image: true,
                      label: choice.enabled
                          ? '${design.title} 미리보기, ${design.variants[choice.variant]}, ${design.tones[choice.tone]}'
                          : '${design.title} 미리보기, 표시 안 함',
                      child: ExcludeSemantics(
                        child: ExcludeFocus(
                          child: IgnorePointer(
                            child: BookDetailPreview(
                              kind: kind,
                              choice: choice,
                              stock: style.paperIndex,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                BookDetailOptions(
                  kind: kind,
                  choice: choice,
                  onChanged: _change,
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: ValueKey('detail-${kind.name}-reset'),
                    onPressed: () => _change((_) => const BookDetailChoice()),
                    child: Text('$target 설정 초기화'),
                  ),
                ),
              ],
            ),
          ),
          if (controller.saveError != null)
            PaperSettingsSaveNotice(onRetry: controller.retrySave),
        ],
      );
    },
  );
}

class _DetailChoices extends StatelessWidget {
  const _DetailChoices({
    required this.title,
    required this.control,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.specimen,
  });

  final String title, control;
  final List<String> labels;
  final int selected;
  final ValueChanged<int>? onSelected;
  final Widget Function(int)? specimen;

  @override
  Widget build(BuildContext context) {
    final buildSpecimen = specimen;
    const labelSize = 14.0;
    const gap = 6.0;
    final longest = labels.map((label) => label.length).reduce(math.max);
    final minWidth =
        MediaQuery.textScalerOf(context).scale(labelSize) * longest + 12;
    final choose = onSelected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: const TextStyle(fontSize: 16)),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, box) {
            final columns = ((box.maxWidth + gap) ~/ (minWidth + gap)).clamp(
              1,
              labels.length,
            );
            final width = (box.maxWidth - (columns - 1) * gap) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var i = 0; i < labels.length; i++)
                  SizedBox(
                    width: width,
                    child: Semantics(
                      selected: selected == i,
                      child: OutlinedButton(
                        key: ValueKey('$control-$i'),
                        onPressed: choose == null ? null : () => choose(i),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          backgroundColor: selected == i
                              ? panelSelectedColor(paper)
                              : null,
                          side: BorderSide(
                            color: selected == i ? brandInk : line,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        child: Stack(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (buildSpecimen != null) ...[
                                  Center(
                                    child: ExcludeSemantics(
                                      child: Opacity(
                                        opacity: choose == null ? .42 : 1,
                                        child: buildSpecimen(i),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                ] else
                                  const SizedBox(height: 10),
                                Text(
                                  labels[i],
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: labelSize),
                                ),
                              ],
                            ),
                            if (selected == i)
                              const Positioned(
                                right: 1,
                                top: 0,
                                child: Icon(CupertinoIcons.checkmark, size: 12),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RibbonSpread extends StatelessWidget {
  const _RibbonSpread({required this.choice, required this.stock});

  final BookDetailChoice choice;
  final int stock;

  @override
  Widget build(BuildContext context) {
    final color = paperColors[stock];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 285),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: muted.withValues(alpha: .56)),
            borderRadius: BorderRadius.circular(4),
            color: const Color(0xffcfbda4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x265a4432),
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(3, 3, 3, 5),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    image: paperGrain(color, paperGrainOpacity[stock] + .15),
                    gradient: LinearGradient(
                      colors: [color, panelSelectedColor(color), color, color],
                      stops: const [.42, .497, .53, 1],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 39, 10, 8),
                    child: MediaQuery.withNoTextScaling(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                for (var i = 0; i < 3; i++)
                                  const Divider(height: 13),
                              ],
                            ),
                          ),
                          const SizedBox(width: 15),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '천천히 책을 펼쳤다.\n어제 남긴 한 줄이\n그 자리에 있었다.',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: ink,
                                    fontSize: 11,
                                    height: 1.2,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '– 7 –',
                                    style: TextStyle(
                                      color: detailMetadataInk,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 17,
                  top: -5,
                  child: RibbonBookmark(choice: choice, width: 13, height: 37),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BookDetailOptions extends StatelessWidget {
  const BookDetailOptions({
    super.key,
    required this.kind,
    required this.choice,
    required this.onChanged,
  });

  final BookDetailKind kind;
  final BookDetailChoice choice;
  final ValueChanged<BookDetailChoice Function(BookDetailChoice)> onChanged;

  @override
  Widget build(BuildContext context) {
    final design = BookDetailDesign.of(kind);
    final ribbon = kind == BookDetailKind.ribbon;
    final target = ribbon ? '책갈피' : design.title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: ValueKey('detail-${kind.name}-enabled'),
          contentPadding: EdgeInsets.zero,
          title: Text('$target 표시'),
          value: choice.enabled,
          activeTrackColor: panelSwitchTrack,
          activeThumbColor: panelSwitchThumb,
          onChanged: (value) =>
              onChanged((current) => current.copy(enabled: value)),
        ),
        const Divider(height: 1),
        const SizedBox(height: 12),
        _DetailChoices(
          title: kind == BookDetailKind.pencil ? '농도' : '모양',
          control: 'detail-${kind.name}-variant',
          labels: design.variants,
          selected: choice.variant,
          onSelected: choice.enabled
              ? (index) => onChanged((current) => current.copy(variant: index))
              : null,
          specimen: (index) {
            final option = choice.copy(enabled: true, variant: index);
            return ribbon
                ? RibbonBookmark(choice: option, width: 18, height: 28)
                : BookDetailSample(
                    kind: kind,
                    choice: option,
                    size: const Size(52, 32),
                  );
          },
        ),
        const SizedBox(height: 10),
        _DetailChoices(
          title: '색',
          control: 'detail-${kind.name}-tone',
          labels: design.tones,
          selected: choice.tone,
          onSelected: choice.enabled
              ? (index) => onChanged((current) => current.copy(tone: index))
              : null,
          specimen: (index) => ribbon
              ? RibbonBookmark(
                  choice: BookDetailChoice(tone: index),
                  width: 23,
                  height: 17,
                )
              : Container(
                  width: 23,
                  height: 17,
                  decoration: BoxDecoration(
                    color: design.colors[index],
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: line),
                  ),
                ),
        ),
        if (kind == BookDetailKind.pressedFlower) ...[
          const SizedBox(height: 10),
          _DetailChoices(
            title: '위치',
            control: 'detail-pressedFlower-placement',
            labels: const ['오른쪽 아래', '왼쪽 아래', '아래 가운데'],
            selected: choice.placement,
            onSelected: choice.enabled
                ? (index) =>
                      onChanged((current) => current.copy(placement: index))
                : null,
          ),
        ],
      ],
    );
  }
}

class BookDetailSample extends StatelessWidget {
  const BookDetailSample({
    super.key,
    required this.kind,
    required this.choice,
    this.size = const Size(62, 38),
  });

  final BookDetailKind kind;
  final BookDetailChoice choice;
  final Size size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: ExcludeFocus(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: line),
              color: const Color(0xfff3eadb),
            ),
            child: Opacity(
              opacity: choice.enabled ? 1 : .42,
              child: MediaQuery.withNoTextScaling(
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: switch (kind) {
                    BookDetailKind.ribbon => Center(
                      child: RibbonBookmark(
                        choice: choice.copy(enabled: true),
                        width: 10,
                        height: 25,
                      ),
                    ),
                    BookDetailKind.pressedFlower => Center(
                      child: PressedFlower(
                        choice: choice.copy(enabled: true),
                        size: 26,
                      ),
                    ),
                    _ => FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: 155,
                        child: BookDetailPreview(
                          kind: kind,
                          choice: choice.copy(enabled: true),
                        ),
                      ),
                    ),
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Synthetic specimens: never create pages, owner data, marks or dates.
class BookDetailPreview extends StatelessWidget {
  const BookDetailPreview({
    super.key,
    required this.kind,
    required this.choice,
    this.stock = 0,
  });
  final BookDetailKind kind;
  final BookDetailChoice choice;
  final int stock;
  @override
  Widget build(BuildContext context) => switch (kind) {
    BookDetailKind.ribbon => _RibbonSpread(choice: choice, stock: stock),
    BookDetailKind.bookplate => Bookplate(
      title: '오래 곁에 둘 문장들',
      owner: '쓰는 사람',
      summary: '모양 미리보기',
      onOwner: () {},
      choice: choice,
      margin: EdgeInsets.zero,
    ),
    BookDetailKind.sourceSlip => SourceSlip(
      choice: choice,
      child: const Text(
        '오래 곁에 두고 싶은\n문장을 한 줄씩 옮깁니다.',
        style: TextStyle(
          fontFamily: appFontFamily,
          fontFamilyFallback: appFontFallback,
          fontSize: 16,
          height: 1.8,
          color: ink,
        ),
      ),
    ),
    BookDetailKind.pencil => Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text.rich(
        pencilTextSpan(
          value: const TextEditingValue(text: '마음이 머문 문장을 씁니다.'),
          marks: const [PencilMark(0, 9)],
          choice: choice,
        ),
        style: const TextStyle(
          fontFamily: appFontFamily,
          fontFamilyFallback: appFontFallback,
          fontSize: 18,
          height: 1.8,
          color: ink,
        ),
      ),
    ),
    BookDetailKind.ornament => Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Center(
        child: SizedBox(
          width: 220,
          child: PageOrnament(
            choice: choice,
            child: const Text(
              '12 / 24',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 13),
            ),
          ),
        ),
      ),
    ),
    BookDetailKind.binding => SizedBox(
      height: 110,
      child: ColoredBox(
        color: paper,
        child: Stack(
          fit: StackFit.expand,
          children: [
            BookBinding(choice: choice),
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 32),
                child: Text(
                  '한 권의 안쪽',
                  style: TextStyle(
                    fontFamily: appFontFamily,
                    fontFamilyFallback: appFontFallback,
                    fontSize: 18,
                    color: ink,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    BookDetailKind.recordDivider => RecordDivider(choice: choice),
    BookDetailKind.pressedFlower => SizedBox(
      height: 112,
      child: Align(
        alignment: flowerAlignment(choice),
        child: PressedFlower(choice: choice, size: 92),
      ),
    ),
    BookDetailKind.dateStamp => Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: DateStamp(date: '2026-11-10', choice: choice),
      ),
    ),
  };
}
