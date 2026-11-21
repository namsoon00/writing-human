import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:writing_human/data/library_controller.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/data/sqlite_store.dart';
import 'package:writing_human/sync/merge.dart';
import 'package:writing_human/ui/book_detail_design.dart';
import 'package:writing_human/ui/book_detail_tools.dart';
import 'package:writing_human/ui/book_details.dart';
import 'package:writing_human/ui/paper.dart';
import 'package:writing_human/ui/workspace.dart';
import 'book_details_test.dart' show specimen;
import 'widget_test.dart' show MemoryStore;

void main() {
  sqfliteFfiInit();
  test('Printed metadata stays readable on all papers and slip tones', () {
    for (final background in [
      ...paperColors,
      ...BookDetailDesign.of(BookDetailKind.sourceSlip).colors,
      const Color(0xfff8f2e5),
    ]) {
      expect(
        (background.computeLuminance() + .05) /
            (detailMetadataInk.computeLuminance() + .05),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
  test(
    'Ten independent choices survive SQLite reopen with annotations, owner and position',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'writing-independent-details-',
      );
      final path = '${directory.path}/library.db';
      var store = await SqliteLibraryStore.open(
        path,
        factory: databaseFactoryFfi,
      );
      final c = LibraryController(store, specimen());
      try {
        c.setBookOwner('b', '남기는 사람');
        c.togglePencilMark('p', 0, 7);
        var details = const BookDetailsStyle();
        for (final kind in BookDetailKind.values) {
          details = details.withChoice(
            kind,
            BookDetailChoice(
              enabled: kind.index.isEven,
              variant: kind.index % 3,
              tone: kind.index % 4,
            ),
          );
        }
        c.setStyle(
          c.library.style.copy(
            paperIndex: 2,
            penIndex: 1,
            fontIndex: 2,
            bookDetails: details,
          ),
        );
        final other = c.addBook('다른 책', '');
        expect(
          await c.saveBookAppearance(
            'b',
            coverIndex: 2,
            paperIndex: 3,
            useDefaultPaper: false,
            changes: {
              for (final kind in BookDetailKind.values)
                kind: details.choice(kind).copy(variant: 1, tone: 3),
            },
          ),
          isTrue,
        );
        expect(c.detailsFor(other).toJson(), details.toJson());
        final expected = c.library.encode();
        await c.settled;
        expect(c.saveError, isNull);
        await store.close();
        store = await SqliteLibraryStore.open(
          path,
          factory: databaseFactoryFfi,
        );
        final restored = await store.load();
        expect(restored.encode(), expected);
        expect(restored.activePage!.pencilMarks.single.end, 7);
        final restoredBook = restored.books.first;
        expect(restoredBook.owner, '남기는 사람');
        expect(
          restoredBook.detailOverrides.length,
          BookDetailKind.values.length,
        );
        expect(restoredBook.coverIndex, 2);
        expect(restoredBook.paperIndex, 3);
        expect(restored.books.last.detailOverrides, isEmpty);
        expect(Library.decode(restored.encode()).encode(), expected);
        expect(restored.activePage!.writtenOn, '2026-11-10');
      } finally {
        c.dispose();
        await store.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test('Book overrides merge against the inherited style on first edit', () {
    final fixture = specimen();
    final inherited = const BookDetailChoice(variant: 2, tone: 1);
    final base = fixture.copy(
      style: fixture.style.copy(
        bookDetails: fixture.style.bookDetails.withChoice(
          BookDetailKind.ribbon,
          inherited,
        ),
      ),
    );
    Library withRibbon(BookDetailChoice choice) => base.copy(
      books: [
        base.books.single.copy(
          detailOverrides: {BookDetailKind.ribbon: choice},
        ),
      ],
    );
    final merged = mergeLibraries(
      base,
      withRibbon(inherited.copy(tone: 3)),
      withRibbon(inherited.copy(variant: 1)),
    ).library;
    expect(
      merged.books.single.detailOverrides[BookDetailKind.ribbon]?.toJson(),
      inherited.copy(variant: 1, tone: 3).toJson(),
    );
    expect(merged.style.bookDetails.ribbon.toJson(), inherited.toJson());
  });

  test(
    'Concurrent changes to the same element merge field by field alongside paper and ink',
    () {
      final base = specimen();
      final local = base.copy(
        style: base.style.copy(
          paperIndex: 2,
          bookDetails: base.style.bookDetails.withChoice(
            BookDetailKind.ribbon,
            const BookDetailChoice(tone: 2),
          ),
        ),
      );
      final remote = base.copy(
        style: base.style.copy(
          penIndex: 1,
          bookDetails: base.style.bookDetails
              .withChoice(
                BookDetailKind.ribbon,
                const BookDetailChoice(variant: 1),
              )
              .withChoice(
                BookDetailKind.dateStamp,
                const BookDetailChoice(enabled: false, tone: 3),
              ),
        ),
      );
      final result = mergeLibraries(base, local, remote).library;
      expect(result.style.paperIndex, 2);
      expect(result.style.penIndex, 1);
      expect(result.style.bookDetails.ribbon.toJson(), {
        'enabled': true,
        'variant': 1,
        'tone': 2,
      });
      expect(result.style.bookDetails.dateStamp.enabled, isFalse);
      expect(
        result.style.bookDetails.bookplate.toJson(),
        base.style.bookDetails.bookplate.toJson(),
      );
    },
  );

  test(
    'Legacy settings keep their choices and invalid detail settings fail instead of clearing records',
    () {
      final json = specimen().toJson();
      final style = json['style'] as Json;
      style.remove('bookDetails');
      final restored = WritingStyle.fromJson(style);
      expect(restored.bookDetails.toJson(), const BookDetailsStyle().toJson());
      for (final invalid in [
        null,
        2,
        {
          'ribbon': {'enabled': 'yes'},
        },
        {
          'pencil': {'variant': 3},
        },
        {
          'binding': {'tone': -1},
        },
      ]) {
        expect(
          () => WritingStyle.fromJson({...style, 'bookDetails': invalid}),
          throwsA(anything),
        );
      }
    },
  );

  test('Small date text remains legible on every paper color', () {
    for (final color in BookDetailDesign.of(BookDetailKind.dateStamp).colors) {
      for (final background in paperColors) {
        expect(
          (background.computeLuminance() + .05) /
              (color.computeLuminance() + .05),
          greaterThanOrEqualTo(4.5),
        );
      }
    }
  });

  testWidgets(
    'Every detail changes without replacing composing text or its live controller',
    (tester) async {
      final store = MemoryStore();
      final c = LibraryController(store, specimen());
      addTearDown(c.dispose);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: Workspace(controller: c)));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('page-text'));
      await tester.tap(field);
      await tester.pumpAndSettle();
      final controller = tester.widget<TextField>(field).controller!;
      const composing = TextEditingValue(
        text: '마음에 남는 사ㄹ',
        selection: TextSelection.collapsed(offset: 9),
        composing: TextRange(start: 7, end: 9),
      );
      tester.testTextInput.updateEditingValue(composing);
      await tester.pumpAndSettle();
      for (final kind in BookDetailKind.values) {
        c.setStyle(
          c.library.style.copy(
            bookDetails: c.library.style.bookDetails.withChoice(
              kind,
              const BookDetailChoice(enabled: false, variant: 2, tone: 3),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(field).controller, same(controller));
        expect(controller.value, composing);
      }
      expect(c.library.pages.single.text, composing.text);
      expect(c.library.books.single.id, 'b');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await c.settled;
    },
  );

  testWidgets(
    'Tools change and reset only one element; failed settings save can retry',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryStore();
      final fixture = specimen();
      final c = LibraryController(
        store,
        fixture.copy(
          records: [
            WritingRecord.fromJson(
              fixture.records.single.toJson()..['bookId'] = null,
            ),
          ],
        ),
      );
      addTearDown(c.dispose);
      final original = c.library.style.bookDetails.withChoice(
        BookDetailKind.dateStamp,
        const BookDetailChoice(variant: 1, tone: 2),
      );
      c.setStyle(c.library.style.copy(bookDetails: original));
      final inherited = c.addBook('기본값을 쓰는 책', '');
      const fixedRibbon = BookDetailChoice(variant: 2, tone: 1);
      await c.saveBookAppearance(
        'b',
        paperIndex: 3,
        useDefaultPaper: false,
        changes: {BookDetailKind.ribbon: fixedRibbon},
      );
      await c.settled;
      await tester.pumpWidget(MaterialApp(home: Workspace(controller: c)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-bookshelf')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('설정'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('회백지'));
      await tester.pumpAndSettle();
      expect(c.styleFor(inherited).paperIndex, 2);
      expect(c.styleFor(null).paperIndex, 2);
      expect(c.styleFor(c.library.books.first).paperIndex, 3);
      await tester.ensureVisible(find.text('기본 장식'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('기본 장식'));
      await tester.pumpAndSettle();
      expect(find.textContaining('책에서 따로 고르지 않은 장식에 적용돼요.'), findsOneWidget);
      expect(find.byKey(const ValueKey('detail-binding')), findsNothing);
      expect(find.byType(BookDetailSample), findsWidgets);
      expect(find.text('모양'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('detail-ribbon')));
      await tester.pumpAndSettle();
      expect(find.text('책갈피 표시'), findsOneWidget);
      expect(find.text('모양'), findsOneWidget);
      expect(find.text('색'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('detail-ribbon-variant-1')));
      await tester.pumpAndSettle();
      expect(c.library.style.bookDetails.ribbon.variant, 1);
      expect(c.detailsFor(inherited).ribbon.variant, 1);
      expect(
        c.detailsFor(c.library.books.first).ribbon.toJson(),
        fixedRibbon.toJson(),
      );
      store.fail = true;
      await tester.ensureVisible(
        find.byKey(const ValueKey('detail-ribbon-tone-2')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('detail-ribbon-tone-2')));
      await tester.pumpAndSettle();
      final retry = find.text('다시 저장').hitTestable();
      expect(find.text('설정을 저장하지 못했어요.'), findsOneWidget);
      expect(retry, findsOneWidget);
      store.fail = false;
      await tester.tap(retry);
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('detail-ribbon-enabled'))),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('detail-ribbon-enabled')));
      await tester.pumpAndSettle();
      expect(c.library.style.bookDetails.ribbon.enabled, isFalse);
      expect(c.library.style.bookDetails.ribbon.variant, 1);
      expect(c.library.style.bookDetails.ribbon.tone, 2);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('detail-ribbon-tone-2')),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('detail-ribbon-reset')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('detail-ribbon-reset')));
      await tester.pumpAndSettle();
      expect(
        c.library.style.bookDetails.ribbon.toJson(),
        const BookDetailChoice().toJson(),
      );
      expect(
        c.library.style.bookDetails.dateStamp.toJson(),
        original.dateStamp.toJson(),
      );
      expect(c.library.activePage!.text, specimen().activePage!.text);
      await tester.tap(find.byTooltip('뒤로'));
      await tester.pumpAndSettle();
      expect(find.text('기본 장식'), findsOneWidget);
      expect(find.text('사선 끝 · 포도'), findsOneWidget);
    },
  );

  testWidgets(
    'All 30 shapes, four tones and hidden states fit 320px with enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final kind in BookDetailKind.values) {
        for (var variant = 0; variant < 3; variant++) {
          for (var tone = 0; tone < 4; tone++) {
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: BookDetailPreview(
                        kind: kind,
                        choice: BookDetailChoice(variant: variant, tone: tone),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '${kind.name} $variant $tone',
            );
          }
        }
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BookDetailPreview(
                kind: kind,
                choice: const BookDetailChoice(enabled: false),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );
}
