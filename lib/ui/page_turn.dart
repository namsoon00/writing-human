import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/model.dart';
import 'paper.dart';

/// Exactly one live editor is mounted. Only the outgoing page is painted as a
/// non-interactive preview; it has no input, focus or persistence listeners.
class PageTurnView extends StatefulWidget {
  const PageTurnView({
    super.key,
    required this.page,
    required this.style,
    required this.editing,
    required this.child,
  });
  final WritingPage page;
  final WritingStyle style;
  final bool editing;
  final Widget child;
  @override
  State<PageTurnView> createState() => _PageTurnViewState();
}

class _PageTurnViewState extends State<PageTurnView>
    with SingleTickerProviderStateMixin {
  late final AnimationController turn;

  @override
  void initState() {
    super.initState();
    turn =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 360),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => outgoing = null);
          }
        });
  }

  WritingPage? outgoing;
  WritingStyle? outgoingStyle;
  bool forward = true, reduced = false;

  void stop() {
    turn.stop();
    outgoing = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduced =
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled;
    if (reduced) stop();
  }

  @override
  void didUpdateWidget(PageTurnView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editing) {
      // Typing on the new page takes precedence over the remaining decoration.
      stop();
    } else if (oldWidget.page.id != widget.page.id) {
      if (reduced || oldWidget.page.text.length > 20000) {
        stop();
      } else {
        outgoing = oldWidget.page;
        outgoingStyle = oldWidget.style;
        forward =
            oldWidget.page.recordId != widget.page.recordId ||
            widget.page.number >= oldWidget.page.number;
        turn.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.hardEdge,
    fit: StackFit.expand,
    children: [
      widget.child,
      if (outgoing != null)
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: turn,
                child: RepaintBoundary(
                  child: _PrintedPage(page: outgoing!, style: outgoingStyle!),
                ),
                builder: (context, child) {
                  final progress = Curves.easeInOutCubic.transform(turn.value);
                  return CustomPaint(
                    key: const ValueKey('page-turn-overlay'),
                    foregroundPainter: _Fold(
                      progress,
                      forward,
                      paperColors[outgoingStyle!.paperIndex],
                    ),
                    child: ClipPath(
                      clipper: _Peel(progress, forward),
                      child: child,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
    ],
  );
}

/// Recreates the last visible prose without retaining an outgoing TextField.
class _PrintedPage extends StatelessWidget {
  const _PrintedPage({required this.page, required this.style});
  final WritingPage page;
  final WritingStyle style;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => DecoratedBox(
      decoration: BoxDecoration(
        color: paperColors[style.paperIndex],
        image: DecorationImage(
          image: const AssetImage('assets/images/cotton-paper.jpg'),
          repeat: ImageRepeat.repeat,
          scale: 2,
          opacity: .24,
        ),
      ),
      child: CustomPaint(
        painter: _Prose(
          page,
          style,
          writingPagePadding(constraints.biggest),
          MediaQuery.textScalerOf(context),
        ),
      ),
    ),
  );
}

class _Prose extends CustomPainter {
  _Prose(this.page, this.style, this.padding, this.scaler);
  final WritingPage page;
  final WritingStyle style;
  final EdgeInsets padding;
  final TextScaler scaler;
  @override
  void paint(Canvas canvas, Size size) {
    if (page.text.isEmpty) return;
    final text = TextPainter(
      text: TextSpan(
        text: page.text,
        style: writingTextStyle(
          style.fontIndex,
          color: penColors[style.penIndex],
          useDevelopmentTypeface: style.useDevelopmentTypeface,
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout(maxWidth: math.max(1, size.width - padding.horizontal));
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    text.paint(canvas, Offset(padding.left, padding.top - page.scroll));
    canvas.restore();
    text.dispose();
  }

  @override
  bool shouldRepaint(_Prose old) =>
      old.page != page ||
      old.style != style ||
      old.padding != padding ||
      old.scaler != scaler;
}

Path _visiblePage(Size size, double t, bool forward) {
  final crease = size.width * (1 - t);
  final bend = math.sin(t * math.pi) * size.width * .10;
  final path = Path()
    ..moveTo(0, 0)
    ..lineTo(crease, 0)
    ..cubicTo(
      crease - bend,
      size.height * .32,
      crease + bend * .55,
      size.height * .72,
      crease,
      size.height,
    )
    ..lineTo(0, size.height)
    ..close();
  return forward
      ? path
      : path.transform(
          (Matrix4.identity()
                ..translateByDouble(size.width, 0, 0, 1)
                ..scaleByDouble(-1, 1, 1, 1))
              .storage,
        );
}

class _Peel extends CustomClipper<Path> {
  _Peel(this.progress, this.forward);
  final double progress;
  final bool forward;
  @override
  Path getClip(Size size) => _visiblePage(size, progress, forward);
  @override
  bool shouldReclip(_Peel old) =>
      old.progress != progress || old.forward != forward;
}

class _Fold extends CustomPainter {
  _Fold(this.progress, this.forward, this.color);
  final double progress;
  final bool forward;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final wave = math.sin(progress * math.pi);
    if (wave < .01) return;
    canvas.save();
    if (!forward) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final x = size.width * (1 - progress),
        bend = wave * size.width * .10,
        band = wave * math.min(64, size.width * .17);
    final edge = Path()
      ..moveTo(x, 0)
      ..cubicTo(
        x - bend,
        size.height * .32,
        x + bend * .55,
        size.height * .72,
        x,
        size.height,
      );
    canvas.drawPath(
      edge,
      Paint()
        ..color = const Color(0xff63513c).withValues(alpha: .16 * wave)
        ..style = PaintingStyle.stroke
        ..strokeWidth = band * .6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    final fold = Path()
      ..addPath(edge, Offset.zero)
      ..lineTo(x + band, size.height)
      ..cubicTo(
        x + band + bend * .55,
        size.height * .72,
        x + band - bend,
        size.height * .32,
        x + band,
        0,
      )
      ..close();
    canvas.drawPath(
      fold,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Color.lerp(color, const Color(0xff99866c), .20)!,
            const Color(0xfffffbf2),
            color,
          ],
        ).createShader(Rect.fromLTWH(x - bend, 0, band + bend, size.height)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Fold old) =>
      old.progress != progress || old.forward != forward || old.color != color;
}
