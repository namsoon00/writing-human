import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:writing_human/data/sqlite_store.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/data/library_controller.dart';
import 'package:writing_human/data/library_backup.dart';
import 'package:writing_human/source/originals.dart';
import 'package:writing_human/sync/merge.dart';

void main() {
  sqfliteFfiInit();
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('writing-human-test-');
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test(
    'A clipped excerpt survives SQLite and merges independently of writing',
    () async {
      const original = RegisteredOriginal(
        'source',
        '제목\n옮겨 둔 구절',
        citation: '출처',
        photoId:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        isFullPage: true,
        writingRange: PencilMark(3, 10),
      );
      const page = WritingPage(
        id: 'p',
        recordId: 'r',
        number: 1,
        text: '먼저 쓴 글',
      );
      const before = Library(
        records: [
          WritingRecord(id: 'r', title: '필사', originals: [original]),
        ],
        pages: [page],
        activePageId: 'p',
        writing: true,
      );
      final file = '${dir.path}/original-slip.db';
      final store = await SqliteLibraryStore.open(
        file,
        factory: databaseFactoryFfi,
      );
      await store.save(before);
      final controller = LibraryController(store, before);
      expect(controller.setOriginalSlip(page.id, original), isTrue);
      await controller.settled;
      controller.dispose();
      await store.close();

      final reopened = await SqliteLibraryStore.open(
        file,
        factory: databaseFactoryFfi,
      );
      final attached = await reopened.load();
      await reopened.close();
      final slip = attached.pages.single.originalSlip!;
      expect(slip.text, '옮겨 둔 구절');
      expect(slip.citation, '출처');
      expect(slip.photoId, original.photoId);
      expect(slip.writingRange, isNull);
      expect(
        LibraryBackup.photoIds(
          attached.copy(records: [before.records.single.copy(originals: [])]),
        ),
        contains(original.photoId),
      );

      final written = before.copy(
        pages: [page.edited(text: '더 쓴 글', base: 5, extent: 5, scroll: 0)],
      );
      final merged = mergeLibraries(before, written, attached).library;
      expect(merged.pages.single.text, '더 쓴 글');
      expect(merged.pages.single.originalSlip?.toJson(), slip.toJson());
      final removed = attached.copy(
        pages: [attached.pages.single.withDetails(clearOriginalSlip: true)],
      );
      final edited = merged.copy(
        pages: [
          merged.pages.single.edited(
            text: '조금 더 쓴 글',
            base: 7,
            extent: 7,
            scroll: 1,
          ),
        ],
      );
      final synced = mergeLibraries(attached, edited, removed).library;
      expect(synced.pages.single.originalSlip, isNull);
      expect(synced.pages.single.text, '조금 더 쓴 글');
    },
  );

  test(
    'Font size survives SQLite and merges independently of the font',
    () async {
      final file = '${dir.path}/font-size.db';
      final store = await SqliteLibraryStore.open(
        file,
        factory: databaseFactoryFfi,
      );
      const before = Library();
      final sized = before.copy(style: before.style.copy(fontSize: 26));
      await store.save(sized);
      await store.close();
      final reopened = await SqliteLibraryStore.open(
        file,
        factory: databaseFactoryFfi,
      );
      expect((await reopened.load()).style.fontSize, 26);
      await reopened.close();
      final other = before.copy(
        style: before.style.copy(fontIndex: 2, useDevelopmentTypeface: false),
      );
      final merged = mergeLibraries(before, other, sized).library;
      expect(merged.style.fontSize, 26);
      expect(merged.style.fontIndex, 2);
      expect(merged.style.useDevelopmentTypeface, isFalse);
      final old = before.toJson();
      (old['style'] as Map).remove('fontSize');
      expect(Library.decode(jsonEncode(old)).style.fontSize, 20);
    },
  );

  test(
    'Original editing keeps guides, valid photo lines and sync changes',
    () async {
      final original = RegisteredOriginal(
        'source',
        '첫 줄\n두번째 줄',
        citation: '초판',
        photoId: List.filled(64, 'a').join(),
        isFullPage: true,
        reflection: const OriginalReflection('느낀 점', mark: PencilMark(4, 9)),
        writingRange: const PencilMark(4, 9),
        photoLines: const [
          OriginalPhotoLine(PencilMark(0, 3), 0, 0, 100, 100),
          OriginalPhotoLine(PencilMark(4, 9), 0, 200, 100, 300),
        ],
      );
      final before = Library(
        books: [
          Book(id: 'b', title: '책', originals: [original]),
        ],
        records: const [WritingRecord(id: 'r', bookId: 'b', title: '필사')],
        pages: const [
          WritingPage(
            id: 'p',
            recordId: 'r',
            number: 1,
            text: '필사 그대로',
            guidedOriginalId: 'source',
          ),
        ],
        activePageId: 'p',
        writing: true,
      );
      final file = '${dir.path}/original-edit.db';
      final store = await SqliteLibraryStore.open(
        file,
        factory: databaseFactoryFfi,
      );
      await store.save(before);
      final controller = LibraryController(store, await store.load());
      final updated = await controller.saveOriginalEdit(
        bookId: 'b',
        recordId: 'r',
        original: original,
        text: '고친 첫 줄\n두번째 줄',
        citation: '개정판',
      );
      expect(updated?.id, original.id);
      expect(
        await controller.saveOriginalEdit(
          bookId: 'b',
          recordId: 'r',
          original: original,
          text: '오래된 초안',
          citation: '',
        ),
        isNull,
      );
      controller.dispose();
      await store.close();

      final reopened = await SqliteLibraryStore.open(
        file,
        factory: databaseFactoryFfi,
      );
      final after = await reopened.load();
      await reopened.close();
      for (final library in [
        after,
        mergeLibraries(before, before, after).library,
        mergeLibraries(before, after, before).library,
      ]) {
        final saved = library.books.single.originals.single;
        expect(saved.text, '고친 첫 줄\n두번째 줄');
        expect(saved.citation, '개정판');
        expect(saved.photoId, original.photoId);
        expect(saved.reflection?.text, '느낀 점');
        expect(saved.reflection?.mark?.start, 7);
        expect(saved.writingRange?.toJson(), {'start': 7, 'end': 12});
        expect(saved.photoLines.map((line) => line.range.start), [3, 7]);
        expect(library.activePage!.guidedOriginalId, 'source');
        expect(library.activePage!.text, '필사 그대로');
      }
    },
  );

  test(
    'An edited legacy original replaces its old copies in the same scope',
    () {
      const library = Library(
        books: [Book(id: 'b', title: '책')],
        records: [
          WritingRecord(id: 'r', bookId: 'b', title: '필사', source: '예전 원문'),
        ],
        pages: [WritingPage(id: 'p', recordId: 'r', number: 1, text: '내가 쓴 글')],
      );
      final legacy = originalsFor(library, bookId: 'b').single;
      final before = library.copy(
        pages: [library.pages.single.withDetails(guidedOriginalId: legacy.id)],
      );
      final after = editOriginalInScope(
        before,
        bookId: 'b',
        recordId: 'r',
        original: legacy,
        text: '교정한 원문',
        citation: '개정판',
        newId: () => 'saved-original',
      );
      final merged = mergeLibraries(before, before, after).library;
      expect(originalsFor(merged, bookId: 'b').single.text, '교정한 원문');
      expect(merged.records.single.source, isEmpty);
      expect(merged.pages.single.guidedOriginalId, 'saved-original');
      expect(merged.pages.single.text, '내가 쓴 글');
    },
  );

  test(
    'An original deletion survives SQLite, sync and an older backup',
    () async {
      const source = RegisteredOriginal('original', '지울 원문');
      const before = Library(
        books: [
          Book(id: 'b', title: '삭제한 책', originals: [source]),
          Book(id: 'other', title: '별도 책', originals: [source]),
        ],
        records: [
          WritingRecord(id: 'r', bookId: 'b', title: '필사', source: '지울 원문'),
        ],
        pages: [
          WritingPage(
            id: 'p',
            recordId: 'r',
            number: 1,
            text: '직접 쓴 필사',
            base: 2,
            extent: 4,
            pencilMarks: [PencilMark(0, 2)],
            guidedOriginalId: 'original',
            passages: [
              PagePassage(id: 'old', start: 0, source: '지울 원문'),
              PagePassage(id: 'keep', start: 2, source: '남긴 출처'),
            ],
          ),
        ],
        activePageId: 'p',
        writing: true,
      );
      final file = '${dir.path}/original-deletion.db';
      final store = await SqliteLibraryStore.open(
        file,
        factory: databaseFactoryFfi,
      );
      await store.save(before);
      final controller = LibraryController(store, await store.load());
      expect(
        await controller.deleteOriginal(
          bookId: 'b',
          recordId: 'r',
          original: source,
        ),
        isTrue,
      );
      controller.dispose();
      await store.close();

      final reopened = await SqliteLibraryStore.open(
        file,
        factory: databaseFactoryFfi,
      );
      final after = await reopened.load();
      await reopened.close();
      for (final library in [
        after,
        mergeLibraries(before, before, after).library,
        mergeLibraries(before, after, before).library,
        mergeBackup(after, before),
      ]) {
        expect(originalsFor(library, bookId: 'b').single.text, '남긴 출처');
        expect(originalsFor(library, bookId: 'other').single.id, 'original');
        expect(library.records.single.source, isEmpty);
        expect(library.activePage!.text, '직접 쓴 필사');
        expect(library.activePage!.base, 2);
        expect(library.activePage!.extent, 4);
        expect(library.activePage!.guidedOriginalId, isNull);
        expect(library.activePage!.pencilMarks.single.end, 2);
        expect(library.originalRemovals.length, 2);
      }
    },
  );

  test(
    'SQLite close/reopen preserves hierarchy, text, page, selection and scroll',
    () async {
      final file = '${dir.path}/library.db';
      final store = await SqliteLibraryStore.open(
        file,
        factory: databaseFactoryFfi,
      );
      final c = LibraryController(store, await store.load());
      c.createBook('나의 문장들', '쓰는 사람');
      final bookId = c.library.books.single.id;
      final first = c.library.activePage!.id;
      c.editPage(first, '첫 번째 문장', 2, 4, 0);
      final original = c.registerOriginal(
        bookId: bookId,
        text: '한글 문장과 emoji 🌿',
        citation: '',
      )!;
      c.addPage(guidedOriginalId: original.id);
      final last = c.library.activePage!.id;
      c.editPage(
        last,
        List.filled(80, '한글 문장과 emoji 🌿').join('\n'),
        3,
        8,
        326.5,
      );
      c.editPage(first, '중간 수정', 2, 2, 0);
      c.editPage(first, '', 0, 0, 0);
      await c.settled;
      expect(c.saveError, isNull);
      await store.close();
      c.dispose();
      expect(await File(file).length(), greaterThan(0));
      final reopened = await SqliteLibraryStore.open(
        file,
        factory: databaseFactoryFfi,
      );
      final data = await reopened.load();
      expect(data.books.single.id, bookId);
      expect(data.records.single.bookId, bookId);
      expect(data.pages.length, 2);
      expect(data.pages.first.text, '');
      expect(data.activePageId, last);
      expect(data.activePage!.text, contains('🌿'));
      expect(data.activePage!.guidedOriginalId, original.id);
      expect(data.activePage!.base, 3);
      expect(data.activePage!.extent, 8);
      expect(data.activePage!.scroll, 326.5);
      expect(data.writing, isTrue);
      await reopened.close();
    },
  );

  test('Trash and restored page survive SQLite close and reopen', () async {
    final file = '${dir.path}/delete-page.db';
    final store = await SqliteLibraryStore.open(
      file,
      factory: databaseFactoryFfi,
    );
    final controller = LibraryController(store, await store.load());
    controller.createBook('책', '');
    final first = controller.library.activePage!;
    controller.editPage(first.id, '남길 글', 1, 3, 0);
    controller.addPage();
    final last = controller.library.activePage!;
    controller.editPage(last.id, '지울 글', 0, 0, 0);
    expect(await controller.trashPage(last), isFalse);
    expect(await controller.trashPage(controller.library.activePage!), isTrue);
    expect(await controller.trashPage(controller.library.activePage!), isFalse);
    controller.dispose();
    await store.close();

    final reopened = await SqliteLibraryStore.open(
      file,
      factory: databaseFactoryFfi,
    );
    try {
      final saved = await reopened.load();
      expect(saved.activePageId, first.id);
      expect(saved.bookPositions.values.single, first.id);
      expect(saved.pages.single.text, '남길 글');
      expect(saved.pages.single.extent, 3);
      expect(saved.trashedPages.single.text, '지울 글');
      final restored = LibraryController(reopened, saved);
      expect(await restored.changeTrashedPage(last.id, restore: true), isTrue);
      final withRestoredPage = await reopened.load();
      expect(
        withRestoredPage
            .volumePages(bookId: saved.books.single.id)
            .map((page) => page.id),
        [first.id, last.id],
      );
      expect(await restored.trashPage(withRestoredPage.pages.last), isTrue);
      expect(await restored.changeTrashedPage(last.id, restore: false), isTrue);
      final purged = await reopened.load();
      expect(purged.trashedPages, isEmpty);
      expect(purged.purgedPageIds, [last.id]);
      restored.dispose();
    } finally {
      await reopened.close();
    }
  });

  test('Each book position survives a real SQLite close and reopen', () async {
    final file = '${dir.path}/book-positions.db';
    final store = await SqliteLibraryStore.open(
      file,
      factory: databaseFactoryFfi,
    );
    final controller = LibraryController(store, await store.load());
    controller.createBook('첫 책', '');
    final firstBook = controller.library.activeBook!.id;
    final firstPage = controller.library.activePageId!;
    controller.addPage();
    controller.openPage(firstPage);
    controller.createBook('둘째 책', '');
    final secondBook = controller.library.activeBook!.id;
    final secondPage = controller.library.activePageId!;
    await controller.settled;
    expect(controller.saveError, isNull);
    controller.dispose();
    await store.close();

    final reopened = await SqliteLibraryStore.open(
      file,
      factory: databaseFactoryFfi,
    );
    final loaded = LibraryController(reopened, await reopened.load());
    expect(loaded.library.activePageId, secondPage);
    expect(loaded.resumePageForBook(firstBook)?.id, firstPage);
    expect(loaded.resumePageForBook(secondBook)?.id, secondPage);
    loaded.dispose();
    await reopened.close();
  });

  test('Unbound record attaches to book without losing its page', () async {
    final store = await SqliteLibraryStore.open(
      '${dir.path}/library.db',
      factory: databaseFactoryFfi,
    );
    final c = LibraryController(store, await store.load());
    c.createRecord();
    final pageId = c.library.activePage!.id;
    final recordId = c.library.activeRecord!.id;
    c.editPage(pageId, '먼저 쓴 문장', 4, 4, 0);
    c.createBook('나중에 묶은 책', '');
    c.bindRecord(recordId, c.library.books.single.id);
    await c.settled;
    final data = await store.load();
    expect(data.records.first.bookId, data.books.single.id);
    expect(data.pages.firstWhere((p) => p.id == pageId).id, pageId);
    expect(data.pages.firstWhere((p) => p.id == pageId).text, '먼저 쓴 문장');
    await store.close();
    c.dispose();
  });

  test(
    'An untouched sheet stores no record; first draft survives disk reopen and later book binding',
    () async {
      final path = '${dir.path}/first-sheet.db';
      final store = await SqliteLibraryStore.open(
        path,
        factory: databaseFactoryFfi,
      );
      final c = LibraryController(store, await store.load());
      const draft = WritingPage(
        id: 'first-page',
        recordId: 'first-record',
        number: 1,
      );
      c.saveDraft(draft);
      await c.settled;
      expect((await store.load()).records, isEmpty);
      c.saveDraft(
        draft.edited(text: '바로 쓴 한글 🌿', base: 2, extent: 4, scroll: 0),
      );
      await c.settled;
      final book = c.addBook('나중에 묶은 문장', '');
      c.bindRecord(draft.recordId, book.id);
      await c.settled;
      await store.close();
      c.dispose();
      final reopened = await SqliteLibraryStore.open(
        path,
        factory: databaseFactoryFfi,
      );
      final data = await reopened.load();
      expect(data.records.single.id, draft.recordId);
      expect(data.records.single.bookId, book.id);
      expect(data.activePage!.id, draft.id);
      expect(data.activePage!.text, '바로 쓴 한글 🌿');
      expect(data.activePage!.base, 2);
      expect(data.activePage!.extent, 4);
      await reopened.close();
    },
  );

  test(
    'Version 1 SQLite migrates without losing text or last position; independent tools persist',
    () async {
      final file = '${dir.path}/legacy.db';
      final old = await databaseFactoryFfi.openDatabase(
        file,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE books (id TEXT PRIMARY KEY, title TEXT NOT NULL, author TEXT NOT NULL)',
            );
            await db.execute(
              'CREATE TABLE records (id TEXT PRIMARY KEY, book_id TEXT REFERENCES books(id), title TEXT NOT NULL)',
            );
            await db.execute(
              'CREATE TABLE pages (id TEXT PRIMARY KEY, record_id TEXT NOT NULL REFERENCES records(id), number INTEGER NOT NULL, text TEXT NOT NULL, selection_base INTEGER NOT NULL, selection_extent INTEGER NOT NULL, scroll REAL NOT NULL, UNIQUE(record_id, number))',
            );
            await db.execute(
              'CREATE TABLE app_state (id INTEGER PRIMARY KEY CHECK(id = 1), active_page_id TEXT REFERENCES pages(id), writing INTEGER NOT NULL)',
            );
            await db.insert('books', {
              'id': 'b',
              'title': '기존 책',
              'author': '나',
            });
            await db.insert('records', {
              'id': 'r',
              'book_id': 'b',
              'title': '필사 1',
            });
            await db.insert('pages', {
              'id': 'p',
              'record_id': 'r',
              'number': 1,
              'text': '기존 한글 기록',
              'selection_base': 2,
              'selection_extent': 4,
              'scroll': 80.0,
            });
            await db.insert('app_state', {
              'id': 1,
              'active_page_id': 'p',
              'writing': 1,
            });
          },
        ),
      );
      await old.close();
      final upgraded = await SqliteLibraryStore.open(
        file,
        factory: databaseFactoryFfi,
      );
      final c = LibraryController(upgraded, await upgraded.load());
      expect(c.library.activePage!.text, '기존 한글 기록');
      expect(c.library.activePage!.extent, 4);
      expect(c.library.activePage!.scroll, 80);
      c.setStyle(c.library.style.copy(paperIndex: 2));
      c.setStyle(c.library.style.copy(penIndex: 1));
      c.setStyle(
        c.library.style.copy(fontIndex: 2, useDevelopmentTypeface: true),
      );
      c.setStyle(c.library.style.copy(penMotion: false));
      c.setSource('r', '함께 읽을 원문');
      c.toggleFavorite('b');
      await c.settled;
      expect(c.saveError, isNull);
      await upgraded.close();
      c.dispose();
      final reopened = await SqliteLibraryStore.open(
        file,
        factory: databaseFactoryFfi,
      );
      final data = await reopened.load();
      expect(data.style.paperIndex, 2);
      expect(data.style.penIndex, 1);
      expect(data.style.fontIndex, 2);
      expect(data.style.useDevelopmentTypeface, isTrue);
      expect(data.style.penMotion, isFalse);
      expect(data.style.favoriteBookIds, ['b']);
      expect(data.records.single.source, '함께 읽을 원문');
      expect(data.activePage!.text, '기존 한글 기록');
      expect(data.activePage!.base, 2);
      await reopened.close();
    },
  );

  test(
    'Existing version 2 files migrate sync metadata without replacing original writing',
    () async {
      final file = '${dir.path}/version-two.db';
      final old = await databaseFactoryFfi.openDatabase(
        file,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE books (id TEXT PRIMARY KEY, title TEXT NOT NULL, author TEXT NOT NULL)',
            );
            await db.execute(
              "CREATE TABLE records (id TEXT PRIMARY KEY, book_id TEXT REFERENCES books(id), title TEXT NOT NULL, source TEXT NOT NULL DEFAULT '')",
            );
            await db.execute(
              'CREATE TABLE pages (id TEXT PRIMARY KEY, record_id TEXT NOT NULL REFERENCES records(id), number INTEGER NOT NULL, text TEXT NOT NULL, selection_base INTEGER NOT NULL, selection_extent INTEGER NOT NULL, scroll REAL NOT NULL, UNIQUE(record_id, number))',
            );
            await db.execute(
              "CREATE TABLE app_state (id INTEGER PRIMARY KEY CHECK(id = 1), active_page_id TEXT REFERENCES pages(id), writing INTEGER NOT NULL, settings TEXT NOT NULL DEFAULT '{}')",
            );
            await db.insert('books', {
              'id': 'b',
              'title': '보존할 책',
              'author': '나',
            });
            await db.insert('records', {
              'id': 'r',
              'book_id': 'b',
              'title': '필사 1',
              'source': '보존할 원문',
            });
            await db.insert('pages', {
              'id': 'p',
              'record_id': 'r',
              'number': 1,
              'text': '기존 본문 그대로',
              'selection_base': 2,
              'selection_extent': 4,
              'scroll': 12.0,
            });
            await db.insert('app_state', {
              'id': 1,
              'active_page_id': 'p',
              'writing': 1,
              'settings':
                  '{"paperIndex":2,"penIndex":1,"fontIndex":2,"guides":true,"favoriteBookIds":["b"]}',
            });
          },
        ),
      );
      await old.close();
      final next = await SqliteLibraryStore.open(
        file,
        factory: databaseFactoryFfi,
      );
      final data = await next.load();
      expect(data.activePage!.text, '기존 본문 그대로');
      expect(data.activePage!.extent, 4);
      expect(data.records.single.source, '보존할 원문');
      expect(data.style.paperIndex, 2);
      expect(data.sync.baseline, isNull);
      expect(data.sync.positionDirty, isTrue);
      await next.close();
    },
  );

  test('Legacy web snapshot defaults tools without changing the draft', () {
    final json = const Library(
      books: [Book(id: 'b', title: '기존 책')],
    ).toJson()..remove('style');
    final data = Library.decode(jsonEncode(json));
    expect(data.books.single.title, '기존 책');
    expect(data.style.paperIndex, 0);
    expect(data.style.fontIndex, 1);
    expect(data.style.useDevelopmentTypeface, isTrue);
    expect(data.style.penMotion, isTrue);
  });

  test('Unsupported/corrupt snapshots fail explicitly', () {
    expect(() => Library.decode('{"version":2}'), throwsFormatException);
    expect(() => Library.decode('broken'), throwsFormatException);
    expect(
      () => Library.decode(const Library(activePageId: 'missing').encode()),
      throwsFormatException,
    );
  });
}
