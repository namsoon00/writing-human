import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'model.dart';
import 'store.dart';
import 'library_backup.dart';
import 'original_removals.dart';
import 'writing_title.dart';
import '../source/originals.dart';
import '../source/photo_lines.dart';
import '../source/page_originals.dart';

class LibraryController extends ChangeNotifier {
  static const defaultPracticeBook = Book(
    id: '43f5a710-9efc-4a38-bb13-cec175a96266',
    title: '연습장',
  );

  Book get practiceBook =>
      library.books
          .where((book) => book.id == defaultPracticeBook.id)
          .firstOrNull ??
      defaultPracticeBook;

  Future<bool> openPracticeBook() async {
    await settled;
    if (_disposed || saveError != null) return false;
    final book = practiceBook;
    final exists = library.books.any((item) => item.id == book.id);
    if (!exists || library.records.any((record) => record.bookId == null)) {
      _publish(
        library.copy(
          books: exists ? null : [...library.books, book],
          records: [
            for (final record in library.records)
              if (record.bookId == null)
                record.copy(bookId: book.id)
              else
                record,
          ],
        ),
        positionChanged: library.activeRecord?.bookId == null,
      );
      await settled;
    }
    return !_disposed && saveError == null;
  }

  LibraryController(this.store, Library library)
    : library = library.bookPositions.containsKey(library.activeRecord?.bookId)
          ? library
          : library.rememberActiveBookPosition();

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
    if (!fromSync) {
      if (next.activePageId != library.activePageId ||
          (!identical(next.records, library.records) &&
              next.activeRecord?.bookId != library.activeRecord?.bookId)) {
        next = next.rememberActiveBookPosition();
      }
      if (!identical(next.records, library.records)) {
        next = next.copy(
          bookPositions: next.validBookPositions(next.bookPositions),
        );
      }
    }
    final snapshot = next;
    library = next;
    final revision = ++_revision;
    saving = true;
    notifyListeners();
    _tail = _tail.then((_) async {
      try {
        await store.save(snapshot);
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
                ? r.copy(
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
            if (r.id == recordId) r.copy(sourceParagraph: index) else r,
        ],
      ),
    );
  }

  RegisteredOriginal? registerOriginal({
    String? bookId,
    WritingPage? page,
    required String text,
    required String citation,
    String? photoId,
    List<double>? photoRegion,
    bool isFullPage = false,
    PencilMark? writingRange,
    List<OriginalPhotoLine> photoLines = const [],
  }) {
    final id = _id();
    final registered = registerOriginals(
      bookId: bookId,
      page: page,
      passages: [text],
      citation: citation,
      deliveryId: id,
      photoId: photoId,
      photoRegion: photoRegion,
      isFullPage: isFullPage,
      writingRange: writingRange,
      photoLines: photoLines,
    );
    if (!registered) return null;
    final originals = bookId != null
        ? library.books.firstWhere((book) => book.id == bookId).originals
        : library.records
              .firstWhere((record) => record.id == page!.recordId)
              .originals;
    return originals.last;
  }

  bool registerOriginals({
    String? bookId,
    WritingPage? page,
    required List<String> passages,
    required String citation,
    String? deliveryId,
    String? photoId,
    List<double>? photoRegion,
    bool isFullPage = false,
    PencilMark? writingRange,
    List<OriginalPhotoLine> photoLines = const [],
  }) {
    final registeredAt = DateTime.now().millisecondsSinceEpoch;
    final originals = [
      for (final (index, text) in passages.indexed)
        RegisteredOriginal(
          index == 0 ? deliveryId ?? _id() : _id(),
          text,
          citation: citation,
          registeredAt: registeredAt,
          photoId: photoId,
          photoRegion: photoRegion,
          isFullPage: isFullPage,
          writingRange: writingRange,
          photoLines: photoLines,
        ),
    ];
    if (originals.isEmpty || !RegisteredOriginal.validList(originals)) {
      return false;
    }
    if (bookId != null) {
      final book = library.books.where((b) => b.id == bookId).firstOrNull;
      if (book == null ||
          (deliveryId != null &&
              book.originals.any((o) => o.id == deliveryId))) {
        return false;
      }
      _publish(
        library.copy(
          books: [
            for (final item in library.books)
              item.id == bookId
                  ? item.copy(originals: [...item.originals, ...originals])
                  : item,
          ],
        ),
      );
      return true;
    }
    if (page == null) return false;
    if (!library.records.any((record) => record.id == page.recordId)) {
      saveDraft(page, originals: originals, keepBlank: true);
      return true;
    }
    _publish(
      library.copy(
        records: [
          for (final record in library.records)
            record.id == page.recordId
                ? record.copy(originals: [...record.originals, ...originals])
                : record,
        ],
      ),
    );
    return true;
  }

