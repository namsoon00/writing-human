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
import 'package:writing_human/ui/book_details.dart';
import 'package:writing_human/ui/book_front_cover.dart';
import 'package:writing_human/ui/collection_sheet.dart';
import 'package:writing_human/ui/paper.dart';
import 'package:writing_human/ui/reading_details.dart';
import 'book_details_test.dart' show specimen;
import 'widget_test.dart' show MemoryStore;

void main() {
  sqfliteFfiInit();
  testWidgets('Cover binding stays on the board and the cover fits its image', (
    tester,
  ) async {
    for (final width in [48.0, 320.0]) {
      for (var variant = 0; variant < coverNames.length; variant++) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: BookCover(
                title: '필사',
                width: width,
                variant: variant,
                pageCount: 2,
              ),
            ),
          ),
        );
        final cover = tester.getRect(find.byType(BookCover));
        final image = tester.getRect(find.byType(Image));
        final binding = tester.getRect(find.byType(BookBinding));
        expect(cover, image);
        expect(binding.left, greaterThan(image.left + width * .04));
        expect(binding.top, greaterThan(image.top));
        expect(binding.bottom, lessThan(image.bottom));
      }
    }
  });

  testWidgets('Long titles and removable flowers occupy separate cover areas', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 460);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    const title = '아주 오래 곁에 두고 싶은 문장을 모아 둔 첫 번째 필사 노트';
    for (final large in [false, true]) {
      for (final enabled in [true, false]) {
        final details = BookDetailsStyle(
          pressedFlower: BookDetailChoice(enabled: enabled, placement: 2),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: large
                  ? BookFrontCover(
                      title: title,
                      author: '길게 적은 기록자의 이름',
                      style: WritingStyle(bookDetails: details),
                      pageCount: 22,
                      onOpen: () {},
                      onCollection: () {},
                    )
                  : Center(
                      child: BookCover(
                        title: title,
                        width: 84,
                        bookmarked: true,
                        pageCount: 22,
                        details: details,
                      ),
                    ),
            ),
          ),
        );
        final flower = find.byType(PressedFlower);
        expect(flower, enabled ? findsOneWidget : findsNothing);
        if (enabled) {
          expect(
            tester.getRect(find.text(title)).bottom,
            lessThan(tester.getRect(flower).top),
          );
        }
        expect(tester.takeException(), isNull);
      }
    }
  });

  test(
    'Version four file migrates with original writing and reopens with legacy index settings',
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
            style.remove('pageMotion');
            style.remove('pageSound');
            style.remove('writingSound');
            final details = style['bookDetails'] as Json;
            for (final kind in [
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
        expect(await store.db.getVersion(), 10);
        expect(migrated.encode(), original.encode());
        expect(migrated.pages.single.passages, isEmpty);
        final settings = original.style.toJson();
        (settings['bookDetails'] as Json)['indexTab'] = {'enabled': true};
        await store.db.update('app_state', {'settings': jsonEncode(settings)});
        await store.db.update('books', {
          'index_label': '다시 읽기',
          'detail_overrides': '{"indexTab":{"variant":1}}',
        });
        expect((await store.load()).encode(), original.encode());
        const passage = PagePassage(
          id: 'passage',
          start: 0,
          source: '원문',
          citation: '필사집 · 12쪽',
        );
        final withPassage = migrated.copy(
          pages: [
            migrated.pages.single.withDetails(passages: [passage]),
          ],
        );
        await store.save(withPassage);
        c = LibraryController(store, withPassage);
        c.setBookOwner('b', '새 필명');
        c.setBookMaterials('b', coverIndex: 2);
        c.setBookMaterials('b', paperIndex: 3);
        var details = c.library.style.bookDetails;
        details = details.withChoice(
          BookDetailKind.recordDivider,
          const BookDetailChoice(variant: 2, tone: 1),
        );
        details = details.withChoice(
          BookDetailKind.pressedFlower,
          const BookDetailChoice(variant: 1, tone: 1, placement: 2),
        );
        c.setStyle(
          c.library.style.copy(
            bookDetails: details,
            pageMotion: false,
            pageSound: true,
            writingSound: true,
          ),
        );
        c.registerOriginal(bookId: 'b', text: '책의 원문', citation: '12쪽');
        c.registerOriginal(
          page: migrated.pages.single,
          text: '기록의 원문',
          citation: '24쪽',
        );
        const reflection = OriginalReflection(
          '연필로 남긴 생각',
          mark: PencilMark(0, 1),
        );
        expect(
          await c.saveOriginalReflection(
            bookId: 'b',
            recordId: migrated.records.single.id,
            original: c.library.books.single.originals.single,
            reflection: reflection,
          ),
          isTrue,
        );
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
        expect(restored.books.single.originals.single.text, '책의 원문');
        expect(restored.books.single.originals.single.citation, '12쪽');
        expect(
          restored.books.single.originals.single.reflection!.toJson(),
          reflection.toJson(),
        );
        expect(restored.records.single.originals.single.text, '기록의 원문');
        expect(restored.books.single.coverIndex, 2);
        expect(restored.books.single.paperIndex, 3);
        expect(restored.style.paperIndex, original.style.paperIndex);
        expect(restored.style.pageMotion, isFalse);
        expect(restored.style.pageSound, isTrue);
        expect(restored.style.writingSound, isTrue);
        expect(restored.pages.single.text, original.pages.single.text);
        expect(
          restored.pages.single.passages.single.toJson(),
          passage.toJson(),
        );
        expect(
          restored.records.single.toJson()..remove('originals'),
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
    'Book materials and owner merge separately; botanical shape, color and placement merge independently',
    () {
      final base = specimen();
      final local = base.copy(
        books: [base.books.single.copy(coverIndex: 2)],
        style: base.style.copy(
          pageMotion: false,
          writingSound: true,
          bookDetails: base.style.bookDetails.withChoice(
            BookDetailKind.pressedFlower,
            const BookDetailChoice(placement: 2),
          ),
        ),
      );
      final remote = base.copy(
        books: [base.books.single.copy(owner: '필명', paperIndex: 3)],
        style: base.style.copy(
          pageSound: true,
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
      expect(result.books.single.owner, '필명');
      expect(result.books.single.coverIndex, 2);
      expect(result.books.single.paperIndex, 3);
      expect(result.style.pageMotion, isFalse);
      expect(result.style.pageSound, isTrue);
      expect(result.style.writingSound, isTrue);
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
      final legacy = base.toJson();
      final book = (legacy['books'] as List).single as Json;
      book['indexLabel'] = '다시 읽기';
      book['detailOverrides'] = {
        'indexTab': {'variant': 1},
      };
      final details = (legacy['style'] as Json)['bookDetails'] as Json;
      details['indexTab'] = {'enabled': true};
      expect(Library.decode(jsonEncode(legacy)).encode(), base.encode());
    },
  );

  testWidgets(
    'Book menus omit index actions and preserve writing, materials and decorations',
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
              onBook: (_) {},
              onNewSheet: (_) {},
              onNewBook: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('shelf-details-b')));
      await tester.pumpAndSettle();
      Future<void> choose(String label) async {
        await tester.tap(find.byTooltip('책 더 보기'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(label).last);
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }

      expect(find.text('목차'), findsOneWidget);
      await tester.tap(find.byTooltip('책 더 보기'));
      await tester.pumpAndSettle();
      expect(find.text('다른 책의 목차'), findsNothing);
      expect(find.text('색인 이름 고치기'), findsNothing);
      await tester.tap(find.text('장서표').last);
      await tester.pumpAndSettle();
      expect(find.byType(PressedFlower), findsOneWidget);
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
      final customize = find.widgetWithText(TextButton, '책 꾸미기');
      expect(tester.getSize(customize).height, greaterThanOrEqualTo(48));
      await tester.tap(customize);
      await tester.pumpAndSettle();
      await tester.tap(find.text('표지·내지'));
      await tester.pumpAndSettle();
      final cover = find.widgetWithText(ChoiceChip, '푸른 리넨');
      final paper = find.widgetWithText(ChoiceChip, '크림지');
      final coverPreview = find.descendant(
        of: find.byKey(const ValueKey('book-appearance-preview')),
        matching: find.byType(BookCover),
      );
      expect(cover, findsOneWidget);
      expect(paper, findsOneWidget);
      await tester.tap(cover);
      await tester.pumpAndSettle();
      expect(coverPreview, findsOneWidget);
      await tester.ensureVisible(paper);
      await tester.tap(paper);
      await tester.pumpAndSettle();
      expect(coverPreview, findsNothing);
      await tester.ensureVisible(cover);
      await tester.tap(cover);
      await tester.pumpAndSettle();
      expect(coverPreview, findsOneWidget);
      await tester.tap(find.byTooltip('뒤로'));
      await tester.pumpAndSettle();
      expect(c.library.books.first.coverIndex, 2);
      expect(c.library.books.first.paperIndex, 3);
      expect(c.library.books.last.coverIndex, isNull);
      expect(c.library.style.paperIndex, initial.style.paperIndex);
      await choose('책 꾸미기');
      await tester.tap(find.text('표지·내지'));
      await tester.pumpAndSettle();
      final defaultPaper = find.text('기본 종이 사용');
      await tester.ensureVisible(defaultPaper);
      await tester.tap(defaultPaper);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('뒤로'));
      await tester.pumpAndSettle();
      expect(c.library.books.first.paperIndex, isNull);
      expect(c.library.books.first.coverIndex, 2);
      expect(find.byType(RecordDivider), findsOneWidget);
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
