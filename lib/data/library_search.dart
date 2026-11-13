import 'model.dart';

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
      _books = {for (final book in library.books) book.id: book};

  final Library library;
  final Map<String, WritingRecord> _records;
  final Map<String, Book> _books;

  String _label(WritingRecord record) => [
    if (_books[record.bookId] case final book?) book.title,
    record.title,
  ].join(' · ');

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
          _excerpt(page.text, hit.start, hit.end),
          offset: hit.start,
        );
      } else if (match.hasMatch(page.writtenOn ?? '')) {
        matchedRecords.add(record.id);
        yield Passage(page, _label(record), _excerpt(page.text, 0, 0));
      }
    }
    for (final record in library.records.reversed) {
      final page = firstPages[record.id];
      if (page == null || matchedRecords.contains(record.id)) continue;
      final book = _books[record.bookId];
      if ([
        record.title,
        book?.title,
        book?.author,
      ].nonNulls.any(match.hasMatch)) {
        yield Passage(page, _label(record), _excerpt(page.text, 0, 0));
      }
    }
  }
}

String _excerpt(String text, int start, int end) {
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
