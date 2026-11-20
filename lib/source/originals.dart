import '../data/model.dart';
import '../data/library_search.dart';
import '../data/original_removals.dart';
import 'page_originals.dart';

RegisteredOriginal _legacyOriginal(String text, [String citation = '']) =>
    RegisteredOriginal(
      legacyOriginalId(text, citation),
      text,
      citation: citation,
    );

typedef _ScopedOriginal = ({OriginalRemoval key, RegisteredOriginal original});

Iterable<_ScopedOriginal> _scopedOriginals(
  Library library, {
  String? bookId,
  String? recordId,
  bool includeTrash = false,
}) sync* {
  final records = library.records.where(
    (record) =>
        bookId == null ? record.id == recordId : record.bookId == bookId,
  );
  final ids = records.map((record) => record.id).toSet();
  final book = library.books.where((book) => book.id == bookId).firstOrNull;
  if (book != null) {
    for (final original in book.originals) {
      yield (
        key: (ownerId: book.id, originalId: original.id, book: true),
        original: original,
      );
    }
  }

  _ScopedOriginal fromRecord(String id, RegisteredOriginal original) => (
    key: (ownerId: id, originalId: original.id, book: false),
    original: original,
  );

  for (final record in records) {
    for (final original in record.originals) {
      yield fromRecord(record.id, original);
    }
    if (record.source.trim().isNotEmpty) {
      yield fromRecord(record.id, _legacyOriginal(record.source));
    }
  }
  for (final page in [
    ...library.pages,
    if (includeTrash) ...library.trashedPages,
  ]) {
    if (!ids.contains(page.recordId)) continue;
    for (final passage in page.passages) {
      if (passage.original != null) continue;
      yield fromRecord(
        page.recordId,
        _legacyOriginal(passage.source, passage.citation),
      );
    }
  }
}

(String, String, String?, String?) _originalContent(
  RegisteredOriginal original,
) => (
  original.text,
  original.citation,
  original.photoId,
  original.photoRegion?.join(','),
);

List<RegisteredOriginal> originalsFor(
  Library library, {
  String? bookId,
  String? recordId,
}) {
  final removed = library.originalRemovals.toSet();
  final originals = <(String, String, String?, String?), RegisteredOriginal>{};
  for (final item in _scopedOriginals(
    library,
    bookId: bookId,
    recordId: recordId,
  )) {
    final original = item.original;
    if (!removed.contains(item.key) &&
        (original.canTranscribe ||
            original.photoId != null ||
            original.citation.trim().isNotEmpty)) {
      originals.putIfAbsent(_originalContent(original), () => original);
    }
  }
  return originals.values.toList();
}

Iterable<OriginalRemoval> removalKeysFor(
  Library library, {
  required RegisteredOriginal original,
  required String? bookId,
  required String recordId,
}) sync* {
  final target = _originalContent(original);
  for (final entry in _scopedOriginals(
    library,
    bookId: bookId,
    recordId: recordId,
    includeTrash: true,
  )) {
    if (_originalContent(entry.original) == target) yield entry.key;
  }
}

typedef OriginalExtraction = ({
  bool isFullPage,
  List<OriginalPhotoLine> photoLines,
  List<double>? photoRegion,
});

RegisteredOriginal editOriginal(
  RegisteredOriginal original,
  String text,
  String citation, {
  String? newId,
  OriginalExtraction? extraction,
}) {
  final edited = original.edited(text, citation, newId: newId);
  return extraction == null
      ? edited
      : edited.withDetails(
          reflection: edited.reflection,
          writingRange: null,
          isFullPage: extraction.isFullPage,
          photoLines: extraction.photoLines,
          photoRegion: extraction.photoRegion,
          clearPhotoRegion: extraction.photoRegion == null,
        );
}