  static const _originalRegistrationError = '원문을 저장하지 못했어요. 다시 담아 주세요.';

  /// Keep the registration form and its draft until the snapshot is on disk.
  Future<RegisteredOriginal?> saveNewOriginal({
    required String? bookId,
    required WritingPage? page,
    required RegisteredOriginal original,
  }) async {
    await settled;
    if (_disposed ||
        editorFocused ||
        composing ||
        (saveError != null && saveError != _originalRegistrationError) ||
        !RegisteredOriginal.validList([original])) {
      return null;
    }
    final Library next;
    var activeChanged = false;
    if (bookId != null) {
      final book = library.books.where((b) => b.id == bookId).firstOrNull;
      if (book == null || book.originals.any((o) => o.id == original.id)) {
        return null;
      }
      next = library.copy(
        books: [
          for (final item in library.books)
            if (item.id == bookId)
              item.copy(originals: [...item.originals, original])
            else
              item,
        ],
      );
    } else {
      if (page == null) return null;
      final record = library.records
          .where((r) => r.id == page.recordId)
          .firstOrNull;
      if (record == null) {
        activeChanged = true;
        next = library.copy(
          records: [
            ...library.records,
            WritingRecord(
              id: page.recordId,
              title: '필사 ${library.records.length + 1}',
              originals: [original],
            ),
          ],
          pages: [
            ...library.pages,
            page.withDetails(writtenOn: page.writtenOn ?? _today()),
          ],
          activePageId: page.id,
          writing: true,
        );
      } else {
        if (record.originals.any((o) => o.id == original.id)) return null;
        next = library.copy(
          records: [
            for (final item in library.records)
              if (item.id == record.id)
                item.copy(originals: [...item.originals, original])
              else
                item,
          ],
        );
      }
    }
    return await _saveBeforePublishing(
          next,
          error: _originalRegistrationError,
          activeChanged: activeChanged,
        )
        ? original
        : null;
  }

  /// Commit the original and its first transcription page together.
  Future<bool> saveImportedTranscription({
    required WritingPage draft,
    required String? bookId,
    required String looseRecordId,
    required RegisteredOriginal original,
  }) async {
    await settled;
    if (_disposed ||
        editorFocused ||
        composing ||
        (saveError != null && saveError != _originalRegistrationError) ||
        !original.canTranscribe ||
        !RegisteredOriginal.validList([original]) ||
        library.records.any((record) => record.id == draft.recordId)) {
      return false;
    }
    final book = library.books.where((item) => item.id == bookId).firstOrNull;
    if (bookId != null && book == null) return false;

    final page = attachedPage(draft, original).withDetails(writtenOn: _today());
    final record = WritingRecord(
      id: page.recordId,
      bookId: bookId,
      title: originalWritingTitle(original),
      originals: book == null
          ? [
              ...originalsFor(library, bookId: null, recordId: looseRecordId),
              original,
            ]
          : const [],
    );
    final next = library
        .copy(
          books: book == null
              ? null
              : [
                  for (final item in library.books)
                    if (item.id == bookId)
                      item.copy(originals: [...item.originals, original])
                    else
                      item,
                ],
          records: [...library.records, record],
          pages: [...library.pages, page],
          activePageId: page.id,
          writing: true,
        )
        .rememberActiveBookPosition();
    return _saveBeforePublishing(
      next,
      error: _originalRegistrationError,
      activeChanged: true,
    );
  }

  static const _originalDeleteError = '원문 삭제를 저장하지 못했어요. 다시 시도해 주세요.';

  Future<bool> deleteOriginal({
    required String? bookId,
    required String recordId,
    required RegisteredOriginal original,
  }) async {
    await settled;
    if (_disposed ||
        editorFocused ||
        composing ||
        (saveError != null && saveError != _originalDeleteError)) {
      return false;
    }
    final stillListed =
        originalsFor(library, bookId: bookId, recordId: recordId).any(
          (item) =>
              item.id == original.id &&
              item.text == original.text &&
              item.citation == original.citation &&
              item.photoId == original.photoId,
        );
    if (!stillListed) return false;
    final next = applyOriginalRemovals(library, [
      ...library.originalRemovals,
      ...removalKeysFor(
        library,
        original: original,
        bookId: bookId,
        recordId: recordId,
      ),
    ]);
    return _saveBeforePublishing(next, error: _originalDeleteError);
  }

