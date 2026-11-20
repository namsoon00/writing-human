import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/book_detail_style.dart';
import 'paper.dart';

MaterialPageRoute<T> paperPanelRoute<T>(
  WidgetBuilder builder, {
  Color color = paper,
}) => MaterialPageRoute<T>(
  fullscreenDialog: true,
  builder: (context) => Scaffold(
    key: const ValueKey('paper-panel-page'),
    backgroundColor: color,
    body: builder(context),
  ),
);

/// Paint behind the safe areas and reserve them only for the controls.
class PaperPanel extends StatelessWidget {
  const PaperPanel({
    super.key,
    required this.child,
    this.color = paper,
    this.grainOpacity = panelGrainOpacity,
  });

  final Widget child;
  final Color color;
  final double grainOpacity;

  @override
  Widget build(BuildContext context) => PaperBackdrop(
    color: color,
    outsideColor: color,
    grainOpacity: grainOpacity,
    binding: const BookDetailChoice(enabled: false),
    child: SafeArea(
      child: SizedBox.expand(
        child: Center(
          child: SizedBox(width: 600, child: SizedBox.expand(child: child)),
        ),
      ),
    ),
  );
}

class PaperPanelHeader extends StatelessWidget {
  const PaperPanelHeader(this.title, {super.key, this.canClose = true});
  final String title;
  final bool canClose;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(child: PaperPanelTitle(title)),
          IconButton(
            tooltip: '닫기',
            onPressed: canClose ? () => Navigator.maybePop(context) : null,
            icon: const Icon(CupertinoIcons.xmark, size: 18),
          ),
        ],
      ),
      const SizedBox(height: 12),
      const DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: line)),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 36,
            height: 2,
            child: ColoredBox(color: brandInk),
          ),
        ),
      ),
      const SizedBox(height: 8),
    ],
  );
}

class PaperPanelTitle extends StatelessWidget {
  const PaperPanelTitle(this.title, {super.key, this.fontSize = 25});
  final String title;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Row(
      children: [
        const InkMark(size: 13),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              color: brandInk,
              height: 1.3,
              letterSpacing: -.5,
            ),
          ),
        ),
      ],
    ),
  );
}
