import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'editable_geometry.dart';

/// Changes the opacity of the editable's own paint, without laying out
/// another paragraph or modifying the input controller.
class InkReveal extends StatefulWidget {
  const InkReveal({
    super.key,
    required this.controller,
    required this.focus,
    required this.enabled,
    required this.child,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final bool enabled;
  final Widget child;

  @override
  State<InkReveal> createState() => _InkRevealState();
}

class _InkRevealState extends State<InkReveal>
    with SingleTickerProviderStateMixin {
  late final _ink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
    value: 1,
  );
  late TextEditingValue _previous;
  TextRange? _range;

  bool get _enabled =>
      widget.enabled &&
      !MediaQuery.disableAnimationsOf(context) &&
      TickerMode.valuesOf(context).enabled;

  @override
  void initState() {
    super.initState();
    _previous = widget.controller.value;
    widget.controller.addListener(_observe);
  }

  @override
  void didUpdateWidget(InkReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_observe);
      _previous = widget.controller.value;
      widget.controller.addListener(_observe);
      _settle();
    }
    if (!widget.enabled) _settle();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_enabled) _settle();
  }

  void _settle() {
    _range = null;
    _ink.value = 1;
  }

  void _observe() {
    final before = _previous;
    final current = _previous = widget.controller.value;
    if (before == current) return;
    if (!_enabled ||
        !widget.focus.hasFocus ||
        !current.selection.isCollapsed ||
        (current.isComposingRangeValid && !current.composing.isCollapsed)) {
      _settle();
      return;
    }
    final end = current.selection.extentOffset;
    final added = current.text.length - before.text.length;
    final start = end - added;
    final inserted =
        added > 0 &&
        start >= 0 &&
        end <= current.text.length &&
        before.text.startsWith(current.text.substring(0, start)) &&
        before.text.substring(start) == current.text.substring(end);
    if (_ink.isAnimating) {
      // Rapid typing never restarts or dims a glyph already on the paper.
      if (before.text != current.text && (!inserted || start < _range!.end)) {
        _settle();
      }
      return;
    }
    if (!inserted ||
        added > 8 ||
        (before.isComposingRangeValid && !before.composing.isCollapsed)) {
      return;
    }
    final glyph = current.text.substring(start, end);
    if (glyph.trim().isEmpty || glyph.characters.length != 1) return;
    _range = TextRange(start: start, end: end);
    _ink.forward(from: 0);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_observe);
    _ink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_ink, widget.focus]),
    child: widget.child,
    builder: (context, child) {
      final range = _enabled && widget.focus.hasFocus && _ink.value < 1
          ? _range
          : null;
      return _InkPaint(
        range: range,
        opacity: 1 - .16 * (1 - Curves.easeOut.transform(_ink.value)),
        child: child,
      );
    },
  );
}

class _InkPaint extends SingleChildRenderObjectWidget {
  const _InkPaint({required this.range, required this.opacity, super.child});
  final TextRange? range;
  final double opacity;

  @override
  _RenderInkPaint createRenderObject(BuildContext context) =>
      _RenderInkPaint(range, opacity);

  @override
  void updateRenderObject(BuildContext context, _RenderInkPaint renderObject) {
    renderObject.update(range, opacity);
  }
}

class _RenderInkPaint extends RenderProxyBox {
  _RenderInkPaint(this._range, this._opacity);

  TextRange? _range;
  double _opacity;

  @override
  bool get alwaysNeedsCompositing => _range != null;

  void update(TextRange? range, double opacity) {
    if (_range == range && _opacity == opacity) return;
    if ((_range == null) != (range == null)) markNeedsCompositingBitsUpdate();
    _range = range;
    _opacity = opacity;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final range = _range;
    final editable = range == null ? null : findEditable(child);
    if (range != null &&
        editable != null &&
        editable.hasSize &&
        editable.text?.codeUnitAt(range.end - 1) != null) {
      final boxes = editable.getBoxesForSelection(
        TextSelection(baseOffset: range.start, extentOffset: range.end),
      );
      if (boxes.length == 1) {
        final rect = boxes.single.toRect().shift(
          globalToLocal(editable.localToGlobal(Offset.zero)),
        );
        if (!rect.isEmpty && rect.overlaps(Offset.zero & size)) {
          final mask = layer as ShaderMaskLayer? ?? ShaderMaskLayer();
          mask
            ..shader = ui.Gradient.radial(
              Offset.zero,
              1,
              [Colors.white.withValues(alpha: _opacity), Colors.white],
              const [.64, 1],
              TileMode.clamp,
              (Matrix4.identity()
                    ..translateByDouble(rect.center.dx, rect.center.dy, 0, 1)
                    ..scaleByDouble(rect.width * .61, rect.height * .61, 1, 1))
                  .storage,
            )
            ..maskRect = offset & size
            ..blendMode = BlendMode.dstIn;
          layer = mask;
          context.pushLayer(mask, super.paint, offset);
          return;
        }
      }
    }
    layer = null;
    super.paint(context, offset);
  }
}