  static const _originalEditError = '원문 수정을 저장하지 못했어요. 다시 시도해 주세요.';

  Future<RegisteredOriginal?> saveOriginalEdit({
    required String? bookId,
    required String recordId,
    required RegisteredOriginal original,
    required String text,
    required String citation,
    OriginalExtraction? extraction,
  }) async {
    await settled;
    if (_disposed ||
        editorFocused ||
        composing ||
        (saveError != null && saveError != _originalEditError)) {
      return null;
    }
    final latest = originalsFor(library, bookId: bookId, recordId: recordId)
        .where(
          (item) =>
              item.id == original.id &&
              item.text == original.text &&
              item.citation == original.citation &&
              item.photoId == original.photoId,
        )
        .firstOrNull;
    if (latest == null ||
        (extraction != null &&
            (latest.canTranscribe || latest.photoId == null))) {
      return null;
    }
    final edited = editOriginal(latest, text, citation, extraction: extraction);
    if (!RegisteredOriginal.validList([edited])) return null;
    if (extraction == null &&
        text == latest.text &&
        citation == latest.citation) {
      return latest;
    }
    final next = editOriginalInScope(
      library,
      original: latest,
      bookId: bookId,
      recordId: recordId,
      text: text,
      citation: citation,
      newId: _id,
      extraction: extraction,
    );
    final saved = originalsFor(next, bookId: bookId, recordId: recordId)
        .where(
          (item) =>
              item.text == text &&
              item.citation == citation &&
              item.photoId == latest.photoId &&
              listEquals(item.photoRegion, edited.photoRegion),
        )
        .firstOrNull;
    if (saved == null) return null;
    return await _saveBeforePublishing(next, error: _originalEditError)
        ? saved
        : null;
  }

  Future<bool> saveOriginalReflection({
    required String? bookId,
    required String recordId,
    required RegisteredOriginal original,
    required OriginalReflection? reflection,
  }) => _saveOriginal(
    bookId: bookId,
    recordId: recordId,
    original: original,
    updated: original.withReflection(reflection),
  );

  Future<bool> _saveOriginal({
    required String? bookId,
    required String recordId,
    required RegisteredOriginal original,
    required RegisteredOriginal updated,
  }) async {
    if (!RegisteredOriginal.validList([updated])) return false;
    final book = library.books.where((book) => book.id == bookId).firstOrNull;
    final records = library.records.where(
      (record) =>
          bookId == null ? record.id == recordId : record.bookId == bookId,
    );
    final record = records
        .where(
          (record) => record.originals.any((item) => item.id == original.id),
        )
        .firstOrNull;

    List<RegisteredOriginal> replace(List<RegisteredOriginal> values) => {
      for (final item in values) item.id: item,
      updated.id: updated,
    }.values.toList();

    if (book != null &&
        (record == null ||
            book.originals.any((item) => item.id == original.id))) {
      _publish(
        library.copy(
          books: [
            for (final item in library.books)
              item.id == book.id
                  ? book.copy(originals: replace(book.originals))
                  : item,
          ],
        ),
      );
    } else {
      final target = record ?? records.firstOrNull;
      if (target == null) return false;
      _publish(
        library.copy(
          records: [
            for (final item in library.records)
              item.id == target.id
                  ? target.copy(originals: replace(target.originals))
                  : item,
          ],
        ),
      );
    }
    await settled;
    return saveError == null;
  }

  void setStyle(WritingStyle style) => _publish(library.copy(style: style));
  int coverIndexFor(Book? book) {
    if (book == null) return 0;
    final position = library.books.indexWhere((b) => b.id == book.id);
    return book.coverIndex ?? (position < 0 ? 0 : position % 3);
  }

  BookDetailsStyle detailsFor(Book? book) {
    var details = library.style.bookDetails;
    if (book == null) return details;
    for (final entry in book.detailOverrides.entries) {
      details = details.withChoice(entry.key, entry.value);
    }
    return details;
  }

  WritingStyle styleFor(Book? book) {
    if (book == null) return library.style;
    return library.style.copy(
      paperIndex: book.paperIndex,
      bookDetails: detailsFor(book),
    );
  }

