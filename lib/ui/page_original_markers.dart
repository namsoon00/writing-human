import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsProperties;
import '../data/model.dart';
import '../source/page_originals.dart';
import 'editable_geometry.dart';
import 'paper.dart';

/// Marks live UTF-16 boundaries in the margin, outside the editable text.
class PageOriginalMarkers extends StatelessWidget {
  const PageOriginalMarkers({
    super.key,
    required this.passages,
    required this.controller,
    required this.scroll,
    required this.fieldKey,
    required this.onSelect,
  });
  final List<PagePassage> passages;
  final TextEditingController controller;
  final ScrollController scroll;
  final GlobalKey fieldKey;
  final ValueChanged<PagePassage> onSelect;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, scroll]),
    builder: (context, _) {
      final painter = _OriginalMarkersPainter(
        passages,
        controller.value,
        fieldKey,
        onSelect,
        MediaQuery.textScalerOf(context),
      );
      return TextFieldTapRegion(
        child: GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          excludeFromSemantics: true,
          onTapUp: (event) {
            final hit = painter.at(event.localPosition);
            if (hit != null) onSelect(hit);
          },
          child: CustomPaint(painter: painter),
        ),
      );
    },
  );
}

class _OriginalMarkersPainter extends CustomPainter {
  _OriginalMarkersPainter(
    this.passages,
    this.value,
    this.fieldKey,
    this.onSelect,
    this.scaler,
  );
  final List<PagePassage> passages;
  final TextEditingValue value;
  final GlobalKey fieldKey;
  final ValueChanged<PagePassage> onSelect;
  final TextScaler scaler;

  List<({Rect rect, int number, PagePassage passage})> _locations() {
    final field = fieldKey.currentContext?.findRenderObject();
    final editable = findEditable(field);
    if (field == null || editable == null || !editable.hasSize) return [];
    final transform = editable.getTransformTo(field);
    final origin = MatrixUtils.transformPoint(transform, Offset.zero);
    final result = <({Rect rect, int number, PagePassage passage})>[];
    var number = 0;
    for (final passage in passages) {
      if (passageOriginal(passage) == null) continue;
      number++;
      final caret = editable.getLocalRectForCaret(
        TextPosition(offset: passage.start.clamp(0, value.text.length)),
      );
      if (caret.top < 0 || caret.bottom > editable.size.height) continue;
      final center = MatrixUtils.transformPoint(
        transform,
        Offset(0, caret.center.dy),
      );
      final x = (origin.dx / 2).clamp(12.0, 32.0);
      final rect = Rect.fromCenter(
        center: Offset(x, center.dy),
        width: 24,
        height: 24,
      );
      // If two sources share a line, show its most recent boundary. Both remain in the list.
      result.removeWhere((p) => (p.rect.center.dy - rect.center.dy).abs() < 20);
      result.add((rect: rect, number: number, passage: passage));
    }
    return result;
  }

  PagePassage? at(Offset point) =>
      _locations().where((p) => p.rect.contains(point)).firstOrNull?.passage;
  @override
  bool hitTest(Offset position) => at(position) != null;
  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = muted.withValues(alpha: .65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7;
    for (final marker in _locations()) {
      canvas.drawCircle(marker.rect.center, 8, outline);
      final label = TextPainter(
        text: TextSpan(
          text: '${marker.number}',
          style: const TextStyle(
            fontFamily: appFontFamily,
            fontFamilyFallback: appFontFallback,
            fontSize: 10,
            color: brandInk,
          ),
        ),
        textScaler: scaler.clamp(maxScaleFactor: 1.3),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        marker.rect.center - Offset(label.width / 2, label.height / 2),
      );
      label.dispose();
    }
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder =>
      (size) => [
        for (final marker in _locations())
          CustomPainterSemantics(
            rect: marker.rect,
            properties: SemanticsProperties(
              label: '원문 ${marker.number} 필사 위치',
              button: true,
              onTap: () => onSelect(marker.passage),
              textDirection: TextDirection.ltr,
            ),
          ),
      ];
  @override
  bool shouldRepaint(_OriginalMarkersPainter oldDelegate) => true;
}
