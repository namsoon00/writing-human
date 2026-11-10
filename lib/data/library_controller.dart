import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'model.dart';
import 'store.dart';

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
    _publish(next, fromSync: true);
    await settled;
    return saveError == null;
  }

  void importLocal(Library next) => _publish(next, positionChanged: true);

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
                  )
                : r,
          )
          .toList(),
    ),
  );

  void setStyle(WritingStyle style) => _publish(library.copy(style: style));
  void toggleFavorite(String bookId) {
    final ids = [...library.style.favoriteBookIds];
    ids.contains(bookId) ? ids.remove(bookId) : ids.add(bookId);
    setStyle(library.style.copy(favoriteBookIds: ids));
  }

  void retrySave() => _publish(library);

  /// Commit an already-mounted blank sheet on its first real input, retaining
  /// its IDs so the editor and an in-flight IME composition stay mounted.
  void saveDraft(WritingPage page, {String source = '', String? bookId}) {
    if (library.pages.any((p) => p.id == page.id)) {
      editPage(page.id, page.text, page.base, page.extent, page.scroll);
      return;
    }
    if (page.text.isEmpty && source.isEmpty) return;
    final record = WritingRecord(
      id: page.recordId,
      title: '필사 ${library.records.length + 1}',
      source: source,
      bookId: bookId,
    );
    _publish(
      library.copy(
        records: [...library.records, record],
        pages: [...library.pages, page],
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
    final page = WritingPage(id: _id(), recordId: record.id, number: 1);
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
      number: library.pages.where((p) => p.recordId == record.id).length + 1,
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
