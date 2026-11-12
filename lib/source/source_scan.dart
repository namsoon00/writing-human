import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// All rectangles are fractions of the displayed image, with top-left origin.
class ScanWord {
  const ScanWord(this.text, this.bounds, this.confidence);
  final String text;
  final Rect? bounds;
  final double? confidence;
}

class ScanLine {
  const ScanLine(
    this.text, {
    this.bounds,
    this.confidence,
    this.words = const [],
  });
  final String text;
  final Rect? bounds;
  final double? confidence;
  final List<ScanWord> words;

  bool get needsReview =>
      (confidence ?? 1) < .65 ||
      words.any((word) => (word.confidence ?? 1) < .65);
}

class ScanParagraph {
  const ScanParagraph(this.lines);
  final List<ScanLine> lines;

  String get text => lines.map((line) => line.text).join('\n');

  Rect? get bounds {
    Rect? result;
    for (final line in lines) {
      if (line.bounds case final box?) {
        result = result?.expandToInclude(box) ?? box;
      }
    }
    return result;
  }
}

class SourceScan {
  const SourceScan(this.photo, this.paragraphs, {this.width, this.height});

  final Uint8List photo;
  final int? width, height;
  final List<ScanParagraph> paragraphs;

  List<int> get pageReadingOrder {
    final order = List.generate(paragraphs.length, (index) => index);
    final boxes = [for (final paragraph in paragraphs) paragraph.bounds];
    if (boxes.any((box) => box == null)) return order;
    final left = order.where((i) => boxes[i]!.right <= .52).toList();
    final right = order.where((i) => boxes[i]!.left >= .48).toList();
    // Two columns must have a real gutter and share vertical space. Other
    // layouts retain the recognizer's order and can be adjusted in review.
    if (left.isEmpty ||
        right.isEmpty ||
        left.map((i) => boxes[i]!.right).reduce(math.max) >=
            right.map((i) => boxes[i]!.left).reduce(math.min) ||
        !left.any(
          (i) => right.any(
            (j) =>
                boxes[i]!.top < boxes[j]!.bottom &&
                boxes[j]!.top < boxes[i]!.bottom,
          ),
        )) {
      return order;
    }
    int vertical(int a, int b) {
      final y = boxes[a]!.top.compareTo(boxes[b]!.top);
      return y == 0 ? a.compareTo(b) : y;
    }

    final spanning =
        order.where((i) => !left.contains(i) && !right.contains(i)).toList()
          ..sort(vertical);
    final columns = [left..sort(vertical), right..sort(vertical)];
    return [
      for (final row in spanning) ...[
        for (final column in columns)
          ..._takeBefore(column, (i) => vertical(i, row) < 0),
        row,
      ],
      for (final column in columns) ...column,
    ];
  }

  factory SourceScan.fromText(Uint8List photo, Iterable<String> paragraphs) =>
      SourceScan(photo, [
        for (final paragraph in paragraphs)
          if (paragraph.trim().isNotEmpty)
            ScanParagraph([
              for (final line in paragraph.trim().split('\n')) ScanLine(line),
            ]),
      ]);

  factory SourceScan.fromPlatform(ScanImage image, List<Object?> rows) {
    return SourceScan(
      image.bytes,
      [
        for (final block in rows.whereType<List<Object?>>())
          if (_lines(block) case final lines when lines.isNotEmpty)
            ScanParagraph(lines),
      ],
      width: image.width,
      height: image.height,
    );
  }
}

List<int> _takeBefore(List<int> sorted, bool Function(int) predicate) {
  final values = sorted.takeWhile(predicate).toList();
  sorted.removeRange(0, values.length);
  return values;
}

List<ScanLine> _lines(List<Object?> block) => [
  for (final row in block)
    if (row case {'text': final String text} when text.trim().isNotEmpty)
      ScanLine(
        text.trim(),
        bounds: _bounds((row as Map)['bounds']),
        confidence: _confidence(row['confidence']),
        words: [
          for (final word in (row['words'] as List? ?? const []))
            if (word case {'text': final String text} when text.isNotEmpty)
              ScanWord(
                text,
                _bounds(word['bounds']),
                _confidence(word['confidence']),
              ),
        ],
      ),
];

double? _confidence(Object? value) =>
    value is num && value.isFinite && value >= 0 && value <= 1
    ? value.toDouble()
    : null;

Rect? _bounds(Object? value) {
  if (value is! List ||
      value.length != 4 ||
      value.any((n) => n is! num || !n.isFinite)) {
    return null;
  }
  final coords = value
      .cast<num>()
      .map((n) => n.clamp(0, 1).toDouble())
      .toList();
  final rect = Rect.fromLTRB(coords[0], coords[1], coords[2], coords[3]);
  return rect.isEmpty ? null : rect;
}

/// Normalizing once makes the photo preview and all OCR engines use the
/// same pixels, even when the input carries a camera orientation tag.
class ScanImage {
  const ScanImage(this.bytes, this.width, this.height);

  final Uint8List bytes;
  final int width, height;

  static Future<ScanImage> decode(
    Uint8List bytes, {
    Rect? region,
    List<Rect> mask = const [],
  }) async {
    final codec = await instantiateImageCodecWithSize(
      await ImmutableBuffer.fromUint8List(bytes),
      getTargetSize: (width, height) {
        if (math.max(width, height) <= 2400) return const TargetImageSize();
        return width >= height
            ? const TargetImageSize(width: 2400)
            : const TargetImageSize(height: 2400);
      },
    );
    try {
      final image = (await codec.getNextFrame()).image;
      try {
        if (region == null) return await _encode(image);
        final width = math.max(1, (image.width * region.width).round());
        final height = math.max(1, (image.height * region.height).round());
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder)
          ..drawColor(const Color(0xffffffff), BlendMode.src);
        for (final box in mask.isEmpty ? [region] : mask) {
          final area = box.intersect(region);
          if (area.isEmpty) continue;
          canvas.drawImageRect(
            image,
            Rect.fromLTRB(
              area.left * image.width,
              area.top * image.height,
              area.right * image.width,
              area.bottom * image.height,
            ),
            Rect.fromLTRB(
              (area.left - region.left) * width / region.width,
              (area.top - region.top) * height / region.height,
              (area.right - region.left) * width / region.width,
              (area.bottom - region.top) * height / region.height,
            ),
            Paint(),
          );
        }
        final picture = recorder.endRecording();
        try {
          final crop = await picture.toImage(width, height);
          try {
            return await _encode(crop);
          } finally {
            crop.dispose();
          }
        } finally {
          picture.dispose();
        }
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  static Future<ScanImage> _encode(Image image) async {
    final bytes = await image.toByteData(format: ImageByteFormat.png);
    if (bytes == null) throw const FormatException('사진을 읽지 못했어요.');
    return ScanImage(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      image.width,
      image.height,
    );
  }
}
