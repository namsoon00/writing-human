import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../data/library_controller.dart';
import '../data/model.dart';
import 'book_detail_design.dart';
import 'book_details.dart';
import 'paper_palette.dart';
import 'pencil_marks.dart';
import 'reading_details.dart';

class BookDetailTools extends StatelessWidget {
  const BookDetailTools({super.key, required this.controller});
  final LibraryController controller;
  void _change(BookDetailKind kind, BookDetailChoice choice) {
    final current = controller.library.style;
    controller.setStyle(
      current.copy(bookDetails: current.bookDetails.withChoice(kind, choice)),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .86,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '책의 디테일',
                      style: TextStyle(
                        fontFamily: appFontFamily,
                        fontFamilyFallback: appFontFallback,
                        fontSize: 21,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '디테일 닫기',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(CupertinoIcons.xmark, size: 18),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Text(
                '모양과 색을 고르면 바로 적용돼요.\n꾸밈을 꺼도 글과 기록은 그대로 남아요.',
                style: TextStyle(color: muted, fontSize: 12, height: 1.7),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final kind in BookDetailKind.values)
                    _item(context, kind),
                ],
              ),
            ),
            if (controller.saveError != null)
              TextButton(
                onPressed: controller.retrySave,
                child: const Text(
                  '설정 저장 실패 · 다시 시도',
                  style: TextStyle(color: burgundy),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _item(BuildContext context, BookDetailKind kind) {
    final design = BookDetailDesign.of(kind),
        choice = controller.library.style.bookDetails.choice(kind);
    return ExpansionTile(
      key: ValueKey('detail-${kind.name}'),
      initiallyExpanded: kind == BookDetailKind.ribbon,
      tilePadding: const EdgeInsets.symmetric(horizontal: 24),
      childrenPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      title: Text(
        design.title,
        style: const TextStyle(
          fontFamily: appFontFamily,
          fontFamilyFallback: appFontFallback,
          fontSize: 17,
        ),
      ),
      subtitle: Text(
        choice.enabled
            ? '${design.variants[choice.variant]} · ${design.tones[choice.tone]}'
            : '꾸밈 숨김',
        style: const TextStyle(color: muted, fontSize: 11),
      ),
      children: [
        BookDetailOptions(
          kind: kind,
          choice: choice,
          onChanged: (value) => _change(kind, value),
        ),
      ],
    );
  }
}

class BookDetailOptions extends StatelessWidget {
  const BookDetailOptions({
    super.key,
    required this.kind,
    required this.choice,
    required this.onChanged,
    this.showSpecimen = true,
  });

  final BookDetailKind kind;
  final BookDetailChoice choice;
  final ValueChanged<BookDetailChoice> onChanged;
  final bool showSpecimen;

  @override
  Widget build(BuildContext context) {
    final design = BookDetailDesign.of(kind);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showSpecimen) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              design.description,
              style: const TextStyle(color: muted, fontSize: 12, height: 1.6),
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            label: '${design.title} 모양 미리보기',
            child: ExcludeSemantics(
              child: ExcludeFocus(
                child: IgnorePointer(
                  child: BookDetailPreview(kind: kind, choice: choice),
                ),
              ),
            ),
          ),
        ],
        SwitchListTile.adaptive(
          key: ValueKey('detail-${kind.name}-enabled'),
          contentPadding: EdgeInsets.zero,
          title: const Text('꾸밈 표시', style: TextStyle(fontSize: 13)),
          value: choice.enabled,
          activeTrackColor: burgundy,
          onChanged: (value) => onChanged(choice.copy(enabled: value)),
        ),
        if (!showSpecimen && kind == BookDetailKind.ribbon) ...[
          const SizedBox(height: 8),
          const Text('리본 색'),
          Wrap(
            spacing: 10,
            children: [
              for (var i = 0; i < design.colors.length; i++)
                Semantics(
                  label: design.tones[i],
                  selected: choice.tone == i,
                  child: IconButton(
                    key: ValueKey('detail-ribbon-tone-$i'),
                    tooltip: design.tones[i],
                    onPressed: choice.enabled
                        ? () => onChanged(choice.copy(tone: i))
                        : null,
                    icon: Container(
                      width: 30,
                      height: 30,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: choice.tone == i
                              ? design.colors[i]
                              : Colors.transparent,
                        ),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: design.colors[i].withValues(
                            alpha: choice.enabled ? 1 : .35,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('리본 모양'),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < design.variants.length; i++)
                ChoiceChip(
                  key: ValueKey('detail-${kind.name}-variant-$i'),
                  label: Text(
                    design.variants[i],
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: choice.variant == i,
                  showCheckmark: false,
                  onSelected: choice.enabled
                      ? (_) => onChanged(choice.copy(variant: i))
                      : null,
                ),
            ],
          ),
        ),
        if (showSpecimen || kind != BookDetailKind.ribbon) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < design.tones.length; i++)
                  ChoiceChip(
                    key: ValueKey('detail-${kind.name}-tone-$i'),
                    avatar: ExcludeSemantics(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: design.colors[i],
                          shape: BoxShape.circle,
                          border: Border.all(color: line),
                        ),
                      ),
                    ),
                    label: Text(
                      design.tones[i],
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: choice.tone == i,
                    showCheckmark: false,
                    onSelected: choice.enabled
                        ? (_) => onChanged(choice.copy(tone: i))
                        : null,
                  ),
              ],
            ),
          ),
        ],
        if (kind == BookDetailKind.pressedFlower) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < 3; i++)
                  ChoiceChip(
                    key: ValueKey('detail-pressedFlower-placement-$i'),
                    label: Text(
                      ['오른쪽 아래', '왼쪽 아래', '아래 가운데'][i],
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: choice.placement == i,
                    showCheckmark: false,
                    onSelected: choice.enabled
                        ? (_) => onChanged(choice.copy(placement: i))
                        : null,
                  ),
              ],
            ),
          ),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: ValueKey('detail-${kind.name}-reset'),
            onPressed: () => onChanged(const BookDetailChoice()),
            child: const Text('이 요소만 기본으로', style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }
}

/// Synthetic specimens: never create pages, owner data, marks or dates.
class BookDetailPreview extends StatelessWidget {
  const BookDetailPreview({
    super.key,
    required this.kind,
    required this.choice,
  });
  final BookDetailKind kind;
  final BookDetailChoice choice;
  @override
  Widget build(BuildContext context) => switch (kind) {
    BookDetailKind.ribbon => SizedBox(
      height: 82,
      child: Stack(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '이어서 쓰는 위치',
              style: TextStyle(
                fontFamily: appFontFamily,
                fontFamilyFallback: appFontFallback,
                fontSize: 17,
                color: ink,
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 28,
            child: RibbonBookmark(choice: choice, width: 17, height: 64),
          ),
        ],
      ),
    ),
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
