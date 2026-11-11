import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import '../data/model.dart';
import 'paper.dart';

/// Connects the paper and footer recognizers to the same turn surface.
class PageTurnController {
  _PageTurnViewState? _view;
  void start({Offset? origin}) => _view?._startDrag(origin);
  void update(double distance) => _view?._updateDrag(distance);
  void end(double distance, double velocity) =>
      unawaited(_view?._finishDrag(distance, velocity));
  void cancel() => unawaited(_view?._finishDrag(0, 0, canceled: true));
}

/// A drag peels the live paper over a read-only neighbour. Non-gesture jumps
/// can still use a disposable image of the previously painted surface.
class PageTurnView extends StatefulWidget {
  const PageTurnView({
    super.key,
    required this.page,
    required this.style,
    required this.editing,
    this.composing = false,
    required this.child,
    required this.controller,
    required this.scopeId,
    required this.position,
    required this.onTurn,
    this.previous,
    this.next,
  });
  final WritingPage page;
  final WritingStyle style;
  final bool editing, composing;
  final Widget child;
  final PageTurnController controller;
  final String scopeId;
  // -1 is the front cover. This is deliberately not a saved page number.
  final int position;
  final Widget? previous, next;
  final Future<bool> Function(bool forward) onTurn;
  @override
  State<PageTurnView> createState() => _PageTurnViewState();
}

