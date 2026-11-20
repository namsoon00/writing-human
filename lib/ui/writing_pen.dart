import 'package:flutter/material.dart';
import 'editable_geometry.dart';

/// Read-only feedback beside the native editable. Never writes input state.
class WritingPen extends StatelessWidget {
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
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          key: const ValueKey('writing-caret-stroke'),
          painter: _WritingCaretPainter(this, context),
        ),
      ),
    ),
  );
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

class _WritingCaretPainter extends CustomPainter {
  _WritingCaretPainter(this.pen, this.context)
    : super(repaint: Listenable.merge([pen.controller, pen.scroll, pen.focus]));

  final WritingPen pen;
  final BuildContext context;

  @override
  void paint(Canvas canvas, Size size) {
    final selection = pen.controller.selection;
    if (!pen.focus.hasFocus || !selection.isValid || !selection.isCollapsed) {
      return;
    }
    final editable = findEditable(
      pen.fieldKey.currentContext?.findRenderObject(),
    );
    final overlay = context.findRenderObject();
    if (editable == null ||
        !editable.attached ||
        !editable.hasSize ||
        overlay is! RenderBox) {
      return;
    }

    // Painting follows layout in the same frame as the selection or edit.
    final caret = editable.getLocalRectForCaret(selection.extent);
    if (!caret.overlaps(Offset.zero & editable.size)) return;
    final center = overlay.globalToLocal(editable.localToGlobal(caret.center));
    final bottom = overlay.globalToLocal(
      editable.localToGlobal(caret.bottomCenter),
    );
    final stroke = Rect.fromCenter(
      center: center,
      width: _caretWidth,
      height: (bottom.dy - center.dy).abs() * 1.44,
    ).intersect(Offset.zero & size);
    if (stroke.isEmpty) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(stroke, const Radius.circular(_caretWidth / 2)),
      Paint()..color = pen.color.withValues(alpha: .50),
    );
  }

  @override
  bool shouldRepaint(_WritingCaretPainter oldDelegate) => true;
}
