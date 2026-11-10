import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:writing_human/data/library_controller.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/data/sqlite_store.dart';
import 'package:writing_human/sync/merge.dart';
import 'package:writing_human/ui/book_detail_tools.dart';
import 'package:writing_human/ui/collection_sheet.dart';
import 'package:writing_human/ui/reading_details.dart';
import 'book_details_test.dart' show specimen;
import 'widget_test.dart' show MemoryStore;

void main() {
  sqfliteFfiInit();
  test(
    'Version four file migrates with original writing; index labels and all new choices reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'writing-reading-details-',
      );
      final file = '${directory.path}/library.db';
      final original = specimen().copy(
        books: [const Book(id: 'b', title: '오래 곁에 둘 문장들', owner: '필명')],
      );
      final old = await databaseFactoryFfi.openDatabase(
        file,
        options: OpenDatabaseOptions(
          version: 4,
          onCreate: (db, _) async {
            await db.execute(
              "CREATE TABLE books (id TEXT PRIMARY KEY, title TEXT NOT NULL, author TEXT NOT NULL, owner TEXT NOT NULL DEFAULT '')",
            );
            await db.execute(
              "CREATE TABLE records (id TEXT PRIMARY KEY, book_id TEXT REFERENCES books(id), title TEXT NOT NULL, source TEXT NOT NULL DEFAULT '')",
            );
            await db.execute(
              "CREATE TABLE pages (id TEXT PRIMARY KEY, record_id TEXT NOT NULL REFERENCES records(id), number INTEGER NOT NULL, text TEXT NOT NULL, selection_base INTEGER NOT NULL, selection_extent INTEGER NOT NULL, scroll REAL NOT NULL, written_on TEXT, pencil_marks TEXT NOT NULL DEFAULT '[]', UNIQUE(record_id,number))",
            );
            await db.execute(
              "CREATE TABLE app_state (id INTEGER PRIMARY KEY, active_page_id TEXT REFERENCES pages(id), writing INTEGER NOT NULL, settings TEXT NOT NULL DEFAULT '{}', sync_state TEXT NOT NULL DEFAULT '{}')",
            );
            await db.insert('books', {
              'id': 'b',
              'title': original.books.single.title,
              'author': '',
              'owner': '필명',
            });
            final r = original.records.single, p = original.pages.single;
            await db.insert('records', {
              'id': r.id,
              'book_id': r.bookId,
              'title': r.title,
              'source': r.source,
            });
            await db.insert('pages', {
              'id': p.id,
              'record_id': p.recordId,
              'number': p.number,
              'text': p.text,
              'selection_base': p.base,
              'selection_extent': p.extent,
              'scroll': p.scroll,
              'written_on': p.writtenOn,
            });
            final style = original.style.toJson();
            final details = style['bookDetails'] as Json;
            for (final kind in [
              BookDetailKind.indexTab,
              BookDetailKind.recordDivider,
              BookDetailKind.pressedFlower,
            ]) {
              details.remove(kind.name);
            }
            await db.insert('app_state', {
              'id': 1,
              'active_page_id': original.activePageId,
              'writing': 1,
              'settings': jsonEncode(style),
            });
          },
        ),
      );
      await old.close();
      var store = await SqliteLibraryStore.open(
        file,
        factory: databaseFactoryFfi,
      );
      LibraryController? c;
      try {
        final migrated = await store.load();
        expect(await store.db.getVersion(), 5);
        expect(migrated.encode(), original.encode());
        c = LibraryController(store, migrated);
        c.setBookIndexLabel('b', '다시 읽기');
        c.setBookOwner('b', '새 필명');
        var details = c.library.style.bookDetails;
        details = details.withChoice(
          BookDetailKind.indexTab,
          const BookDetailChoice(enabled: false, variant: 1, tone: 3),
        );
        details = details.withChoice(
          BookDetailKind.recordDivider,
          const BookDetailChoice(variant: 2, tone: 1),
        );
        details = details.withChoice(
          BookDetailKind.pressedFlower,
          const BookDetailChoice(variant: 1, tone: 1, placement: 2),
        );
        c.setStyle(c.library.style.copy(bookDetails: details));
        await c.settled;
        expect(c.saveError, isNull);
        final expected = c.library.encode();
        await store.close();
        store = await SqliteLibraryStore.open(
          file,
          factory: databaseFactoryFfi,
        );
        final restored = await store.load();
        expect(restored.encode(), expected);
        expect(restored.books.single.indexLabel, '다시 읽기');
        expect(restored.pages.single.toJson(), original.pages.single.toJson());
        expect(
          restored.records.single.toJson(),
          original.records.single.toJson(),
        );
      } finally {
        c?.dispose();
        await store.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'Book index and owner merge separately; botanical shape, color and placement merge independently',
    () {
      final base = specimen();
      final local = base.copy(
        books: [base.books.single.copy(indexLabel: '다시 읽기')],
        style: base.style.copy(
          bookDetails: base.style.bookDetails.withChoice(
            BookDetailKind.pressedFlower,
            const BookDetailChoice(placement: 2),
          ),
        ),
      );
      final remote = base.copy(
        books: [base.books.single.copy(owner: '필명')],
        style: base.style.copy(
          bookDetails: base.style.bookDetails
              .withChoice(
                BookDetailKind.pressedFlower,
                const BookDetailChoice(variant: 1, tone: 1),
              )
              .withChoice(
                BookDetailKind.recordDivider,
                const BookDetailChoice(enabled: false),
              ),
        ),
      );
      final result = mergeLibraries(base, local, remote).library;
      expect(result.books.single.indexLabel, '다시 읽기');
      expect(result.books.single.owner, '필명');
      expect(result.style.bookDetails.pressedFlower.toJson(), {
        'enabled': true,
        'variant': 1,
        'tone': 1,
        'placement': 2,
      });
      expect(result.style.bookDetails.recordDivider.enabled, isFalse);
      expect(result.activePage!.toJson(), base.activePage!.toJson());
      for (final invalid in [-1, 3, 'left', null]) {
        expect(
          () => BookDetailChoice.fromJson({'placement': invalid}),
          throwsA(anything),
        );
      }
      final malformed = base.toJson();
      (malformed['books'] as List).first['indexLabel'] = '가' * 81;
      expect(() => Library.decode(jsonEncode(malformed)), throwsA(anything));
    },
  );

  testWidgets(
    'Book tabs open the matching book, edit and clear labels without changing writing; separators and botany are real',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final initial = specimen();
      final library = initial.copy(
        books: [
          ...initial.books,
          const Book(id: 'other', title: '다른 책'),
        ],
        records: [
          ...initial.records,
          const WritingRecord(id: 'r2', bookId: 'b', title: '두 번째 기록'),
        ],
        pages: [
          ...initial.pages,
          const WritingPage(
            id: 'p2',
            recordId: 'r2',
            number: 1,
            text: '두 번째 문장',
          ),
        ],
      );
      final c = LibraryController(MemoryStore(), library);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CollectionSheet(
              controller: c,
              onRecord: (_) {},
              onNewSheet: (_) {},
              onNewBook: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('책'));
      await tester.pumpAndSettle();
      expect(find.byType(BookIndexTab), findsNWidgets(2));
      final tab = find.byKey(const ValueKey('book-index-b'));
      expect(tester.getSize(tab).height, greaterThanOrEqualTo(48));
      await tester.tap(tab);
      await tester.pumpAndSettle();
      expect(find.byType(PressedFlower), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('edit-book-index')));
      await tester.tap(find.byKey(const ValueKey('edit-book-index')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('book-index-label')),
        '다시 읽기',
      );
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(c.library.books.first.indexLabel, '');
      await tester.tap(find.byKey(const ValueKey('edit-book-index')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('book-index-label')),
        '👩‍👩‍👧‍👦' * 24,
      );
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(find.text('이름을 조금 줄여 주세요.'), findsOneWidget);
      expect(c.library.books.first.indexLabel, '');
      await tester.enterText(
        find.byKey(const ValueKey('book-index-label')),
        '다시 읽기',
      );
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(c.library.books.first.indexLabel, '다시 읽기');
      expect(find.text('다시 읽기'), findsOneWidget);
      final vertical = find
          .descendant(
            of: find.byType(CollectionSheet),
            matching: find.byType(Scrollable),
          )
          .last;
      await tester.scrollUntilVisible(
        find.byType(RecordDivider),
        120,
        scrollable: vertical,
      );
      await tester.pumpAndSettle();
      expect(find.byType(RecordDivider), findsOneWidget);
      c.setStyle(
        c.library.style.copy(
          bookDetails: c.library.style.bookDetails
              .withChoice(
                BookDetailKind.indexTab,
                const BookDetailChoice(enabled: false),
              )
              .withChoice(
                BookDetailKind.pressedFlower,
                const BookDetailChoice(enabled: false),
              ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BookIndexTab), findsNothing);
      expect(c.library.books.first.indexLabel, '다시 읽기');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('edit-book-index')),
        -160,
        scrollable: vertical,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('edit-book-index')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('book-index-label')),
        '',
      );
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(c.library.books.first.indexLabel, '');
      expect(c.library.activePage!.toJson(), initial.activePage!.toJson());
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await c.settled;
    },
  );

  testWidgets(
    'New element controls preserve other settings and retry failed saves',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryStore();
      final c = LibraryController(store, specimen());
      addTearDown(c.dispose);
      final before = c.library.encode();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BookDetailTools(controller: c)),
        ),
      );
      await tester.pumpAndSettle();
      final list = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('detail-pressedFlower')),
        200,
        scrollable: list,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('detail-pressedFlower')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('detail-pressedFlower-placement-2')),
      );
      await tester.pumpAndSettle();
      store.fail = true;
      await tester.tap(
        find.byKey(const ValueKey('detail-pressedFlower-placement-2')),
      );
      await tester.pumpAndSettle();
      expect(c.library.style.bookDetails.pressedFlower.placement, 2);
      expect(find.text('설정 저장 실패 · 다시 시도'), findsOneWidget);
      store.fail = false;
      await tester.tap(find.text('설정 저장 실패 · 다시 시도'));
      await tester.pumpAndSettle();
      expect(c.saveError, isNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('detail-pressedFlower-reset')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('detail-pressedFlower-reset')),
      );
      await tester.pumpAndSettle();
      expect(c.library.encode(), before);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await c.settled;
    },
  );
}