class _PageTurnViewState extends State<PageTurnView>
    with TickerProviderStateMixin {
  late final AnimationController turn;
  late final AnimationController dragProgress;
  bool _resetting = false;
  bool _dragging = false, _ending = false, _committing = false;
  bool _dragForward = true;
  int _gestureVersion = 0;
  Widget? _preview;
  Size _surfaceSize = Size.zero;
  Offset? _dragOrigin;
  final surface = GlobalKey();
  ui.Image? outgoing;
  WritingStyle? outgoingStyle;
  bool forward = true, reduced = false;
  Size? viewport;
  EdgeInsets? insets;

  @override
  void initState() {
    super.initState();
    widget.controller._view = this;
    turn =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 360),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(_stopImage);
          }
        });
    dragProgress = AnimationController(vsync: this)
      ..addListener(() {
        if (mounted && !_resetting) setState(() {});
      });
  }

  void _stopImage() {
    turn.stop();
    outgoing?.dispose();
    outgoing = null;
  }

  void _resetDrag() {
    _gestureVersion++;
    dragProgress.stop();
    _dragging = _ending = _committing = false;
    _preview = null;
    _dragOrigin = null;
    _resetting = true;
    dragProgress.value = 0;
    _resetting = false;
  }

  void _startDrag(Offset? origin) {
    if (_dragging ||
        _ending ||
        widget.composing ||
        _surfaceSize.isEmpty ||
        (widget.previous == null && widget.next == null)) {
      return;
    }
    setState(() {
      _stopImage();
      _resetDrag();
      _dragging = true;
      _dragOrigin = origin;
    });
  }

  void _updateDrag(double distance) {
    if (!_dragging) return;
    _dragForward = distance < 0;
    _preview = distance == 0
        ? null
        : _dragForward
        ? widget.next
        : widget.previous;
    dragProgress.value = _preview == null
        ? 0
        : (distance.abs() / _surfaceSize.width).clamp(0.0, 1.0);
  }

  bool get _fromCorner {
    final origin = _dragOrigin;
    if (origin == null || origin.dy < _surfaceSize.height * .64) return false;
    final reach = math.min(96, _surfaceSize.width * .25);
    return _dragForward
        ? origin.dx >= _surfaceSize.width - reach
        : origin.dx <= reach;
  }

  Future<void> _easeTo(double value) async {
    if (reduced || !widget.style.pageMotion) {
      dragProgress.value = value;
      return;
    }
    final remaining = (value - dragProgress.value).abs();
    if (remaining == 0) return;
    await dragProgress
        .animateTo(
          value,
          duration: Duration(
            milliseconds: (remaining * 220).round().clamp(60, 220),
          ),
          curve: Curves.easeOutCubic,
        )
        .orCancel;
  }

  Future<void> _finishDrag(
    double distance,
    double velocity, {
    bool canceled = false,
  }) async {
    if (!_dragging) return;
    if (!canceled) _updateDrag(distance);
    _dragging = false;
    final version = _gestureVersion;
    if (_preview == null || dragProgress.value == 0) {
      setState(_resetDrag);
      return;
    }
    final sameDirection = distance * velocity > 0;
    final commit =
        !canceled &&
        !(velocity.abs() >= 500 && !sameDirection) &&
        (dragProgress.value >= .32 ||
            (distance.abs() >= 36 && velocity.abs() >= 500));
    _ending = true;
    try {
      await _easeTo(commit ? 1 : 0);
      if (!mounted || version != _gestureVersion) return;
      if (commit) {
        _committing = true;
        final changed = await widget.onTurn(_dragForward);
        if (!mounted || version != _gestureVersion) return;
        if (changed) {
          // Swap the preview only after the real page has had a frame to mount.
          await WidgetsBinding.instance.endOfFrame;
        } else {
          _committing = false;
          await _easeTo(0);
        }
      }
    } on TickerCanceled {
      // Rotation, input, a different record, or disposal already reset the turn.
    } finally {
      if (mounted && version == _gestureVersion) setState(_resetDrag);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextReduced =
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled;
    final nextViewport = MediaQuery.sizeOf(context);
    final nextInsets = MediaQuery.viewInsetsOf(context);
    if (reduced != nextReduced ||
        viewport != nextViewport ||
        insets != nextInsets) {
      _stopImage();
      if (!_committing) _resetDrag();
    }
    reduced = nextReduced;
    viewport = nextViewport;
    insets = nextInsets;
  }

  @override
  void didUpdateWidget(PageTurnView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller._view = null;
      widget.controller._view = this;
      _stopImage();
      _resetDrag();
    }
    final moved =
        oldWidget.page.id != widget.page.id ||
        (oldWidget.position < 0) != (widget.position < 0);
    if (oldWidget.scopeId != widget.scopeId ||
        widget.composing ||
        (widget.editing && !oldWidget.editing)) {
      _stopImage();
      _resetDrag();
      return;
    }
    if (_dragging || _ending) {
      // The destination is now live. Do not keep its preview on top while
      // the save queue writes the new active position.
      if (moved ||
          oldWidget.page.text != widget.page.text ||
          oldWidget.style.paperIndex != widget.style.paperIndex ||
          oldWidget.style.pageMotion != widget.style.pageMotion) {
        _resetDrag();
      }
      return;
    }
    if (widget.editing) {
      _stopImage();
      return;
    }
    if (!moved) return;
    _stopImage();
    if (reduced ||
        !widget.style.pageMotion ||
        oldWidget.page.text.length > 20000) {
      return;
    }
    final boundary = surface.currentContext?.findRenderObject();
    if (boundary is! _PaperSurfaceBoundary ||
        !boundary.hasSize ||
        boundary.size.isEmpty) {
      return;
    }
    try {
      outgoing = boundary.capture();
      if (outgoing == null) return;
    } catch (error) {
      debugPrint('Page turn preview unavailable: $error');
      return;
    }
    outgoingStyle = oldWidget.style;
    forward = widget.position >= oldWidget.position;
    turn.forward(from: 0);
  }

  @override
  void dispose() {
    if (identical(widget.controller._view, this)) {
      widget.controller._view = null;
    }
    _stopImage();
    _resetDrag();
    dragProgress.dispose();
    turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _surfaceSize = constraints.biggest;
      final revealing =
          _preview != null &&
          dragProgress.value > 0 &&
          !reduced &&
          widget.style.pageMotion;
      final progress = dragProgress.value;
      final corner = revealing && _fromCorner;
      final color = paperColors[widget.style.paperIndex];
      Widget clipped(Widget child, {required bool incoming}) {
        final key = ValueKey(incoming ? 'page-turn-reveal' : 'page-turn-live');
        // Keep one stable wrapper type and key around the actual editor.
        return ClipRect(
          key: key,
          clipper: revealing && !corner
              ? PageRevealClipper(progress, _dragForward, incoming: incoming)
              : null,
          child: ClipPath(
            clipper: corner
                ? _CornerPeel(progress, _dragForward, incoming)
                : null,
            clipBehavior: corner ? Clip.antiAlias : Clip.none,
            child: child,
          ),
        );
      }

      return Stack(
        clipBehavior: Clip.hardEdge,
        fit: StackFit.expand,
        children: [
          if (revealing)
            Positioned.fill(
              child: ExcludeSemantics(
                child: IgnorePointer(
                  child: clipped(
                    RepaintBoundary(child: _preview),
                    incoming: true,
                  ),
                ),
              ),
            ),
          clipped(
            _PaperSurface(key: surface, child: widget.child),
            incoming: false,
          ),
          if (revealing)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  key: const ValueKey('page-turn-fold'),
                  painter: corner
                      ? _CornerFold(progress, _dragForward, color)
                      : _DraggedFold(progress, _dragForward, color),
                ),
              ),
            ),
          if (outgoing != null)
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: AnimatedBuilder(
                    animation: turn,
                    child: RepaintBoundary(
                      child: RawImage(
                        image: outgoing,
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    builder: (context, child) {
                      final progress = Curves.easeInOutCubic.transform(
                        turn.value,
                      );
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
    },
  );
}

/// The exposed width is exactly the drag distance, in either direction.
class PageRevealClipper extends CustomClipper<Rect> {
  const PageRevealClipper(this.progress, this.forward, {this.incoming = false});
  final double progress;
  final bool forward, incoming;
  @override
  Rect getClip(Size size) {
    final width = size.width * (incoming ? progress : 1 - progress);
    final atRight = forward == incoming;
    return Rect.fromLTWH(
      atRight ? size.width - width : 0,
      0,
      width,
      size.height,
    );
  }

  @override
  bool shouldReclip(PageRevealClipper old) =>
      old.progress != progress ||
      old.forward != forward ||
      old.incoming != incoming;
}

class _CornerGeometry {
  _CornerGeometry(this.size, double progress, this.forward)
    : top = size.width * (1 - progress * progress),
      bottom = size.width * math.max(0, 1 - progress * 1.55),
      lift = math.min(size.width * .18, 75) * math.sin(progress * math.pi);

  final Size size;
  final bool forward;
  final double top, bottom, lift;

  double x(double value) => forward ? value : size.width - value;

  Path crease() {
    final h = size.height;
    return Path()
      ..moveTo(x(top), 0)
      ..cubicTo(x(top), h * .57, x(top), h * .76, x(bottom), h);
  }

  Path get page => crease()
    ..lineTo(x(0), size.height)
    ..lineTo(x(0), 0)
    ..close();

  Path get underside {
    final h = size.height;
    return crease()
      ..cubicTo(
        x(math.max(0, bottom - lift * .8)),
        h * .92,
        x(math.max(0, (top + bottom) / 2 - lift)),
        h * .71,
        x(math.max(0, top - lift * .38)),
        h * .52,
      )
      ..quadraticBezierTo(x(top - lift * .1), h * .38, x(top), 0)
      ..close();
  }
}

class _CornerPeel extends CustomClipper<Path> {
  const _CornerPeel(this.progress, this.forward, this.incoming);
  final double progress;
  final bool forward, incoming;

  @override
  Path getClip(Size size) {
    final page = _CornerGeometry(size, progress, forward).page;
    if (!incoming) return page;
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addPath(page, Offset.zero);
  }

  @override
  bool shouldReclip(_CornerPeel old) =>
      old.progress != progress ||
      old.forward != forward ||
      old.incoming != incoming;
}

class _CornerFold extends CustomPainter {
  const _CornerFold(this.progress, this.forward, this.color);
  final double progress;
  final bool forward;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final curl = _CornerGeometry(size, progress, forward);
    if (curl.lift < .5) return;
    final underside = curl.underside;
    final bounds = underside.getBounds();
    final dark = Color.lerp(color, const Color(0xff7c664c), .36)!;
    final light = Color.lerp(color, Colors.white, .65)!;
    canvas.drawShadow(
      underside,
      const Color(0x83614a35),
      curl.lift * .16,
      true,
    );
    canvas.drawPath(
      underside,
      Paint()
        ..shader = LinearGradient(
          begin: forward ? Alignment.bottomLeft : Alignment.bottomRight,
          end: forward ? Alignment.topRight : Alignment.topLeft,
          colors: [light, color, light, dark],
          stops: const [0, .37, .58, 1],
        ).createShader(bounds),
    );
    canvas.drawPath(
      curl.crease(),
      Paint()
        ..color = light.withValues(alpha: .8)
        ..strokeWidth = .85
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_CornerFold old) =>
      old.progress != progress || old.forward != forward || old.color != color;
}

/// The shaded curl lies entirely on the departing paper, leaving the revealed
/// page readable even for a short drag.
class _DraggedFold extends CustomPainter {
  const _DraggedFold(this.progress, this.forward, this.color);
  final double progress;
  final bool forward;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final edge = size.width * (1 - progress);
    final wave = math.sin(progress * math.pi);
    final band = math.min(edge, math.min(54, size.width * .15) * wave);
    if (band <= .5) return;
    canvas.save();
    if (!forward) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final rect = Rect.fromLTWH(edge - band, 0, band, size.height);
    final fold = Path()
      ..moveTo(edge, 0)
      ..lineTo(edge, size.height)
      ..cubicTo(
        edge - band * .35,
        size.height * .80,
        edge - band,
        size.height * .64,
        edge - band,
        size.height * .46,
      )
      ..cubicTo(
        edge - band,
        size.height * .25,
        edge - band * .40,
        size.height * .10,
        edge,
        0,
      )
      ..close();
    canvas.drawPath(
      fold,
      Paint()
        ..shader = LinearGradient(
          colors: [
            color.withValues(alpha: .20),
            color,
            const Color(0xfffffbf2),
            Color.lerp(color, const Color(0xff938069), .36)!,
          ],
          stops: const [0, .24, .72, 1],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DraggedFold old) =>
      old.progress != progress || old.forward != forward || old.color != color;
}

/// The previously painted layer is still the outgoing screen during widget
/// updates. Capture that frame even if a button ripple has requested repaint.
/// No encoding, storage or extra live widget tree is involved.
class _PaperSurface extends SingleChildRenderObjectWidget {
  const _PaperSurface({super.key, required super.child});
  @override
  _PaperSurfaceBoundary createRenderObject(BuildContext context) =>
      _PaperSurfaceBoundary();
}

class _PaperSurfaceBoundary extends RenderRepaintBoundary {
  Size? paintedSize;
  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    paintedSize = size;
  }

  ui.Image? capture() {
    final previous = paintedSize, painted = layer;
    if (previous == null || previous.isEmpty || painted is! OffsetLayer) {
      return null;
    }
    final ratio = math.min(
      2.0,
      math.sqrt(2000000 / (previous.width * previous.height)),
    );
    return painted.toImageSync(Offset.zero & previous, pixelRatio: ratio);
  }
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
