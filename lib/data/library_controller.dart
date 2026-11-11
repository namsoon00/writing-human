import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'model.dart';
import 'store.dart';
import 'library_backup.dart';

class LibraryController extends ChangeNotifier {
  LibraryController(this.store, this.library);
  final LibraryStore store;
  Library library;
  String? saveError;
  bool saving = false;
  bool _disposed = false;
  int _revision = 0;
  int editorEpoch = 0;
  int localGeneration = 0;
  int positionGeneration = 0;
  bool editorFocused = false, composing = false;
  Future<void> _tail = Future.value();
  String _id() => const Uuid().v4();
  String _today() => DateTime.now().toIso8601String().substring(0, 10);
  Future<void> get settled => _tail;

  void _publish(
    Library next, {
    bool fromSync = false,
    bool positionChanged = false,
  }) {
    if (!fromSync) {
      localGeneration++;
    }
    if (positionChanged) {
      positionGeneration++;
      next = next.copy(sync: next.sync.copy(positionDirty: true));
    }
    library = next;
    final revision = ++_revision;
    saving = true;
    notifyListeners();
    _tail = _tail.then((_) async {
      try {
        await store.save(next);
        if (revision == _revision) {
          saving = false;
          saveError = null;
        }
      } catch (_) {
        saving = false;
        saveError = '저장하지 못했습니다. 앱을 닫지 말고 다시 시도해 주세요.';
      }
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  void setEditorState({required bool focused, required bool isComposing}) {
    if (editorFocused == focused && composing == isComposing) {
      return;
    }
    editorFocused = focused;
    composing = isComposing;
    if (!_disposed) {
      notifyListeners();
    }
  }

  bool canApplySync(Library next) {
    if (!editorFocused && !composing) {
      return true;
    }
    final before = library.activePage, after = next.activePage;
    return before?.id == after?.id &&
        before?.text == after?.text &&
        before?.base == after?.base &&
        before?.extent == after?.extent;
  }

  Future<bool> applySync(Library next) async {
    if (!canApplySync(next)) {
      return false;
    }
    final before = library.activePage, after = next.activePage;
    if (before?.id == after?.id &&
        (before?.text != after?.text ||
            before?.base != after?.base ||
            before?.extent != after?.extent ||
            before?.scroll != after?.scroll)) {
      editorEpoch++;
    }
    _publish(next.copy(lastBackupAt: library.lastBackupAt), fromSync: true);
    await settled;
    return saveError == null;
  }

  void importLocal(Library next) => _publish(
    next.copy(lastBackupAt: library.lastBackupAt),
    positionChanged: true,
  );

  void recordBackupExport(DateTime createdAt) =>
      _publish(library.copy(lastBackupAt: createdAt.toUtc()), fromSync: true);

  Future<bool> restoreBackup(Library backup) async {
    final next = mergeBackup(library, backup);
    _publish(next, positionChanged: next.activePageId != library.activePageId);
    await settled;
    return saveError == null;
  }

  void setSource(String recordId, String source) => _publish(
    library.copy(
      records: library.records
          .map(
            (r) => r.id == recordId
                ? WritingRecord(
                    id: r.id,
                    bookId: r.bookId,
                    title: r.title,
                    source: source,
                    sourceParagraph: r.source == source ? r.sourceParagraph : 0,
                  )
                : r,
          )
          .toList(),
    ),
  );

  void setSourceParagraph(String recordId, String source, int index) {
    final record = library.records.where((r) => r.id == recordId).firstOrNull;
    if (record == null ||
        record.source != source ||
        index < 0 ||
        record.sourceParagraph == index) {
      return;
    }
    _publish(
      library.copy(
        records: [
          for (final r in library.records)
            if (r.id == recordId)
              WritingRecord(
                id: r.id,
                title: r.title,
                bookId: r.bookId,
                source: r.source,
                sourceParagraph: index,
              )
            else
              r,
        ],
      ),
    );
  }

  void setStyle(WritingStyle style) => _publish(library.copy(style: style));
  int coverIndexFor(Book? book) {
    if (book == null) return 0;
    final position = library.books.indexWhere((b) => b.id == book.id);
    return book.coverIndex ?? (position < 0 ? 0 : position % 3);
  }

  void setBookMaterials(
    String id, {
    int? coverIndex,
    int? paperIndex,
    bool useDefaultPaper = false,
  }) => _publish(
    library.copy(
      books: library.books
          .map(
            (b) => b.id == id
                ? b.copy(
                    coverIndex: coverIndex,
                    paperIndex: paperIndex,
                    useDefaultPaper: useDefaultPaper,
                  )
                : b,
          )
          .toList(),
    ),
  );

  void setBookTitle(String id, String title) {
    final name = title.trim();
    final book = library.books.where((book) => book.id == id).firstOrNull;
    if (book == null || name.isEmpty || book.title == name) return;
    _publish(
      library.copy(
        books: [
          for (final entry in library.books)
            if (entry.id == id) entry.copy(title: name) else entry,
        ],
      ),
    );
  }

  void setBookOwner(String id, String owner) => _publish(
    library.copy(
      books: library.books
          .map((b) => b.id == id ? b.copy(owner: owner.trim()) : b)
          .toList(),
    ),
  );

  void setBookIndexLabel(String id, String label) => _publish(
    library.copy(
      books: library.books
          .map((b) => b.id == id ? b.copy(indexLabel: label.trim()) : b)
          .toList(),
    ),
  );

  void togglePencilMark(String id, int start, int end) {
    if (composing) return;
    final page = library.pages.where((p) => p.id == id).firstOrNull;
    if (page == null || start < 0 || end <= start || end > page.text.length) {
      return;
    }
    final marks = page.pencilMarks;
    final removing = marks.any((m) => m.start <= start && m.end >= end);
    final next = removing
        ? [
            for (final m in marks) ...[
              if (m.end <= start || m.start >= end)
                m
              else ...[
                if (m.start < start) PencilMark(m.start, start),
                if (m.end > end) PencilMark(end, m.end),
              ],
            ],
          ]
        : PencilMark.normalize([...marks, PencilMark(start, end)]);
    _publish(
      library.copy(
        pages: library.pages
            .map((p) => p.id == id ? p.withDetails(pencilMarks: next) : p)
            .toList(),
      ),
    );
  }

  void toggleFavorite(String bookId) {
    final ids = [...library.style.favoriteBookIds];
    ids.contains(bookId) ? ids.remove(bookId) : ids.add(bookId);
    setStyle(library.style.copy(favoriteBookIds: ids));
  }

  void retrySave() => _publish(library);

  /// Commit a mounted draft on first input, or an explicit page-add request.
  /// Retain its IDs so a live editor/IME composition stays mounted.
  void saveDraft(
    WritingPage page, {
    String source = '',
    String? bookId,
    bool keepBlank = false,
  }) {
    if (library.pages.any((p) => p.id == page.id)) {
      editPage(page.id, page.text, page.base, page.extent, page.scroll);
      return;
    }
    if (page.text.isEmpty && source.isEmpty && !keepBlank) return;
    final record = WritingRecord(
      id: page.recordId,
      title: '필사 ${library.records.length + 1}',
      source: source,
      bookId: bookId,
    );
    _publish(
      library.copy(
        records: [...library.records, record],
        pages: [
          ...library.pages,
          page.withDetails(writtenOn: page.writtenOn ?? _today()),
        ],
        activePageId: page.id,
        writing: true,
      ),
      positionChanged: true,
    );
  }

  Book addBook(String title, String author) {
    final book = Book(id: _id(), title: title.trim(), author: author.trim());
    _publish(library.copy(books: [...library.books, book]));
    return book;
  }

  void createBook(String title, String author) {
    final book = Book(id: _id(), title: title.trim(), author: author.trim());
    _createRecord(book.id, library.copy(books: [...library.books, book]));
  }

  void createRecord([String? bookId]) => _createRecord(bookId, library);
  void _createRecord(String? bookId, Library source) {
    final number = source.records.where((r) => r.bookId == bookId).length + 1;
    final record = WritingRecord(
      id: _id(),
      bookId: bookId,
      title: '필사 $number',
    );
    final page = WritingPage(
      id: _id(),
      recordId: record.id,
      number: 1,
      writtenOn: _today(),
    );
    _publish(
      source.copy(
        records: [...source.records, record],
        pages: [...source.pages, page],
        activePageId: page.id,
        writing: true,
      ),
      positionChanged: true,
    );
  }

  void editPage(String id, String text, int base, int extent, double scroll) {
    final old = library.pages.firstWhere((p) => p.id == id);
    if (old.text == text &&
        old.base == base &&
        old.extent == extent &&
        old.scroll == scroll) {
      return;
    }
    final page = old.edited(
      text: text,
      base: base,
      extent: extent,
      scroll: scroll,
    );
    _publish(
      library.copy(
        pages: library.pages.map((p) => p.id == id ? page : p).toList(),
      ),
      positionChanged: id == library.activePageId,
    );
  }

  void showShelf() =>
      _publish(library.copy(writing: false), positionChanged: true);
  void openPage(String id) => _publish(
    library.copy(activePageId: id, writing: true),
    positionChanged: true,
  );
  void openBook(String id) {
    final recordIds = library.records
        .where((r) => r.bookId == id)
        .map((r) => r.id)
        .toSet();
    final pages = library.pages.where((p) => recordIds.contains(p.recordId));
    if (pages.isEmpty) {
      createRecord(id);
      return;
    }
    openPage(
      pages.any((p) => p.id == library.activePageId)
          ? library.activePageId!
          : pages.last.id,
    );
  }

  void addPage() {
    final record = library.activeRecord!;
    final page = WritingPage(
      id: _id(),
      recordId: record.id,
      writtenOn: _today(),
      number:
          library.pages
              .where((p) => p.recordId == record.id)
              .fold<int>(0, (max, p) => p.number > max ? p.number : max) +
          1,
    );
    _publish(
      library.copy(pages: [...library.pages, page], activePageId: page.id),
      positionChanged: true,
    );
  }

  void bindRecord(String recordId, String bookId) {
    _publish(
      library.copy(
        records: library.records
            .map(
              (r) => r.id == recordId
                  ? WritingRecord(
                      id: r.id,
                      title: r.title,
                      bookId: bookId,
                      source: r.source,
                      sourceParagraph: r.sourceParagraph,
                    )
                  : r,
            )
            .toList(),
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
