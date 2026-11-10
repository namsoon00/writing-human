import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:writing_human/data/sqlite_store.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/data/library_controller.dart';

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
      c.addPage();
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
      expect(data.activePage!.base, 3);
      expect(data.activePage!.extent, 8);
      expect(data.activePage!.scroll, 326.5);
      expect(data.writing, isTrue);
      await reopened.close();
    },
  );

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
