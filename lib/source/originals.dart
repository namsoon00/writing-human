import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../data/model.dart';

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
  final originals = <(String, String), RegisteredOriginal>{};

  void add(RegisteredOriginal original) {
    if (original.text.trim().isNotEmpty ||
        original.citation.trim().isNotEmpty) {
      originals.putIfAbsent((original.text, original.citation), () => original);
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
  const OriginalMatch(this.original, this.start, this.end);

  final RegisteredOriginal original;
  final int start, end;

  String get remainder {
    final text = original.text;
    final lineEnd = text.indexOf('\n', end);
    return text.substring(end, lineEnd < 0 ? null : lineEnd);
  }
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
  OriginalMatch? match;
  for (final original in originals) {
    final source = original.text;
    for (
      var start = source.indexOf(prefix);
      start >= 0;
      start = source.indexOf(prefix, start + 1)
    ) {
      final end = start + prefix.length;
      if (_isWithinWord(source, start) ||
          (needsWordEnd && _isWithinWord(source, end))) {
        continue;
      }
      if (match != null) return null;
      match = OriginalMatch(original, start, end);
    }
  }
  return match;
}

typedef NotebookReflectionMatch = ({OriginalMatch match, int offset});

NotebookReflectionMatch? reflectionForWriting(
  List<RegisteredOriginal> originals,
  String text,
  int caret,
) {
  final current = matchOriginal(originals, text, caret);
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