  Future<bool> saveBookAppearance(
    String id, {
    int? coverIndex,
    int? paperIndex,
    required bool useDefaultPaper,
    required Map<BookDetailKind, BookDetailChoice?> changes,
  }) async {
    final book = library.books.where((entry) => entry.id == id).firstOrNull;
    if (book == null) return false;
    final overrides = {...book.detailOverrides};
    for (final entry in changes.entries) {
      final choice = entry.value;
      if (choice == null) {
        overrides.remove(entry.key);
      } else {
        overrides[entry.key] = choice;
      }
    }
    final updated = book.copy(
      coverIndex: coverIndex,
      paperIndex: paperIndex,
      useDefaultPaper: useDefaultPaper,
      detailOverrides: Map.unmodifiable(overrides),
    );
    _publish(
      library.copy(
        books: [
          for (final entry in library.books)
            if (entry.id == id) updated else entry,
        ],
      ),
    );
    await settled;
    return saveError == null;
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

  void setRecordTitle(String id, String title) {
    if (_disposed || composing || saveError != null) return;
    final name = title.trim();
    final record = library.records.where((r) => r.id == id).firstOrNull;
    if (record == null ||
        name.isEmpty ||
        (record.title == name && record.titleIsManual)) {
      return;
    }
    _publish(
      library.copy(
        records: [
          for (final item in library.records)
            if (item.id == id)
              item.copy(title: name, titleIsManual: true)
            else
              item,
        ],
      ),
    );
  }

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

  void addPencilMark(String id, int start, int end) =>
      _applyPencilMark(id, start, end, erase: false);

  void togglePencilMark(String id, int start, int end) =>
      _applyPencilMark(id, start, end, erase: null);

  void erasePencilMark(String id, int start, int end) =>
      _applyPencilMark(id, start, end, erase: true);

  void _applyPencilMark(String id, int start, int end, {required bool? erase}) {
    if (composing) return;
    final page = library.pages.where((p) => p.id == id).firstOrNull;
    if (page == null || start < 0 || end <= start || end > page.text.length) {
      return;
    }
    final marks = page.pencilMarks;
    final covered = marks.any((m) => m.start <= start && m.end >= end);
    final removing = erase ?? covered;
    if (removing
        ? !marks.any((m) => m.start < end && start < m.end)
        : covered) {
      return;
    }
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
    String? title,
    List<RegisteredOriginal> originals = const [],
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
      title: title ?? '필사 ${library.records.length + 1}',
      source: source,
      originals: originals,
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
  WritingPage? resumePageForBook(String id) {
    final recordIds = library.records
        .where((record) => record.bookId == id)
        .map((record) => record.id)
        .toSet();
    final savedId =
        library.bookPositions[id] ??
        (library.activeRecord?.bookId == id ? library.activePageId : null);
    final lastPages = <String, WritingPage>{};
    for (final page in library.pages) {
      if (!recordIds.contains(page.recordId)) continue;
      if (page.id == savedId) return page;
      final last = lastPages[page.recordId];
      if (last == null || page.number > last.number) {
        lastPages[page.recordId] = page;
      }
    }
    return recordIds
        .toList()
        .reversed
        .map((id) => lastPages[id])
        .nonNulls
        .firstOrNull;
  }

  void openBook(String id) {
    final page = resumePageForBook(id);
    if (page == null) {
      createRecord(id);
    } else {
      openPage(page.id);
    }
  }

  bool setOriginalSlip(String pageId, RegisteredOriginal? original) {
    if (_disposed || composing || saveError != null) return false;
    final page = library.pages.where((item) => item.id == pageId).firstOrNull;
    if (page == null) return false;
    final slip = original == null
        ? null
        : RegisteredOriginal(
            original.id,
            original.text.substring(
              original.writingRange?.start ?? 0,
              original.writingRange?.end,
            ),
            citation: original.citation,
            photoId: original.photoId,
            photoRegion: originalPhotoPreviewRegion(original),
          );
    if (slip != null && !RegisteredOriginal.validList([slip])) return false;
    _publish(
      library.copy(
        pages: [
          for (final item in library.pages)
            if (item.id == pageId)
              item.withDetails(
                originalSlip: slip,
                clearOriginalSlip: slip == null,
              )
            else
              item,
        ],
      ),
    );
    return true;
  }

  String _linkId() => 'link-${DateTime.now().microsecondsSinceEpoch}-${_id()}';

  void guidePage(String pageId, RegisteredOriginal original) {
    attachOriginal(pageId, original);
  }

  List<RegisteredOriginal> _originalsForPage(WritingPage page) {
    final record = library.records
        .where((r) => r.id == page.recordId)
        .firstOrNull;
    return originalsFor(
      library,
      bookId: record?.bookId,
      recordId: page.recordId,
    );
  }

  List<PagePassage> _insertPassage(WritingPage page, PagePassage inserted) {
    final passages = [
      for (final p in pageOriginals(page, _originalsForPage(page)))
        p.copy(attached: true),
    ];
    if (inserted.start < page.text.length &&
        !passages.any((p) => p.following && p.start == inserted.start)) {
      passages.add(resumeAfterInsertion(page, passages, _linkId()));
    }
    passages.add(inserted);
    final ordered = passages.indexed.toList()
      ..sort((a, b) {
        final start = a.$2.start.compareTo(b.$2.start);
        if (start != 0) return start;
        if (a.$2.following != b.$2.following) return a.$2.following ? 1 : -1;
        return a.$1.compareTo(b.$1);
      });
    return ordered.map((p) => p.$2).toList();
  }

  WritingPage attachedPage(WritingPage page, RegisteredOriginal original) {
    // Previously stored multi-source pages remain intact; new work uses a new page.
    if (pageOriginals(
      page,
      _originalsForPage(page),
    ).any((p) => passageOriginal(p) != null)) {
      return page;
    }
    final snapshot = originalSnapshot(original);
    return page
        .rememberOriginalCitation(original.citation)
        .withDetails(
          passages: _insertPassage(
            page,
            PagePassage(
              id: _linkId(),
              start: page.extent.clamp(0, page.text.length),
              source: snapshot.text,
              citation: snapshot.citation,
              attached: true,
              original: RegisteredOriginal.validList([snapshot])
                  ? snapshot
                  : null,
            ),
          ),
          guidedOriginalId: original.id,
          referenceOnly: page.text.isNotEmpty,
          clearOriginalSlip: true,
        );
  }

  bool attachOriginal(String pageId, RegisteredOriginal original) {
    if (_disposed || composing || saveError != null) return false;
    final page = library.pages.where((p) => p.id == pageId).firstOrNull;
    if (page == null) return false;
    final originals = _originalsForPage(page);
    final linked = pageOriginals(
      page,
      originals,
    ).any((p) => passageOriginal(p) != null);
    if (linked) return pageUsesOriginal(page, originals, original);
    _publish(
      library.copy(
        pages: [
          for (final p in library.pages)
            if (p.id == pageId) attachedPage(p, original) else p,
        ],
      ),
    );
    return true;
  }

  void detachOriginal(String pageId, String passageId) {
    if (_disposed || composing || saveError != null) return;
    final page = library.pages.where((p) => p.id == pageId).firstOrNull;
    if (page == null) return;
    final passages = pageOriginals(page, _originalsForPage(page));
    _publish(
      library.copy(
        pages: [
          for (final p in library.pages)
            if (p.id == pageId)
              p.withDetails(
                passages: [
                  for (final link in passages)
                    if (link.id == passageId)
                      PagePassage(
                        id: link.id,
                        start: link.start,
                        attached: true,
                        following: link.following,
                      )
                    else
                      link.copy(attached: true),
                ],
                clearGuide: true,
                clearOriginalSlip: true,
              )
            else
              p,
        ],
      ),
    );
  }

  void writeWithoutOriginal(String pageId) {
    if (_disposed || composing || saveError != null) return;
    final page = library.pages.where((p) => p.id == pageId).firstOrNull;
    if (page == null) return;
    final passages = _insertPassage(
      page,
      PagePassage(
        id: _linkId(),
        start: page.extent.clamp(0, page.text.length),
        attached: true,
      ),
    );
    _publish(
      library.copy(
        pages: [
          for (final p in library.pages)
            if (p.id == pageId)
              p.withDetails(
                passages: passages,
                clearGuide: true,
                clearOriginalSlip: true,
              )
            else
              p,
        ],
      ),
    );
  }

  void addPage({
    String? recordId,
    String? guidedOriginalId,
    String? originalCitation,
  }) {
    final record = recordId == null
        ? library.activeRecord
        : library.records.where((item) => item.id == recordId).firstOrNull;
    if (record == null) return;
    final previous = library.activePage;
    final continuation =
        guidedOriginalId == null && previous?.recordId == record.id
        ? continuedOriginal(previous!, _originalsForPage(previous), _linkId())
        : null;
    final chosen = guidedOriginalId == null || previous == null
        ? null
        : _originalsForPage(
            previous,
          ).where((o) => o.id == guidedOriginalId).firstOrNull;
    final snapshot = chosen == null ? null : originalSnapshot(chosen);
    final selectedLink = snapshot == null
        ? null
        : PagePassage(
            id: _linkId(),
            start: 0,
            source: snapshot.text,
            citation: snapshot.citation,
            attached: true,
            original: RegisteredOriginal.validList([snapshot])
                ? snapshot
                : null,
          );
    final page = WritingPage(
      id: _id(),
      recordId: record.id,
      passages: selectedLink != null
          ? [selectedLink]
          : continuation == null
          ? const []
          : [continuation],
      guidedOriginalId: guidedOriginalId ?? continuation?.original?.id,
      writtenOn: _today(),
      number:
          [...library.pages, ...library.trashedPages]
              .where((p) => p.recordId == record.id)
              .fold<int>(0, (max, p) => p.number > max ? p.number : max) +
          1,
    ).rememberOriginalCitation(originalCitation ?? '');
    _publish(
      library.copy(
        pages: [...library.pages, page],
        activePageId: page.id,
        writing: true,
      ),
      positionChanged: true,
    );
  }

  static const _trashSaveError = '휴지통 변경을 저장하지 못했어요. 다시 시도해 주세요.';

  /// Keep the paper on screen until the store has committed the move.
  Future<bool> trashPage(WritingPage expected) async {
    await settled;
    if (!_canChangeTrash) return false;
    final target = library.pages
        .where((page) => page.id == expected.id)
        .firstOrNull;
    if (target == null ||
        target.text != expected.text ||
        target.recordId != expected.recordId ||
        library.pages.where((page) => page.recordId == target.recordId).length <
            2) {
      return false;
    }
    final record = library.records.firstWhere(
      (record) => record.id == target.recordId,
    );
    final volume = library.volumePages(
      bookId: record.bookId,
      recordId: record.id,
    );
    final index = volume.indexWhere((page) => page.id == target.id);
    final neighbor = volume[index + (index + 1 < volume.length ? 1 : -1)];
    final activeChanged = library.activePageId == target.id;
    final positions = {...library.bookPositions};
    if (record.bookId case final bookId? when positions[bookId] == target.id) {
      positions[bookId] = neighbor.id;
    }
    final next = library
        .copy(
          pages: library.pages.where((page) => page.id != target.id).toList(),
          trashedPages: [target, ...library.trashedPages],
          activePageId: activeChanged ? neighbor.id : library.activePageId,
          bookPositions: positions,
          sync: activeChanged
              ? library.sync.copy(positionDirty: true)
              : library.sync,
        )
        .rememberActiveBookPosition();

    return _saveBeforePublishing(
      next,
      error: _trashSaveError,
      activeChanged: activeChanged,
    );
  }

  bool get _canChangeTrash =>
      !_disposed &&
      !composing &&
      !editorFocused &&
      (saveError == null || saveError == _trashSaveError);

  Future<bool> changeTrashedPage(String id, {required bool restore}) async {
    await settled;
    if (!_canChangeTrash) return false;
    final page = library.trashedPages
        .where((page) => page.id == id)
        .firstOrNull;
    if (page == null) return false;
    final next = library.copy(
      pages: restore ? [...library.pages, page] : null,
      trashedPages: library.trashedPages
          .where((page) => page.id != id)
          .toList(),
      purgedPageIds: restore ? null : [...library.purgedPageIds, id],
    );
    return _saveBeforePublishing(next, error: _trashSaveError);
  }

  Future<bool> _saveBeforePublishing(
    Library next, {
    required String error,
    bool activeChanged = false,
  }) async {
    final revision = ++_revision;
    var committed = false;
    saving = true;
    _tail = _tail.then((_) async {
      try {
        if (revision != _revision) return;
        await store.save(next);
        // A newer publish queues its own snapshot and supersedes this one.
        if (revision != _revision) return;
        library = next;
        saveError = null;
        localGeneration++;
        if (activeChanged) positionGeneration++;
        committed = true;
      } catch (_) {
        if (revision == _revision) {
          saveError = error;
        }
      } finally {
        if (revision == _revision) saving = false;
        if (!_disposed) notifyListeners();
      }
    });
    notifyListeners();
    await settled;
    return committed;
  }

  void bindRecord(String recordId, String bookId) {
    _publish(
      library.copy(
        records: library.records
            .map((r) => r.id == recordId ? r.copy(bookId: bookId) : r)
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
