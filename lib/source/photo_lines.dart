import 'dart:ui';

import '../data/model.dart';
import 'source_scan.dart';

extension OriginalPhotoLineBounds on OriginalPhotoLine {
  Rect get bounds => Rect.fromLTRB(
    left / OriginalPhotoLine.coordinateScale,
    top / OriginalPhotoLine.coordinateScale,
    right / OriginalPhotoLine.coordinateScale,
    bottom / OriginalPhotoLine.coordinateScale,
  );
}

List<OriginalPhotoLine> mapPhotoLines(
  Iterable<(String, List<ScanLine>)> paragraphs,
) {
  final result = <OriginalPhotoLine>[];
  var offset = 0;
  for (final (text, scanned) in paragraphs) {
    if (text.isEmpty) continue;
    final lines = text.split('\n');
    final keepPositions = lines.length == scanned.length;
    var lineOffset = offset;
    for (final (index, content) in lines.indexed) {
      final startOfLine = lineOffset;
      lineOffset += content.length + 1;
      final trimmed = content.trim();
      if (trimmed.isEmpty) continue;
      final matches = scanned.where((row) => row.text.trim() == trimmed);
      final scanLine = keepPositions
          ? scanned[index]
          : matches.length == 1
          ? matches.single
          : null;
      if (scanLine?.bounds case final box?) {
        final left = _coordinate(box.left), top = _coordinate(box.top);
        final right = _coordinate(box.right), bottom = _coordinate(box.bottom);
        if (left >= right || top >= bottom) continue;
        final start = startOfLine + content.indexOf(trimmed);
        result.add(
          OriginalPhotoLine(
            PencilMark(start, start + trimmed.length),
            left,
            top,
            right,
            bottom,
          ),
        );
        if (result.length == OriginalPhotoLine.limit) return result;
      }
    }
    offset += text.length + 2;
  }
  return result;
}

int _coordinate(double value) =>
    (value.clamp(0.0, 1.0) * OriginalPhotoLine.coordinateScale).round();
