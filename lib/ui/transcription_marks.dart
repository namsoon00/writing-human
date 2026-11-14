import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsProperties;

import '../source/transcription_comparison.dart';
import 'editable_geometry.dart';

class TranscriptionMarks extends StatelessWidget {
  const TranscriptionMarks({
    super.key,
    required this.comparison,
    required this.controller,
    required this.scroll,
    required this.fieldKey,
  });

  final TranscriptionComparison comparison;
  final TextEditingController controller;
  final ScrollController scroll;
  final GlobalKey fieldKey;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, scroll]),
    builder: (context, _) {
      void show(TranscriptionDifference difference) {
        final expected = switch (difference.expected) {
          ' ' => '공백',
          '\n' => '줄바꿈',
          final text => text,
        };
        showDialog<void>(
          context: context,
          requestFocus: false,
          builder: (context) => AlertDialog(
            title: const Text('원문 확인'),
            content: Text(
              expected.isEmpty
                  ? '원문에는 없는 글자예요.'
                  : difference.start == difference.end
                  ? '빠진 글자 ‘$expected’'
                  : '원문 글자 ‘$expected’',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            ],
          ),
        );
      }

      final painter = _MarksPainter(
        comparison: comparison,
        value: controller.value,
        fieldKey: fieldKey,
        onOpen: show,
      );
      return TextFieldTapRegion(
        child: GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          excludeFromSemantics: true,
          supportedDevices: const {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.stylus,
          },
          onTapUp: (details) {
            final hit = painter.at(details.localPosition);
            if (hit != null) show(hit);
          },
          child: CustomPaint(painter: painter),
        ),
      );
    },
  );
}

class _MarksPainter extends CustomPainter {
  _MarksPainter({
    required this.comparison,
    required this.value,
    required this.fieldKey,
    required this.onOpen,
  });

  final TranscriptionComparison comparison;
  final TextEditingValue value;
  final GlobalKey fieldKey;
  final ValueChanged<TranscriptionDifference> onOpen;
  List<({Rect target, Rect dots, TranscriptionDifference difference})>
  _locations() {
    final end = value.isComposingRangeValid && !value.composing.isCollapsed
        ? value.composing.start
        : value.text.length;
    if (end == 0) return const [];
    final differences = comparison.differencesFor(value.text.substring(0, end));
    if (differences.isEmpty) return const [];

    final field = fieldKey.currentContext?.findRenderObject();
    final editable = findEditable(field);
    if (field == null ||
        editable == null ||
        !editable.hasSize ||
        editable.size.width < 6) {
      return const [];
    }
    final transform = editable.getTransformTo(field);
    final viewport = Offset.zero & editable.size;
    final first = editable
        .getPositionForPoint(
          editable.localToGlobal(Offset(0, -editable.preferredLineHeight)),
        )
        .offset;
    final last = editable
        .getPositionForPoint(
          editable.localToGlobal(
            Offset(editable.size.width, editable.size.height),
          ),
        )
        .offset;

    final locations =
        <({Rect target, Rect dots, TranscriptionDifference difference})>[];
    for (final difference in differences) {
      if (difference.end < first) continue;
      if (difference.start > last) break;
      final boxes = editable.getBoxesForSelection(
        TextSelection(
          baseOffset: difference.start,
          extentOffset: difference.end,
        ),
      );
      final box =
          boxes.firstOrNull?.toRect() ??
          editable.getLocalRectForCaret(TextPosition(offset: difference.start));
      final y = box.bottom - 0.5;
      if (y < 1 || y >= viewport.bottom - 1) continue;
      final width = boxes.isEmpty ? 6.0 : box.width.clamp(6.0, viewport.width);
      final left = boxes.isEmpty ? box.left - 3.0 : box.left;
      final target = Rect.fromLTWH(left, y - 3, width, 12).intersect(viewport);
      if (target.isEmpty) continue;
      locations.add((
        target: MatrixUtils.transformRect(transform, target),
        dots: MatrixUtils.transformRect(
          transform,
          Rect.fromLTWH(target.left, y - 0.5, target.width, 1),
        ),
        difference: difference,
      ));
    }
    return locations;
  }

  TranscriptionDifference? at(Offset offset) => _locations()
      .where((item) => item.target.contains(offset))
      .firstOrNull
      ?.difference;

  @override
  bool hitTest(Offset position) => at(position) != null;

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()..color = const Color(0xffa4624d).withValues(alpha: .65);
    for (final location in _locations()) {
      final dots = location.dots;
      for (var x = dots.left + 1; x < dots.right; x += 3.5) {
        canvas.drawCircle(Offset(x, dots.center.dy), 0.85, ink);
      }
    }
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder =>
      (size) => [
        for (final location in _locations())
          CustomPainterSemantics(
            rect: location.target,
            properties: SemanticsProperties(
              label: '원문과 다른 글자 확인',
              button: true,
              onTap: () => onOpen(location.difference),
              textDirection: TextDirection.ltr,
            ),
          ),
      ];

  @override
  bool shouldRepaint(_MarksPainter oldDelegate) => true;
}
