import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'editable_geometry.dart';
import 'ink_mark.dart';
import 'paper_palette.dart';

/// Read-only feedback beside the native editable. Never writes input state.
class WritingPen extends StatefulWidget {
  const WritingPen({
    super.key,
    required this.controller,
    required this.scroll,
    required this.focus,
    required this.fieldKey,
    required this.animateInk,
    this.color = const Color(0xff302c27),
  });
  final TextEditingController controller;
  final ScrollController scroll;
  final FocusNode focus;
  final GlobalKey fieldKey;
  final bool animateInk;
  final Color color;

  @override
  State<WritingPen> createState() => _WritingPenState();
}

const _inkPointDiameter = 6.0;

class _WritingPenState extends State<WritingPen>
    with SingleTickerProviderStateMixin {
  late final drying = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: 1,
  );
  late TextEditingValue observed;
  Offset? target;
  Size? viewport;
  bool queued = false, reduced = false, newStroke = false;
  TextRange? freshRange;
  TextPainter? freshText;
  Path? freshClip;
  Offset freshOrigin = Offset.zero;

  bool get animateInk => widget.animateInk && !reduced;

  bool get composing =>
      widget.controller.value.isComposingRangeValid &&
      !widget.controller.value.composing.isCollapsed;

  @override
  void initState() {
    super.initState();
    observed = widget.controller.value;
    _listen(widget, true);
    _schedule();
  }

  void _listen(WritingPen pen, bool add) {
    if (add) {
      pen.controller.addListener(_textChanged);
      pen.scroll.addListener(_geometryChanged);
      pen.focus.addListener(_geometryChanged);
    } else {
      pen.controller.removeListener(_textChanged);
      pen.scroll.removeListener(_geometryChanged);
      pen.focus.removeListener(_geometryChanged);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduced =
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled;
    _settle();
    _schedule();
  }

  @override
  void didUpdateWidget(WritingPen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.scroll != widget.scroll ||
        oldWidget.focus != widget.focus) {
      _listen(oldWidget, false);
      _listen(widget, true);
      observed = widget.controller.value;
      _settle();
    }
    if (oldWidget.color != widget.color ||
        oldWidget.animateInk != widget.animateInk) {
      _settle();
    }
    _schedule();
  }

  void _settle() {
    drying.stop();
    drying.value = 1;
    freshRange = null;
    newStroke = false;
    freshText?.dispose();
    freshText = null;
    freshClip = null;
  }

  void _textChanged() {
    final before = observed;
    final next = widget.controller.value;
    observed = next;
    final wasComposing =
        before.isComposingRangeValid && !before.composing.isCollapsed;
    final caret = next.selection.extentOffset;
    final typed =
        next.text != before.text &&
        next.text.length >= before.text.length &&
        next.text.length - before.text.length <= 4;
    final committed = wasComposing && caret > before.composing.start;
    if (next == before) return;
    _settle();
    if (animateInk &&
        !composing &&
        next.selection.isValid &&
        next.selection.isCollapsed &&
        caret > 0 &&
        (typed || committed)) {
      final glyph = next.text.substring(0, caret).characters.last;
      if (glyph.trim().isNotEmpty) {
        freshRange = TextRange(start: caret - glyph.length, end: caret);
        newStroke = true;
      }
    }
    _schedule();
  }

  void _geometryChanged() {
    // Scrolling or moving focus must never leave wet ink at an old position.
    _settle();
    _schedule();
  }

  void _schedule() {
    if (queued) return;
    queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      queued = false;
      if (mounted) _readGeometry();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _readGeometry() {
    final value = widget.controller.value;
    Offset? next;
    final editable = findEditable(
      widget.fieldKey.currentContext?.findRenderObject(),
    );
    final overlay = context.findRenderObject();
    if (widget.focus.hasFocus &&
        value.selection.isValid &&
        value.selection.isCollapsed &&
        editable != null &&
        editable.attached &&
        editable.hasSize &&
        overlay is RenderBox &&
        overlay.hasSize) {
      final caret = editable.getLocalRectForCaret(value.selection.extent);
      if (caret.overlaps(Offset.zero & editable.size)) {
        final point = overlay.globalToLocal(
          editable.localToGlobal(caret.bottomCenter + const Offset(0, -1)),
        );
        if ((Offset.zero & overlay.size).contains(point)) next = point;
      }
      if (animateInk &&
          newStroke &&
          next != null &&
          !composing &&
          value.text.length <= 20000) {
        _prepareInk(editable, overlay);
      }
    }
    final animate =
        animateInk && newStroke && freshText != null && next != null;
    newStroke = false;
    if (target != next || animate) {
      setState(() => target = next);
    }
    if (animate) drying.forward(from: 0);
  }

  void _prepareInk(RenderEditable editable, RenderBox overlay) {
    final range = freshRange;
    if (range == null) return;
    final width = editable.size.width - editable.cursorWidth - 1;
    if (width <= 0) return;
    freshText?.dispose();
    final text = TextPainter(
      text: editable.text,
      textDirection: editable.textDirection,
      textAlign: editable.textAlign,
      textScaler: editable.textScaler,
      locale: editable.locale,
      strutStyle: editable.strutStyle,
      textHeightBehavior: editable.textHeightBehavior,
      textWidthBasis: editable.textWidthBasis,
    )..layout(maxWidth: width);
    final origin = overlay.globalToLocal(editable.localToGlobal(Offset.zero));
    final firstLine =
        editable
            .getEndpointsForSelection(const TextSelection.collapsed(offset: 0))
            .single
            .point
            .dy -
        editable.preferredLineHeight;
    freshOrigin = origin + Offset(0, firstLine);
    final clip = Path();
    for (final box in text.getBoxesForSelection(
      TextSelection(baseOffset: range.start, extentOffset: range.end),
      boxHeightStyle: ui.BoxHeightStyle.tight,
    )) {
      clip.addRect(box.toRect().shift(freshOrigin));
    }
    freshText = text;
    freshClip = clip;
  }

  @override
  void dispose() {
    _listen(widget, false);
    freshText?.dispose();
    drying.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (viewport != constraints.biggest) {
              viewport = constraints.biggest;
              _schedule();
            }
            return AnimatedBuilder(
              animation: drying,
              builder: (context, _) {
                final at = widget.focus.hasFocus ? target : null;
                final wet = (1 - drying.value * 3).clamp(0.0, 1.0);
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    if (at != null && freshText != null && wet > 0)
                      Positioned.fill(
                        child: CustomPaint(
                          key: const ValueKey('fresh-ink'),
                          painter: FreshInkPainter(
                            text: freshText!,
                            clip: freshClip!,
                            origin: freshOrigin,
                            opacity: wet * .2,
                          ),
                        ),
                      ),
                    if (at != null)
                      Positioned(
                        left: at.dx - _inkPointDiameter / 2,
                        top: at.dy - _inkPointDiameter / 2,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              left: -3,
                              right: -3,
                              top: -3,
                              bottom: -3,
                              child: InkMark(
                                key: const ValueKey('writing-ink-bleed'),
                                size: 12,
                                color: widget.color.withValues(alpha: .64),
                              ),
                            ),
                            DecoratedBox(
                              key: const ValueKey('writing-ink-point'),
                              decoration: BoxDecoration(
                                color: Color.lerp(widget.color, ink, .24),
                                shape: BoxShape.circle,
                              ),
                              child: const SizedBox.square(
                                dimension: _inkPointDiameter,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    ),
  );
}

class FreshInkPainter extends CustomPainter {
  const FreshInkPainter({
    required this.text,
    required this.clip,
    required this.origin,
    required this.opacity,
  });
  final TextPainter text;
  final Path clip;
  final Offset origin;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipPath(clip);
    canvas.saveLayer(
      clip.getBounds(),
      Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..colorFilter = const ColorFilter.mode(Colors.black, BlendMode.srcIn),
    );
    text.paint(canvas, origin);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(FreshInkPainter oldDelegate) =>
      text != oldDelegate.text ||
      opacity != oldDelegate.opacity ||
      clip != oldDelegate.clip ||
      origin != oldDelegate.origin;
}
