import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'paper_palette.dart';

const _slip = Color(0xfffff5df);
const _edge = Color(0xffcbb088);

class PaperSelectionMenu extends StatefulWidget {
  const PaperSelectionMenu({
    super.key,
    required this.anchors,
    required this.editActions,
    required this.writingActions,
    required this.otherActions,
  });

  final TextSelectionToolbarAnchors anchors;
  final List<ContextMenuButtonItem> editActions, writingActions, otherActions;

  @override
  State<PaperSelectionMenu> createState() => _PaperSelectionMenuState();
}

class _PaperSelectionMenuState extends State<PaperSelectionMenu> {
  bool expanded = false;

  Widget _action(ContextMenuButtonItem item) {
    final label =
        item.label ??
        switch (item.type) {
          ContextMenuButtonType.copy => '복사',
          ContextMenuButtonType.cut => '잘라내기',
          ContextMenuButtonType.paste => '붙여넣기',
          ContextMenuButtonType.selectAll => '전체 선택',
          _ => throw StateError('Missing selection action label'),
        };
    return TextButton(
      onPressed: item.onPressed,
      style: TextButton.styleFrom(
        foregroundColor: brandInk,
        minimumSize: const Size(44, 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        textStyle: const TextStyle(
          fontSize: 12,
          fontFamily: appFontFamily,
          fontFamilyFallback: appFontFallback,
        ),
      ),
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final view = MediaQuery.viewPaddingOf(context);
    final inset = MediaQuery.viewInsetsOf(context);
    final padding = EdgeInsets.fromLTRB(
      view.left + 8,
      view.top + 8,
      view.right + 8,
      math.max(view.bottom, inset.bottom) + 8,
    );
    final origin = Offset(padding.left, padding.top);
    return Padding(
      padding: padding,
      child: CustomMultiChildLayout(
        delegate: _SlipLayout(
          widget.anchors.primaryAnchor - origin,
          (widget.anchors.secondaryAnchor ?? widget.anchors.primaryAnchor) -
              origin,
        ),
        children: [
          LayoutId(
            id: _SlipPart.point,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: math.pi / 4,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: _slip,
                    border: Border.fromBorderSide(BorderSide(color: _edge)),
                  ),
                ),
              ),
            ),
          ),
          LayoutId(
            id: _SlipPart.menu,
            child: TextFieldTapRegion(
              child: Material(
                key: const ValueKey('paper-selection-menu'),
                color: _slip,
                elevation: 3,
                shadowColor: const Color(0x48493117),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                  side: const BorderSide(color: _edge),
                ),
                child: SingleChildScrollView(
                  primary: false,
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ...widget.editActions.map(_action),
                          if (widget.editActions.isNotEmpty &&
                              widget.writingActions.isNotEmpty)
                            const SizedBox(
                              height: 21,
                              width: 1,
                              child: ColoredBox(color: _edge),
                            ),
                          ...widget.writingActions.map(_action),
                          if (widget.otherActions.isNotEmpty)
                            IconButton(
                              tooltip: expanded ? '편집 메뉴 접기' : '편집 메뉴 더 보기',
                              onPressed: () =>
                                  setState(() => expanded = !expanded),
                              constraints: const BoxConstraints.tightFor(
                                width: 44,
                                height: 44,
                              ),
                              color: brandInk,
                              icon: Icon(
                                expanded ? Icons.expand_less : Icons.more_horiz,
                                size: 19,
                              ),
                            ),
                        ],
                      ),
                      if (expanded && widget.otherActions.isNotEmpty)
                        Wrap(
                          alignment: WrapAlignment.center,
                          children: widget.otherActions.map(_action).toList(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _SlipPart { point, menu }

class _SlipLayout extends MultiChildLayoutDelegate {
  _SlipLayout(this.above, this.below);

  final Offset above, below;

  @override
  void performLayout(Size size) {
    final menu = layoutChild(_SlipPart.menu, BoxConstraints.loose(size));
    const gap = 10.0;
    final roomAbove = above.dy - gap;
    final roomBelow = size.height - below.dy - gap;
    final useAbove = roomAbove >= menu.height || roomAbove >= roomBelow;
    final anchor = useAbove ? above : below;
    final x = (anchor.dx - menu.width / 2).clamp(0.0, size.width - menu.width);
    final y = (useAbove ? anchor.dy - gap - menu.height : anchor.dy + gap)
        .clamp(0.0, size.height - menu.height);
    positionChild(_SlipPart.menu, Offset(x, y));
    layoutChild(
      _SlipPart.point,
      const BoxConstraints.tightFor(width: 8, height: 8),
    );
    final pointX = (anchor.dx - 4).clamp(
      x + 7,
      x + math.max(7, menu.width - 15),
    );
    final pointY = useAbove ? y + menu.height - 4 : y - 4;
    positionChild(_SlipPart.point, Offset(pointX, pointY));
  }

  @override
  bool shouldRelayout(_SlipLayout oldDelegate) =>
      above != oldDelegate.above || below != oldDelegate.below;
}
