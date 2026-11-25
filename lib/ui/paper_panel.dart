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
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            PaperBackButton(
              label: backLabel,
              onPressed: onBack,
              enabled: canClose,
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * .7,
              ),
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
    this.showInkMark = true,
  });
  final String title;
  final double fontSize;
  final bool showInkMark;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showInkMark) ...[
          const InkMark(size: 13),
          const SizedBox(width: 10),
        ],
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

/// One temporary panel over the existing paper. Its pop uses the same guards
/// as a button/system back; dragging never edits the underlying document.
PageRoute<T> paperSheetRoute<T>(WidgetBuilder builder) => PageRouteBuilder<T>(
  opaque: false,
  fullscreenDialog: true,
  barrierDismissible: true,
  barrierColor: Colors.black.withValues(alpha: .14),
  barrierLabel: '이전 화면으로 돌아가기',
  pageBuilder: (context, animation, secondaryAnimation) =>
      _PaperSheetFrame(child: builder(context)),
  transitionsBuilder: (context, animation, secondaryAnimation, child) =>
      SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
);

class _PaperSheetFrame extends StatefulWidget {
  const _PaperSheetFrame({required this.child});
  final Widget child;
  @override
  State<_PaperSheetFrame> createState() => _PaperSheetFrameState();
}

class _PaperSheetFrameState extends State<_PaperSheetFrame> {
  double drag = 0;
  bool moving = false;

  Future<void> _release([double velocity = 0]) async {
    if (drag > 70 || velocity > 700) {
      await Navigator.maybePop(context);
    }
    if (mounted) {
      setState(() {
        drag = 0;
        moving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final tall =
        media.size.width > media.size.height || media.textScaler.scale(16) > 22;
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: 600,
        height: media.size.height * (tall ? .96 : .74),
        child: AnimatedSlide(
          offset: Offset(0, drag / (media.size.height * (tall ? .96 : .74))),
          duration: Duration(milliseconds: moving ? 0 : 160),
          child: Material(
            key: const ValueKey('paper-sheet'),
            color: paper,
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Column(
              children: [
                Semantics(
                  label: '아래로 내려 돌아가기',
                  button: true,
                  onTap: () => Navigator.maybePop(context),
                  child: GestureDetector(
                    key: const ValueKey('paper-sheet-handle'),
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: (_) => setState(() => moving = true),
                    onVerticalDragUpdate: (event) => setState(() {
                      drag = (drag + event.delta.dy).clamp(
                        0.0,
                        media.size.height,
                      );
                    }),
                    onVerticalDragCancel: () => _release(),
                    onVerticalDragEnd: (event) =>
                        _release(event.primaryVelocity ?? 0),
                    child: SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: muted.withValues(alpha: .5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Navigation actions wrap before they can squeeze a title or overflow at large type.
class PaperHeaderRow extends StatelessWidget {
  const PaperHeaderRow({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (MediaQuery.sizeOf(context).width >= 360 &&
          MediaQuery.textScalerOf(context).scale(16) <= 21) {
        return Row(children: children);
      }
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final child in children.where((child) => child is! Spacer))
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: child is Flexible ? box.maxWidth * .55 : box.maxWidth,
              ),
              child: child is Flexible ? child.child : child,
            ),
        ],
      );
    },
  );
}