/// Replace every stored copy that appears as this single list item.
Library editOriginalInScope(
  Library library, {
  required String? bookId,
  required String recordId,
  required RegisteredOriginal original,
  required String text,
  required String citation,
  required String Function() newId,
  OriginalExtraction? extraction,
}) {
  final keys = removalKeysFor(
    library,
    original: original,
    bookId: bookId,
    recordId: recordId,
  ).toSet();
  final legacyIds = {
    for (final key in keys)
      if (key.originalId.startsWith('legacy-')) key.originalId: newId(),
  };
  final promotedId = legacyIds[original.id];
  final owner = keys.firstWhere((key) => key.originalId == original.id);

  List<RegisteredOriginal> replace(
    List<RegisteredOriginal> values,
    String id, {
    required bool book,
  }) {
    final updated = [
      for (final item in values)
        if (keys.contains((ownerId: id, originalId: item.id, book: book)))
          editOriginal(
            item,
            text,
            citation,
            newId: legacyIds[item.id],
            extraction: extraction,
          )
        else
          item,
    ];
    if (promotedId != null && owner.ownerId == id && owner.book == book) {
      if (!updated.any((item) => item.id == promotedId)) {
        updated.add(
          editOriginal(
            original,
            text,
            citation,
            newId: promotedId,
            extraction: extraction,
          ),
        );
      }
    }
    return updated;
  }

  final scopedRecords = library.records
      .where(
        (record) =>
            bookId == null ? record.id == recordId : record.bookId == bookId,
      )
      .map((record) => record.id)
      .toSet();
  final changed = library.copy(
    books: [
      for (final book in library.books)
        if (book.id == bookId)
          book.copy(originals: replace(book.originals, book.id, book: true))
        else
          book,
    ],
    records: [
      for (final record in library.records)
        if (scopedRecords.contains(record.id))
          record.copy(
            originals: replace(record.originals, record.id, book: false),
          )
        else
          record,
    ],
  );
  final photoRegion = extraction == null
      ? original.photoRegion
      : extraction.photoRegion;
  final selected = originalsFor(changed, bookId: bookId, recordId: recordId)
      .firstWhere(
        (item) =>
            item.text == text &&
            item.citation == citation &&
            item.photoId == original.photoId &&
            item.photoRegion?.join(',') == photoRegion?.join(','),
      );
  final previousIds = keys.map((item) => item.originalId).toSet();
  WritingPage relinkGuide(WritingPage page) =>
      previousIds.contains(page.guidedOriginalId) &&
          scopedRecords.contains(page.recordId)
      ? page
            .rememberOriginalCitation(original.citation)
            .withDetails(
              guidedOriginalId: selected.id,
              clearGuide: extraction != null,
            )
      : page;
  return applyOriginalRemovals(
    changed.copy(
      pages: library.pages.map(relinkGuide).toList(),
      trashedPages: library.trashedPages.map(relinkGuide).toList(),
    ),
    [
      ...library.originalRemovals,
      ...keys.where((key) => legacyIds.containsKey(key.originalId)),
    ],
  );
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
  final originalIds = originals.map((original) => original.id).toSet();
  for (final page in pages) {
    if (page.guidedOriginalId case final String id
        when page.text.trim().isNotEmpty && originalIds.contains(id)) {
      final previous = locations[id];
      if (previous?.marked != true) {
        locations[id] = (
          passage: Passage(page, '', page.text.trim(), offset: page.extent),
          marked: false,
        );
      }
    }
    for (final link in pageOriginals(page, originals)) {
      final source = passageOriginal(link);
      if (source == null) continue;
      final stored = originals.where((o) => o.id == source.id).firstOrNull;
      if (stored == null) continue;
      final end = passageEnd(
        pageOriginals(page, originals),
        link,
        page.text.length,
      );
      if (end <= link.start) continue;
      locations[source.id] = (
        passage: Passage(
          page,
          '',
          page.text.substring(link.start, end).trim(),
          offset: link.start,
        ),
        marked: page.pencilMarks.any(
          (m) => m.start < end && m.end > link.start,
        ),
      );
    }
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
