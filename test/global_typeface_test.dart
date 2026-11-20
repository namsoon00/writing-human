import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/data/sqlite_store.dart';
import 'package:writing_human/data/store.dart';
import 'package:writing_human/main.dart';
import 'package:writing_human/ui/paper.dart';

class SnapshotStore implements LibraryStore {
  SnapshotStore(this.snapshot);
  String snapshot;
  int writes = 0;
  @override
  Future<Library> load() async => Library.decode(snapshot);
  @override
  Future<void> save(Library library) async {
    writes++;
    snapshot = library.encode();
  }

  @override
  Future<void> close() async {}
}

Json legacyLibrary() {
  final json = const Library(
    books: [Book(id: 'b', title: '내 책')],
    records: [WritingRecord(id: 'r', bookId: 'b', title: '내 문장')],
    pages: [
      WritingPage(
        id: 'p',
        recordId: 'r',
        number: 1,
        text: '남겨 둔 문장',
        base: 2,
        extent: 5,
        scroll: 31,
      ),
      WritingPage(id: 'p2', recordId: 'r', number: 2, text: '두 번째 페이지'),
    ],
    activePageId: 'p',
    writing: true,
    style: WritingStyle(
      paperIndex: 2,
      penIndex: 1,
      fontIndex: 2,
      useDevelopmentTypeface: false,
      guides: true,
    ),
  ).toJson();
  (json['style'] as Json).remove('typefaceDefaultsVersion');
  return json;
}

