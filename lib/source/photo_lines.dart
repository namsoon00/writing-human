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

/// The visible excerpt follows the chosen range when OCR line locations exist.
List<double>? originalPhotoPreviewRegion(RegisteredOriginal original) {
  if (original.photoId == null) return null;
  final range = original.writingRange;
  return original.photoRegion ??
      photoExcerptRegion([
        for (final line in original.photoLines)
          if (range == null ||
              (range.start < line.range.end && line.range.start < range.end))
            line.bounds,
      ]);
}

List<double>? photoExcerptRegion(Iterable<Rect> lines) {
  if (lines.isEmpty) return null;
  final bounds = lines
      .reduce((first, next) => first.expandToInclude(next))
      .inflate(.012)
      .intersect(const Rect.fromLTWH(0, 0, 1, 1));
  return bounds.isEmpty
      ? null
      : [bounds.left, bounds.top, bounds.right, bounds.bottom];
}

List<OriginalPhotoLine> mapPhotoLines(
  Iterable<(String, List<ScanLine>)> paragraphs, {
  Rect Function(Rect)? transformBounds,
  bool matchByPosition = true,
}) {
  final result = <OriginalPhotoLine>[];
  var offset = 0;
  for (final (text, scanned) in paragraphs) {
    if (text.isEmpty) continue;
    final lines = text.split('\n');
    final keepPositions = matchByPosition && lines.length == scanned.length;
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
      if (scanLine?.bounds case final bounds?) {
        final box = transformBounds?.call(bounds) ?? bounds;
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
