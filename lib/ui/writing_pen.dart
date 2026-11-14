import 'package:flutter/material.dart';
import 'editable_geometry.dart';

/// Read-only feedback beside the native editable. Never writes input state.
class WritingPen extends StatefulWidget {
  const WritingPen({
    super.key,
    required this.controller,
    required this.scroll,
    required this.focus,
    required this.fieldKey,
    this.color = const Color(0xff302c27),
  });
  final TextEditingController controller;
  final ScrollController scroll;
  final FocusNode focus;
  final GlobalKey fieldKey;
  final Color color;

  @override
  State<WritingPen> createState() => _WritingPenState();
}

/// Supplies the same insertion marker to short editors on paper.
class WritingCaret extends StatefulWidget {
  const WritingCaret({
    super.key,
    required this.controller,
    required this.builder,
    this.focusNode,
    this.color = const Color(0xff302c27),
  });

  final TextEditingController controller;
  final Widget Function(FocusNode focus, ScrollController scroll) builder;
  final FocusNode? focusNode;
  final Color color;

  @override
  State<WritingCaret> createState() => _WritingCaretState();
}

class _WritingCaretState extends State<WritingCaret> {
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _field = GlobalKey();

  @override
  void dispose() {
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focus = widget.focusNode ?? _focus;
    return Stack(
      children: [
        KeyedSubtree(key: _field, child: widget.builder(focus, _scroll)),
        Positioned.fill(
          child: WritingPen(
            controller: widget.controller,
            scroll: _scroll,
            focus: focus,
            fieldKey: _field,
            color: widget.color,
          ),
        ),
      ],
    );
  }
}

const _caretWidth = 1.2;

class _WritingPenState extends State<WritingPen> {
  Rect? target;
  Size? viewport;
  bool queued = false;

  @override
  void initState() {
    super.initState();
    _listen(widget, true);
    _schedule();
  }

  void _listen(WritingPen pen, bool add) {
    if (add) {
      pen.controller.addListener(_schedule);
      pen.scroll.addListener(_schedule);
      pen.focus.addListener(_schedule);
    } else {
      pen.controller.removeListener(_schedule);
      pen.scroll.removeListener(_schedule);
      pen.focus.removeListener(_schedule);
    }
  }

  @override
  void didUpdateWidget(WritingPen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.scroll != widget.scroll ||
        oldWidget.focus != widget.focus) {
      _listen(oldWidget, false);
      _listen(widget, true);
    }
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
    Rect? next;
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
      final position = value.selection.extent;
      final caret = editable.getLocalRectForCaret(position);
      final editorBounds = Offset.zero & editable.size;
      if (caret.overlaps(editorBounds)) {
        final center = overlay.globalToLocal(
          editable.localToGlobal(caret.center),
        );
        final bottom = overlay.globalToLocal(
          editable.localToGlobal(caret.bottomCenter),
        );
        final stroke = Rect.fromCenter(
          center: center,
          width: _caretWidth,
          height: (bottom.dy - center.dy).abs() * 1.44,
        );
        final visible = stroke.intersect(Offset.zero & overlay.size);
        if (!visible.isEmpty) next = visible;
      }
    }
    if (target != next) setState(() => target = next);
  }

  @override
  void dispose() {
    _listen(widget, false);
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
            final at = widget.focus.hasFocus ? target : null;
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                if (at != null)
                  Positioned.fromRect(
                    rect: at,
                    child: DecoratedBox(
                      key: const ValueKey('writing-caret-stroke'),
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: .50),
                        borderRadius: BorderRadius.circular(_caretWidth / 2),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
