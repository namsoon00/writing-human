import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'model.dart';

String legacyOriginalId(String text, [String citation = '']) =>
    'legacy-${sha256.convert(utf8.encode(jsonEncode([text, citation])))}';

/// Keep removal keys when an older copy of a library is merged back in.
Library applyOriginalRemovals(
  Library library,
  Iterable<OriginalRemoval> entries,
) {
  final removals = entries.toSet();
  if (removals.isEmpty) return library;
  final bookIds = <String, Set<String>>{};
  final recordIds = <String, Set<String>>{};
  for (final entry in removals) {
    final ids = entry.book ? bookIds : recordIds;
    ids.putIfAbsent(entry.ownerId, () => {}).add(entry.originalId);
  }
  final booksByRecord = <String, String?>{};
  final guidesByBook = {
    for (final entry in bookIds.entries) entry.key: {...entry.value},
  };
  for (final record in library.records) {
    final bookId = record.bookId;
    booksByRecord[record.id] = bookId;
    if (recordIds[record.id] case final ids? when bookId != null) {
      guidesByBook.putIfAbsent(bookId, () => {}).addAll(ids);
    }
  }

  WritingRecord removeFromRecord(WritingRecord record) {
    final ids = recordIds[record.id];
    if (ids == null) return record;
    final removeSource =
        record.source.isNotEmpty &&
        ids.contains(legacyOriginalId(record.source));
    return record.copy(
      source: removeSource ? '' : null,
      sourceParagraph: removeSource ? 0 : null,
      originals: record.originals.where((o) => !ids.contains(o.id)).toList(),
    );
  }

  WritingPage removeFromPage(WritingPage page) {
    final ids = recordIds[page.recordId];
    final guide = page.guidedOriginalId;
    final clearGuide =
        ids?.contains(guide) == true ||
        guidesByBook[booksByRecord[page.recordId]]?.contains(guide) == true;
    final passages = ids == null
        ? page.passages
        : page.passages
              .where(
                (entry) => !ids.contains(
                  legacyOriginalId(entry.source, entry.citation),
                ),
              )
              .toList();
    if (!clearGuide && passages.length == page.passages.length) return page;
    final bookId = booksByRecord[page.recordId];
    final removedOriginal = clearGuide
        ? [
            for (final book in library.books)
              if (book.id == bookId) ...book.originals,
            for (final record in library.records)
              if (record.id == page.recordId ||
                  (bookId != null && record.bookId == bookId))
                ...record.originals,
          ].where((item) => item.id == guide).firstOrNull
        : null;
    final preserved = [
      if (removedOriginal != null) removedOriginal.citation,
      for (final entry in page.passages)
        if (!passages.contains(entry)) entry.citation,
    ].fold(page, (page, citation) => page.rememberOriginalCitation(citation));
    return preserved.withDetails(clearGuide: clearGuide, passages: passages);
  }

  final ordered = removals.toList()
    ..sort((a, b) {
      if (a.book != b.book) return a.book ? -1 : 1;
      final owner = a.ownerId.compareTo(b.ownerId);
      return owner == 0 ? a.originalId.compareTo(b.originalId) : owner;
    });

  return library.copy(
    originalRemovals: ordered,
    books: [
      for (final book in library.books)
        if (bookIds[book.id] case final ids?)
          book.copy(
            originals: book.originals
                .where((o) => !ids.contains(o.id))
                .toList(),
          )
        else
          book,
    ],
    records: library.records.map(removeFromRecord).toList(),
    pages: library.pages.map(removeFromPage).toList(),
    trashedPages: library.trashedPages.map(removeFromPage).toList(),
  );
}
