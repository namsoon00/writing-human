import 'package:flutter/material.dart';

import '../data/book_detail_style.dart';
import 'paper.dart';
import 'paper_navigation.dart';
export 'paper_navigation.dart';

MaterialPageRoute<T> paperPanelRoute<T>(
  WidgetBuilder builder, {
  Color color = paper,
  bool fullscreenDialog = false,
}) => MaterialPageRoute<T>(
  fullscreenDialog: fullscreenDialog,
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
  const PaperPanelHeader(
    this.title, {
    super.key,
    this.canClose = true,
    this.showBackButton = true,
    this.backLabel,
    this.onBack,
    this.allowWritingReturn = true,
  });
  final String title;
  final bool canClose;
  final bool showBackButton, allowWritingReturn;
  final String? backLabel;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    PaperNavigationScope.maybeOf(context)?.name(context, title);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaperHeaderRow(
          children: [
            if (showBackButton)
              PaperBackButton(
                label: backLabel,
                onPressed: onBack,
                enabled: canClose,
              )
            else
              const SizedBox(width: 48),
            Expanded(
              child: PaperPanelTitle(title, showInkMark: false, fontSize: 22),
            ),
            if (allowWritingReturn) PaperWritingReturn(enabled: canClose),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: line),
        const SizedBox(height: 8),
      ],
    );
  }
}

class PaperPanelTitle extends StatelessWidget {
  const PaperPanelTitle(
    this.title, {
    super.key,
    this.fontSize = 25,
    this.showInkMark = false,
  });
  final String title;
  final double fontSize;
  final bool showInkMark;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showInkMark) ...[
          const InkMark(size: 13),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(
            title,
            textAlign: TextAlign.center,
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

class PaperSettingsSaveNotice extends StatelessWidget {
  const PaperSettingsSaveNotice({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Semantics(
              liveRegion: true,
              child: const Text(
                '설정을 저장하지 못했어요.',
                style: TextStyle(color: burgundy),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('다시 저장')),
          ],
        ),
      ],
    ),
  );
}

/// Compatibility entry point for callers that used a temporary sheet. The
/// destination now occupies a normal full screen and follows page navigation.
MaterialPageRoute<T> paperSheetRoute<T>(WidgetBuilder builder) =>
    paperPanelRoute<T>(builder);

/// Equal side columns keep the title at the screen's center even when the
/// actions are asymmetric. Actions wrap within their own column at large type.
class PaperHeaderRow extends StatelessWidget {
  const PaperHeaderRow({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final middle = children.indexWhere((child) => child is Flexible);
      if (middle < 0) return Row(children: children);
      final title = (children[middle] as Flexible).child;
      final sideWidth = (box.maxWidth / 3).clamp(48.0, 144.0);
      Widget side(Iterable<Widget> items, WrapAlignment alignment) => SizedBox(
        width: sideWidth,
        child: Wrap(
          alignment: alignment,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final child in items.where((child) => child is! Spacer))
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: sideWidth),
                child: child,
              ),
          ],
        ),
      );
      return Row(
        children: [
          side(children.take(middle), WrapAlignment.start),
          Expanded(child: Center(child: title)),
          side(children.skip(middle + 1), WrapAlignment.end),
        ],
      );
    },
  );
}
