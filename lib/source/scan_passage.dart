import 'dart:ui';

import 'source_scan.dart';

final _term = RegExp(r'\S+');

/// Word boundaries are taken from the OCR line text so selecting an excerpt
/// preserves punctuation, original spaces, and intentional line breaks.
class ScanPassage {
  ScanPassage(ScanParagraph paragraph)
    : text = paragraph.text,
      terms = _terms(paragraph);

  final String text;
  final List<({int start, int end, int line, Rect? bounds})> terms;

  String select(int first, int last) =>
      text.substring(terms[first].start, terms[last].end);

  List<Rect> boxes(int first, int last) => [
    for (final term in terms.getRange(first, last + 1)) ?term.bounds,
  ];

  List<Rect> lineBoxes(int first, int last) {
    final lines = <int, Rect>{};
    for (final term in terms.getRange(first, last + 1)) {
      if (term.bounds case final box?) {
        lines.update(
          term.line,
          (before) => before.expandToInclude(box),
          ifAbsent: () => box,
        );
      }
    }
    return lines.values.toList();
  }

  static List<({int start, int end, int line, Rect? bounds})> _terms(
    ScanParagraph paragraph,
  ) {
    var offset = 0;
    final terms = <({int start, int end, int line, Rect? bounds})>[];
    for (final (lineIndex, line) in paragraph.lines.indexed) {
      final positions = <({int start, int end, Rect bounds})>[];
      var afterWord = 0;
      for (final word in line.words) {
        final start = line.text.indexOf(word.text, afterWord);
        if (start < 0) continue;
        afterWord = start + word.text.length;
        if (word.bounds case final box?) {
          positions.add((start: start, end: afterWord, bounds: box));
        }
      }
      for (final term in _term.allMatches(line.text)) {
        Rect? box;
        for (final position in positions) {
          if (position.end > term.start && position.start < term.end) {
            box = box?.expandToInclude(position.bounds) ?? position.bounds;
          }
        }
        terms.add((
          start: offset + term.start,
          end: offset + term.end,
          line: lineIndex,
          bounds: box ?? line.bounds,
        ));
      }
      offset += line.text.length + 1;
    }
    return terms;
  }
}
