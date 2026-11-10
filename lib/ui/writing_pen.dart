import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A read-only, non-interactive companion to the actual editable caret.
/// Never writes text, selection, composing, focus or scroll positions.
class WritingPen extends StatefulWidget {
  const WritingPen({
    super.key,
    required this.controller,
    required this.scroll,
    required this.focus,
    required this.fieldKey,
    required this.enabled,
  });
  final TextEditingController controller;
  final ScrollController scroll;
  final FocusNode focus;
  final GlobalKey fieldKey;
  final bool enabled;

  @override
  State<WritingPen> createState() => _WritingPenState();
}

class _WritingPenState extends State<WritingPen>
    with SingleTickerProviderStateMixin {
  // The nib tip in the bundled, transparent 768:512 image.
  static const nib = FractionalOffset(.185, .95);
  static const penSize = Size(150, 100);
  late final motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 130),
  );
  late TextEditingValue observed;
  Offset? from, target;
  Size? viewport;
  bool queued = false, stroke = false, snap = true, reduced = false;

  bool get composing =>
      widget.controller.value.composing.isValid &&
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
      pen.scroll.addListener(_snapChanged);
      pen.focus.addListener(_snapChanged);
    } else {
      pen.controller.removeListener(_textChanged);
      pen.scroll.removeListener(_snapChanged);
      pen.focus.removeListener(_snapChanged);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduced =
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled;
    snap = true;
    motion.stop();
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
      snap = true;
    }
    _schedule();
  }

  void _textChanged() {
    final next = widget.controller.value;
    final wasComposing =
        observed.composing.isValid && !observed.composing.isCollapsed;
    stroke = next.text != observed.text || (wasComposing && !composing);
    if (!stroke || composing) {
      snap = true;
      motion.stop();
    }
    observed = next;
    _schedule();
  }

  void _snapChanged() {
    snap = true;
    motion.stop();
    _schedule();
  }

  void _schedule() {
    if (queued) return;
    queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      queued = false;
      if (mounted) _readCaret();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  RenderEditable? _findEditable(RenderObject? root) {
    if (root is RenderEditable) return root;
    RenderEditable? found;
    root?.visitChildren((child) => found ??= _findEditable(child));
    return found;
  }

  Offset get position =>
      Offset.lerp(from, target, Curves.easeOutCubic.transform(motion.value))!;

  void _readCaret() {
    final value = widget.controller.value;
    Offset? next;
    if (widget.enabled &&
        !reduced &&
        widget.focus.hasFocus &&
        value.selection.isValid &&
        value.selection.isCollapsed) {
      final editable = _findEditable(
        widget.fieldKey.currentContext?.findRenderObject(),
      );
      final overlay = context.findRenderObject();
      if (editable != null &&
          editable.attached &&
          editable.hasSize &&
          overlay is RenderBox &&
          overlay.hasSize) {
        final caret = editable.getLocalRectForCaret(value.selection.extent);
        if (caret.overlaps(Offset.zero & editable.size)) {
          final point = overlay.globalToLocal(
            editable.localToGlobal(caret.bottomRight + const Offset(3, -3)),
          );
          if ((Offset.zero & overlay.size).contains(point)) next = point;
        }
      }
    }
    if (next == target && !stroke && !snap && !composing) return;
    final animate =
        next != null && target != null && stroke && !snap && !composing;
    final start = target == null ? next : position;
    // Lift/snap across line breaks, large pastes, taps and viewport changes;
    // a small horizontal stroke follows normal committed typing only.
    final sameLine =
        next != null &&
        start != null &&
        (next.dy - start.dy).abs() < 12 &&
        (next - start).distance < 90;
    motion.stop();
    if (next != target || stroke || target != null && next == null) {
      setState(() {
        target = next;
        from = animate && sameLine ? start : next;
      });
    }
    if (animate) {
      motion.forward(from: 0);
    } else {
      motion.value = 1;
    }
    stroke = false;
    snap = false;
  }

  @override
  void dispose() {
    _listen(widget, false);
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            if (viewport != size) {
              viewport = size;
              snap = true;
              _schedule();
            }
            return AnimatedBuilder(
              animation: motion,
              builder: (context, _) {
                final at = target == null ? null : position;
                final wave = math.sin(motion.value * math.pi);
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    if (at != null)
                      Positioned(
                        left: at.dx - penSize.width * nib.dx,
                        top: at.dy - penSize.height * nib.dy - wave * 1.3,
                        child: Transform.rotate(
                          angle:
                              math.pi / 2 +
                              math.sin(motion.value * math.pi * 3) *
                                  (1 - motion.value) *
                                  .035,
                          alignment: nib,
                          child: SizedBox(
                            key: const ValueKey('writing-pen'),
                            width: penSize.width,
                            height: penSize.height,
                            child: Image.asset(
                              'assets/images/fountain-pen.png',
                              fit: BoxFit.fill,
                            ),
                          ),
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
