import 'package:flutter/widgets.dart' show StringCharacters;

import 'model.dart';
import 'writing_title.dart';

class Passage {
  const Passage(this.page, this.label, this.excerpt, {this.offset});

  final WritingPage page;
  final String label;
  final String excerpt;
  final int? offset;
}

class LibraryPassages {
  LibraryPassages(this.library)
    : _records = {for (final record in library.records) record.id: record},
      _books = {for (final book in library.books) book.id: book} {
    for (final page in library.pages) {
      (_pagesByRecord[page.recordId] ??= []).add(page);
    }
    for (final pages in _pagesByRecord.values) {
      pages.sort((a, b) => a.number.compareTo(b.number));
    }
  }

  final Library library;
  final Map<String, WritingRecord> _records;
  final Map<String, Book> _books;

  final _pagesByRecord = <String, List<WritingPage>>{};
  String _title(WritingRecord record) =>
      writingTitle(record, _pagesByRecord[record.id] ?? const []);

  String _label(WritingRecord record) => [
    if (_books[record.bookId] case final book?) book.title,
    _title(record),
  ].join(' · ');

  Iterable<String> completions(String query, {String? bookId}) =>
      searchCompletions(query, _searchFields(bookId));

  Iterable<String> _searchFields(String? bookId) sync* {
    final recordIds = {for (final page in library.pages) page.recordId};
    final seenBooks = <String>{};
    for (final record in library.records.reversed) {
      if (!recordIds.contains(record.id) ||
          (bookId != null && record.bookId != bookId)) {
        continue;
      }
      if (_books[record.bookId] case final book? when seenBooks.add(book.id)) {
        yield book.title;
        yield book.author;
      }
      yield _title(record);
    }
    for (final page in library.pages.reversed) {
      if (bookId != null && _records[page.recordId]?.bookId != bookId) continue;
      if (page.writtenOn case final date?) yield date;
      yield page.text;
    }
  }

  Iterable<Passage> search(String query, {String? bookId}) sync* {
    final term = query.trim();
    if (term.isEmpty) return;
    final match = RegExp(RegExp.escape(term), caseSensitive: false);
    final matchedRecords = <String>{};
    final firstPages = <String, WritingPage>{};
    for (final page in library.pages.reversed) {
      final record = _records[page.recordId]!;
      if (bookId != null && record.bookId != bookId) continue;
      final first = firstPages[record.id];
      if (first == null || first.number > page.number) {
        firstPages[record.id] = page;
      }
      final hit = match.firstMatch(page.text);
      if (hit != null) {
        matchedRecords.add(record.id);
        yield Passage(
          page,
          _label(record),
          searchExcerpt(page.text, hit.start, hit.end),
          offset: hit.start,
        );
      } else if (match.hasMatch(page.writtenOn ?? '')) {
        matchedRecords.add(record.id);
        yield Passage(page, _label(record), searchExcerpt(page.text, 0, 0));
      }
    }
    for (final record in library.records.reversed) {
      final page = firstPages[record.id];
      if (page == null || matchedRecords.contains(record.id)) continue;
      final book = _books[record.bookId];
      if ([
        _title(record),
        book?.title,
        book?.author,
      ].nonNulls.any(match.hasMatch)) {
        yield Passage(page, _label(record), searchExcerpt(page.text, 0, 0));
      }
    }
  }
}

String searchExcerpt(String text, int start, int end) {
  if (text.trim().isEmpty) return '아직 비어 있는 종이';
  var from = (start - 24).clamp(0, text.length);
  var to = (end.clamp(start, start + 50) + 72).clamp(0, text.length);
  // UTF-16 offsets from RegExp also match the editor's offsets.
  bool lowSurrogateAt(int offset) =>
      offset < text.length &&
      text.codeUnitAt(offset) >= 0xdc00 &&
      text.codeUnitAt(offset) <= 0xdfff;
  if (lowSurrogateAt(from)) from--;
  if (lowSurrogateAt(to)) to++;
  return '${from == 0 ? '' : '…'}${text.substring(from, to).trim()}${to == text.length ? '' : '…'}';
}

const _wordCharacters = r'\p{L}\p{M}\p{N}';
final _wordBeforeCursor = RegExp(
  r'[' + _wordCharacters + r']+$',
  unicode: true,
);
final _wordAfterCursor = RegExp('^[$_wordCharacters]+', unicode: true);

String searchWordPrefix(String query) =>
    _wordBeforeCursor.stringMatch(query) ?? '';

int searchWordSuffixLength(String text) =>
    _wordAfterCursor.matchAsPrefix(text)?.end ?? 0;

/// Suggest a single longer word, using the earlier query to narrow the match.
Iterable<String> searchCompletions(
  String query,
  Iterable<String> fields,
) sync* {
  final prefix = searchWordPrefix(query);
  if (prefix.isEmpty) return;
  final earlier = query.substring(0, query.length - prefix.length).trimLeft();
  final match = RegExp(
    '(?:^|[^$_wordCharacters])${RegExp.escape(earlier)}'
    '(${RegExp.escape(prefix)}[$_wordCharacters]+)',
    caseSensitive: false,
    unicode: true,
  );
  final seen = <String>{};
  for (final field in fields) {
    for (final hit in match.allMatches(field)) {
      final word = hit[1]!;
      if (word.characters.length <= 48 && seen.add(word.toLowerCase())) {
        yield word;
      }
    }
  }
}

RegExp? originalSearchPattern(String query) {
  final terms = query.trim().split(RegExp(r'\s+'));
  if (terms.first.isEmpty) return null;
  return RegExp(terms.map(RegExp.escape).join(r'\s+'), caseSensitive: false);
}