void main() {
  sqfliteFfiInit();
  test(
    'Legacy web settings adopt the full font once; later choices survive',
    () {
      final before = legacyLibrary();
      final library = Library.decode(jsonEncode(before));
      expect(library.style.useDevelopmentTypeface, isTrue);
      expect(library.style.paperIndex, 2);
      expect(library.style.penIndex, 1);
      expect(library.style.fontIndex, 2);
      expect(library.style.guides, isTrue);
      for (final field in [
        'books',
        'records',
        'pages',
        'activePageId',
        'writing',
      ]) {
        expect(library.toJson()[field], before[field], reason: field);
      }
      final alternative = library.copy(
        style: library.style.copy(useDevelopmentTypeface: false),
      );
      final reopened = Library.decode(alternative.encode());
      expect(reopened.style.useDevelopmentTypeface, isFalse);
      expect(reopened.style.fontIndex, 2);
      expect(reopened.toJson()['pages'], before['pages']);
      expect(
        (reopened.toJson()['style'] as Json)['typefaceDefaultsVersion'],
        1,
      );
      expect(
        () => WritingStyle.fromJson({'typefaceDefaultsVersion': 2}),
        throwsFormatException,
      );
    },
  );

  test(
    'Actual SQLite legacy settings preserve pages and later explicit fonts',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'global-typeface-',
      );
      final file = '${directory.path}/library.db';
      var store = await SqliteLibraryStore.open(
        file,
        factory: databaseFactoryFfi,
      );
      try {
        final old = legacyLibrary();
        await store.save(Library.decode(jsonEncode(old)));
        await store.db.update('app_state', {
          'settings': jsonEncode(old['style']),
        }, where: 'id = 1');
        await store.close();
        store = await SqliteLibraryStore.open(
          file,
          factory: databaseFactoryFfi,
        );
        final migrated = await store.load();
        expect(migrated.style.useDevelopmentTypeface, isTrue);
        expect(migrated.toJson()['pages'], old['pages']);
        expect(migrated.activePageId, 'p');
        await store.save(
          migrated.copy(
            style: migrated.style.copy(useDevelopmentTypeface: false),
          ),
        );
        await store.close();
        store = await SqliteLibraryStore.open(
          file,
          factory: databaseFactoryFfi,
        );
        final reopened = await store.load();
        expect(reopened.style.useDevelopmentTypeface, isFalse);
        expect(reopened.style.paperIndex, 2);
        expect(reopened.style.penIndex, 1);
        expect(reopened.toJson()['pages'], old['pages']);
      } finally {
        await store.close();
        await directory.delete(recursive: true);
      }
    },
  );

  testWidgets(
    'Font size controls and two-finger zoom preserve the live editor',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = SnapshotStore(jsonEncode(legacyLibrary()));
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('page-text'));
      final controller = tester.widget<TextField>(field).controller!;
      final before = controller.value;
      expect(tester.widget<TextField>(field).style!.fontSize, 20);
      await tester.tap(find.byTooltip('쓰기 도구'));
      await tester.pumpAndSettle();
      final control = find.byTooltip('글자 크게');
      await tester.ensureVisible(control);
      await tester.tap(control);
      await tester.pumpAndSettle();
      expect(Library.decode(store.snapshot).style.fontSize, 21);
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller, same(controller));
      expect(controller.value, before);
      expect(tester.widget<TextField>(field).style!.fontSize, 21);
      final bounds = tester.getRect(field);
      final middle = Offset(bounds.center.dx, bounds.top + 100);

      Future<void> pinch(double factor) async {
        final first = await tester.startGesture(
          middle - const Offset(40, 0),
          pointer: 1,
        );
        final second = await tester.startGesture(
          middle + const Offset(40, 0),
          pointer: 2,
        );
        await tester.pump();
        await first.moveTo(middle - Offset(40 * factor, 0));
        await second.moveTo(middle + Offset(40 * factor, 0));
        await tester.pump();
        await first.up();
        await second.up();
        await tester.pumpAndSettle();
      }

      await pinch(1.35);
      final enlarged = Library.decode(store.snapshot).style.fontSize;
      expect(enlarged, greaterThan(21));
      expect(enlarged, lessThanOrEqualTo(WritingStyle.maxFontSize));
      expect(tester.widget<TextField>(field).controller, same(controller));
      expect(controller.text, before.text);
      expect(controller.selection, before.selection);
      expect(Library.decode(store.snapshot).pages.length, 2);
      expect(Library.decode(store.snapshot).activePageId, 'p');
      await pinch(.5);
      final reduced = Library.decode(store.snapshot).style.fontSize;
      expect(reduced, WritingStyle.minFontSize);
      expect(controller.text, before.text);
      expect(controller.selection, before.selection);

      await tester.showKeyboard(field);
      final composing = TextEditingValue(
        text: controller.text,
        selection: const TextSelection.collapsed(offset: 2),
        composing: const TextRange(start: 1, end: 2),
      );
      tester.testTextInput.updateEditingValue(composing);
      await tester.pumpAndSettle();
      await pinch(1.35);
      expect(controller.value, composing);
      expect(Library.decode(store.snapshot).style.fontSize, reduced);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).style!.fontSize, reduced);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Maximum font preview and tools fit a narrow screen with large system text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final library = Library.decode(jsonEncode(legacyLibrary()));
      final store = SnapshotStore(
        library.copy(style: library.style.copy(fontSize: 30)).encode(),
      );
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('쓰기 도구'));
      await tester.pumpAndSettle();
      final smaller = find.byTooltip('글자 작게');
      await tester.ensureVisible(smaller);
      await tester.pumpAndSettle();
      await tester.tap(smaller);
      await tester.pumpAndSettle();
      expect(Library.decode(store.snapshot).style.fontSize, 29);
      await tester.ensureVisible(find.text('기록 보관'));
      await tester.pumpAndSettle();
      expect(find.text('기록 보관').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Ordinary app uses the font in editor, library, dialogs and tools',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = SnapshotStore(jsonEncode(legacyLibrary()));
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('page-text'));
      final controller = tester.widget<TextField>(field).controller!;
      expect(tester.widget<TextField>(field).style!.fontFamily, appFontFamily);
      final editorStyle = tester.widget<TextField>(field).style!;
      expect(
        MediaQuery.textScalerOf(
          tester.element(field),
        ).scale(editorStyle.fontSize!),
        closeTo(20, .001),
      );
      expect(controller.text, '남겨 둔 문장');
      expect(
        controller.selection,
        const TextSelection(baseOffset: 2, extentOffset: 5),
      );
      expect(
        store.writes,
        0,
        reason: 'Reading a migrated font must not create a save',
      );
      final theme = Theme.of(tester.element(field));
      for (final style in [
        theme.textTheme.displayLarge,
        theme.textTheme.displayMedium,
        theme.textTheme.displaySmall,
        theme.textTheme.headlineLarge,
        theme.textTheme.headlineMedium,
        theme.textTheme.headlineSmall,
        theme.textTheme.titleLarge,
        theme.textTheme.titleMedium,
        theme.textTheme.titleSmall,
        theme.textTheme.bodyLarge,
        theme.textTheme.bodyMedium,
        theme.textTheme.bodySmall,
        theme.textTheme.labelLarge,
        theme.textTheme.labelMedium,
        theme.textTheme.labelSmall,
      ]) {
        expect(style!.fontFamily, appFontFamily);
        expect(style.fontFamilyFallback, appFontFallback);
      }
      void expectTypeface(String text) {
        final rich = find.descendant(
          of: find.text(text).last,
          matching: find.byType(RichText),
        );
        expect(rich, findsOneWidget, reason: text);
        expect(
          tester.widget<RichText>(rich).text.style!.fontFamily,
          appFontFamily,
          reason: text,
        );
      }

      expectTypeface('내 책');
      expectTypeface('책장');
      await tester.tap(find.text('책장'));
      await tester.pumpAndSettle();
      expectTypeface('책장');
      expectTypeface('새 책');
      await tester.tap(find.text('새 책'));
      await tester.pumpAndSettle();
      expectTypeface('책 만들고 쓰기');
      final input = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      expect(input.style.fontFamily, appFontFamily);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('쓰기 도구'));
      await tester.pumpAndSettle();
      expectTypeface('쓰는 인간체');
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '쓰는 인간체'))
            .selected,
        isTrue,
      );
      await tester.tap(find.text('나눔고딕'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller, same(controller));
      expect(controller.text, '남겨 둔 문장');
      expect(
        controller.selection,
        const TextSelection(baseOffset: 2, extentOffset: 5),
      );
      expect(tester.widget<TextField>(field).style!.fontFamily, 'NanumGothic');
      expectTypeface('내 책');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).style!.fontFamily, 'NanumGothic');
      expect(tester.widget<TextField>(field).controller!.text, '남겨 둔 문장');
      expectTypeface('내 책');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
