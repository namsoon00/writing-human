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
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      IconButton(
        tooltip: '닫기',
        onPressed: canClose ? () => Navigator.maybePop(context) : null,
        icon: const Icon(CupertinoIcons.xmark, size: 18),
      ),
    ],
  );
}
