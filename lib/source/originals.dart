import 'package:flutter/widgets.dart';

import '../data/model.dart';

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
    add(RegisteredOriginal('record-${record.id}', record.source));
  }
  for (final page in library.pages.where(
    (page) => ids.contains(page.recordId),
  )) {
    for (final passage in page.passages) {
      add(
        RegisteredOriginal(
          'passage-${page.id}-${passage.id}',
          passage.source,
          citation: passage.citation,
        ),
      );
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

OriginalMatch? matchOriginal(
  List<RegisteredOriginal> originals,
  String text,
  int caret,
) {
  if (caret <= 0 || caret > text.length || originals.isEmpty) return null;
  final lineStart = text.lastIndexOf('\n', caret - 1) + 1;
  final prefix = text.substring(lineStart, caret).trimLeft();
  if (prefix.characters
          .where((letter) => letter.trim().isNotEmpty)
          .take(5)
          .length <
      5) {
    return null;
  }
  OriginalMatch? match;
  for (final original in originals) {
    final start = original.text.indexOf(prefix);
    if (start < 0) continue;
    if (match != null || original.text.indexOf(prefix, start + 1) >= 0) {
      return null;
    }
    match = OriginalMatch(original, start, start + prefix.length);
  }
  return match;
}
