import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../data/model.dart';
import '../data/library_search.dart';

RegisteredOriginal _legacyOriginal(String text, [String citation = '']) {
  final digest = sha256.convert(utf8.encode(jsonEncode([text, citation])));
  return RegisteredOriginal('legacy-$digest', text, citation: citation);
}

List<RegisteredOriginal> originalsFor(
  Library library, {
  String? bookId,
  String? recordId,
}) {
  final records = library.records.where(
    (record) =>
        bookId == null ? record.id == recordId : record.bookId == bookId,
  );
  final ids = records.map((record) => record.id).toSet();
  final book = library.books.where((book) => book.id == bookId).firstOrNull;
  final originals = <(String, String, String?), RegisteredOriginal>{};

  void add(RegisteredOriginal original) {
    if (original.text.trim().isNotEmpty ||
        original.citation.trim().isNotEmpty) {
      originals.putIfAbsent((
        original.text,
        original.citation,
        original.photoId,
      ), () => original);
    }
  }

  for (final original in book?.originals ?? const <RegisteredOriginal>[]) {
    add(original);
  }
  for (final record in records) {
    for (final original in record.originals) {
      add(original);
    }
    if (record.source.trim().isNotEmpty) add(_legacyOriginal(record.source));
  }
  for (final page in library.pages.where(
    (page) => ids.contains(page.recordId),
  )) {
    for (final passage in page.passages) {
      add(_legacyOriginal(passage.source, passage.citation));
    }
  }
  return originals.values.toList();
}

class OriginalMatch {
  const OriginalMatch(
    this.original,
    this.start,
    this.end, {
    this.useWritingRange = false,
  });

  final RegisteredOriginal original;
  final int start, end;
  final bool useWritingRange;

  String get remainder {
    final text = original.text;
    final lineEnd = text.indexOf('\n', end);
    final limit = useWritingRange
        ? original.writingRange?.end ?? text.length
        : text.length;
    return text.substring(end, lineEnd < 0 ? limit : lineEnd.clamp(end, limit));
  }
}

/// Matches only the beginning of the source deliberately opened on an empty page.
OriginalMatch? matchGuidedOriginal(
  RegisteredOriginal original,
  String text,
  int caret,
) {
  if (caret < 0 || caret > text.length) return null;
  final limit = original.writingRange?.end ?? original.text.length;
  final rangeStart = original.writingRange?.start ?? 0;
  final passage = original.text.substring(rangeStart, limit);
  final start = limit - passage.trimLeft().length;
  final prefix = text.substring(0, caret);
  if (!original.text.startsWith(prefix, start) || start + caret > limit) {
    return null;
  }
  return OriginalMatch(original, start, start + caret, useWritingRange: true);
}

/// Finds the writing behind original notes and pencil marks on copied text.
Map<String, ({Passage passage, bool marked})> originalWritingLocations(
  List<RegisteredOriginal> originals,
  Iterable<WritingPage> pages,
) {
  final locations = <String, ({Passage passage, bool marked})>{};
  for (final page in pages) {
    // A mark can cover a single word or more than one line.
    for (final mark in page.pencilMarks) {
      if (mark.start < 0 ||
          mark.end > page.text.length ||
          mark.end <= mark.start) {
        continue;
      }
      final selection = page.text.substring(mark.start, mark.end);
      var offset = mark.start;
      for (final line in selection.split('\n')) {
        final match = matchSelectedOriginal(originals, line);
        if (match != null) {
          locations[match.original.id] = (
            passage: Passage(page, '', line.trim(), offset: offset),
            marked: true,
          );
        }
        offset += line.length + 1;
      }
    }
    var offset = 0;
    for (final line in page.text.split('\n')) {
      final match = matchOriginal(originals, line, line.trimRight().length);
      if (match != null) {
        locations.putIfAbsent(
          match.original.id,
          () => (
            passage: Passage(page, '', line.trim(), offset: offset),
            marked: false,
          ),
        );
      }
      offset += line.length + 1;
    }
  }
  return locations;
}

