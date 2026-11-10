import 'model.dart';
import 'store.dart';

/// An explicitly chosen visual preview, completely separate from user storage.
class DemoStore implements LibraryStore {
  DemoStore({bool useDevelopmentTypeface = false})
    : _data = referenceLibrary(useDevelopmentTypeface: useDevelopmentTypeface);
  Library _data;
  @override
  Future<Library> load() async => _data;
  @override
  Future<void> save(Library library) async {
    _data = library;
  }

  @override
  Future<void> close() async {}
}

Library referenceLibrary({bool useDevelopmentTypeface = false}) {
  const quote = '새는 알에서 나오려고\n투쟁한다.\n알은 세계다.';
  const titles = ['데미안', '나의 문장집', '좋은 것들의 힘'];
  const authors = ['헤르만 헤세', '나의 생각과 문장들', '앨리스 먼로'];
  const counts = [2, 1, 1];
  final books = <Book>[], records = <WritingRecord>[], pages = <WritingPage>[];
  for (var i = 0; i < titles.length; i++) {
    final id = 'demo-book-$i', r = 'demo-record-$i';
    books.add(Book(id: id, title: titles[i], author: authors[i]));
    records.add(
      WritingRecord(
        id: r,
        bookId: id,
        title: '필사 1',
        source: i == 0 ? '새는 알에서 나오려고 투쟁한다.\n알은 세계다.' : '내 마음에 오래 남는 문장.',
      ),
    );
    for (var n = 1; n <= counts[i]; n++) {
      pages.add(
        WritingPage(
          id: '$r-page-$n',
          recordId: r,
          number: n,
          text: i == 0
              ? n == 1
                    ? quote
                    : '오래 읽고, 천천히 쓴다.\n마음에 남은 문장을 한 줄씩 기록한다.'
              : '오래 곁에 두고 싶은 문장을 남깁니다.',
        ),
      );
    }
  }
  return Library(
    books: books,
    records: records,
    pages: pages,
    activePageId: 'demo-record-0-page-1',
    style: WritingStyle(
      fontIndex: 0,
      useDevelopmentTypeface: useDevelopmentTypeface,
    ),
  );
}