const _wordPattern = r'[\p{L}\p{M}\p{N}]';
final _wordCharacter = RegExp(_wordPattern, unicode: true);
final _wordCharacters = RegExp('$_wordPattern+', unicode: true);

bool _isWithinWord(String text, int index) {
  if (index <= 0 || index >= text.length) return false;
  var previous = index - 1;
  final unit = text.codeUnitAt(previous);
  if (unit >= 0xdc00 && unit <= 0xdfff && previous > 0) previous--;
  return _wordCharacter.matchAsPrefix(text, previous)?.end == index &&
      _wordCharacter.matchAsPrefix(text, index) != null;
}

OriginalMatch? matchOriginal(
  List<RegisteredOriginal> originals,
  String text,
  int caret,
) {
  if (caret <= 0 || caret > text.length || originals.isEmpty) return null;
  final lineStart = text.lastIndexOf('\n', caret - 1) + 1;
  final prefix = text.substring(lineStart, caret).trimLeft();
  final words = _wordCharacters.allMatches(prefix).take(2).toList();
  if (words.isEmpty) return null;
  final singleWord = words.length == 1;
  final needsWordEnd = singleWord && words.single.end == prefix.length;
  return _findOriginal(
    originals,
    prefix,
    needsWordEnd: needsWordEnd,
    useWritingRange: true,
  );
}

OriginalMatch? matchSelectedOriginal(
  List<RegisteredOriginal> originals,
  String selection,
) {
  final passage = selection.trim();
  if (!_wordCharacters.hasMatch(passage)) return null;
  return _findOriginal(originals, passage, needsWordEnd: true);
}

OriginalMatch? _findOriginal(
  List<RegisteredOriginal> originals,
  String passage, {
  required bool needsWordEnd,
  bool useWritingRange = false,
}) {
  OriginalMatch? match;
  for (final original in originals) {
    final source = original.text;
    final range = useWritingRange ? original.writingRange : null;
    final limit = range?.end ?? source.length;
    for (
      var start = source.indexOf(passage, range?.start ?? 0);
      start >= 0 && start + passage.length <= limit;
      start = source.indexOf(passage, start + 1)
    ) {
      final end = start + passage.length;
      if ((start != range?.start && _isWithinWord(source, start)) ||
          (needsWordEnd && end != limit && _isWithinWord(source, end))) {
        continue;
      }
      if (match != null) return null;
      match = OriginalMatch(
        original,
        start,
        end,
        useWritingRange: useWritingRange,
      );
    }
  }
  return match;
}

typedef NotebookReflectionMatch = ({OriginalMatch match, int offset});

NotebookReflectionMatch? reflectionForWriting(
  List<RegisteredOriginal> originals,
  String text,
  int caret, {
  RegisteredOriginal? guided,
}) {
  final explicit = guided == null || caret <= 0
      ? null
      : matchGuidedOriginal(guided, text, caret);
  final current =
      explicit != null && _wordCharacters.hasMatch(text.substring(0, caret))
      ? explicit
      : matchOriginal(originals, text, caret);
  if (current != null) return _notebookAnchor(current, caret);
  if (caret <= 0 ||
      caret > text.length ||
      !originals.any((item) => item.reflection != null)) {
    return null;
  }
  final previousLine = text.lastIndexOf('\n', caret - 1);
  if (previousLine < 0) return null;
  final offset = text.substring(0, previousLine).trimRight().length;
  final previous = matchOriginal(originals, text, offset);
  if (previous == null || previous.original.reflection == null) return null;
  return _notebookAnchor(previous, offset);
}

NotebookReflectionMatch _notebookAnchor(OriginalMatch match, int writtenEnd) {
  final mark = match.original.reflection?.mark;
  if (mark == null || mark.end <= match.start || mark.start >= match.end) {
    return (match: match, offset: writtenEnd);
  }
  final sourceEnd = mark.end.clamp(match.start, match.end);
  return (match: match, offset: writtenEnd - (match.end - sourceEnd));
}
