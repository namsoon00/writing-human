import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:writing_human/data/library_controller.dart';
import 'package:writing_human/data/sqlite_store.dart';
import 'package:writing_human/ui/workspace.dart';
import 'package:writing_human/ui/paper_swipe.dart';

void main() {
  sqfliteFfiInit();
  testWidgets('Paper editor writes to SQLite and restores after reopening', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late Directory directory;
    late SqliteLibraryStore store;
    late LibraryController controller;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('writing-paper-ui-');
      store = await SqliteLibraryStore.open(
        '${directory.path}/library.db',
        factory: databaseFactoryFfi,
      );
      controller = LibraryController(store, await store.load());
    });
    addTearDown(() async {
      controller.dispose();
      await store.close();
      await directory.delete(recursive: true);
    });
    Widget app() => MaterialApp(home: Workspace(controller: controller));
    Future<void> saved() async {
      await tester.pump();
      await tester.runAsync(() => controller.settled);
      await tester.pumpAndSettle();
      expect(controller.saveError, isNull);
    }

    Future<void> turn(double distance) async {
      final number = find.byKey(const ValueKey('page-number'));
      final gesture = await tester.startGesture(tester.getCenter(number));
      await gesture.moveBy(Offset(distance, 0));
      await tester.pump();
      expect(find.byKey(const ValueKey('page-turn-reveal')), findsOneWidget);
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      await saved();
      final footer = find.byKey(const ValueKey('page-number-swipe'));
      if (footer.evaluate().isNotEmpty) {
        // The new page is already visible; its position write can finish later.
        await saved();
        expect(tester.widget<PaperSwipe>(footer).onNext, isNotNull);
      }
      expect(find.byKey(const ValueKey('page-turn-reveal')), findsNothing);
    }

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('보관함'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('새 책 만들기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '실제 파일 검수');
    await tester.tap(find.text('책 만들고 쓰기'));
    await saved();
    await tester.tap(find.byKey(const ValueKey('place-source')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('source-text')),
      '먼저 골라 둔 실제 파일 원문',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('source-confirm')));
    await tester.pumpAndSettle();
    await saved();
    expect(controller.library.records.single.source, '먼저 골라 둔 실제 파일 원문');
    final field = find.byKey(const ValueKey('page-text'));
    final text = tester.widget<TextField>(field).controller!;
    expect(
      tester.widget<TextField>(field).style!.fontFamily,
      'WritingHumanDevelopment',
    );
    await tester.tap(find.byTooltip('쓰기 도구'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('쓰는 인간체'));
    await saved();
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller, same(text));
    expect(
      tester.widget<TextField>(field).style!.fontFamily,
      'WritingHumanDevelopment',
    );
    await tester.tap(field);
    await tester.pump();
    const composing = TextEditingValue(
      text: '한글을 쓰는 사ㄹ',
      selection: TextSelection.collapsed(offset: 9),
      composing: TextRange(start: 7, end: 9),
    );
    tester.testTextInput.updateEditingValue(composing);
    await saved();
    expect(tester.widget<TextField>(field).controller, same(text));
    expect(text.value, composing);

    final body = List.filled(70, '새 종이에도 온전히 남는 한글 문장. 🌿').join('\n');
    final committed = TextEditingValue(
      text: body,
      selection: const TextSelection(baseOffset: 3, extentOffset: 8),
    );
    tester.testTextInput.updateEditingValue(committed);
    await saved();
    tester.widget<TextField>(field).scrollController!.jumpTo(710);
    await saved();
    final pageId = controller.library.activePageId;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await controller.settled;
      controller.dispose();
      await store.close();
      expect(
        await File('${directory.path}/library.db').length(),
        greaterThan(0),
      );
      store = await SqliteLibraryStore.open(
        '${directory.path}/library.db',
        factory: databaseFactoryFfi,
      );
      controller = LibraryController(store, await store.load());
    });
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final restored = tester.widget<TextField>(field);
    expect(restored.controller!.text, body);
    expect(restored.controller!.selection, committed.selection);
    expect(restored.scrollController!.offset, 710);
    expect(restored.style!.fontFamily, 'WritingHumanDevelopment');
    expect(restored.style!.fontFamilyFallback, contains('NanumMyeongjo'));
    expect(controller.library.style.useDevelopmentTypeface, isTrue);
    expect(controller.library.activePageId, pageId);
    expect(controller.library.books.single.title, '실제 파일 검수');
    expect(controller.library.records.single.source, '먼저 골라 둔 실제 파일 원문');
    expect(
      controller.library.records.single.bookId,
      controller.library.books.single.id,
    );
    expect(find.text('저장됨'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await turn(-160);
    expect(find.byKey(const ValueKey('book-back-cover')), findsOneWidget);
    await tester.runAsync(() async {
      final stored = await store.load();
      expect(stored.pages.length, 1);
      expect(stored.activePageId, pageId);
      expect(stored.activePage!.text, body);
      expect(stored.activePage!.scroll, 710);
    });
    await tester.tap(find.text('한 쪽 더'));
    await saved();
    expect(find.text('2'), findsOneWidget);
    const next = TextEditingValue(
      text: '두 번째 쪽도 실제 파일에 남깁니다.',
      selection: TextSelection(baseOffset: 2, extentOffset: 5),
    );
    await tester.tap(field);
    tester.testTextInput.updateEditingValue(next);
    await saved();
    final secondId = controller.library.activePageId;
    expect(controller.library.pages.length, 2);
    expect(controller.library.pages.first.text, body);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await controller.settled;
      controller.dispose();
      await store.close();
      store = await SqliteLibraryStore.open(
        '${directory.path}/library.db',
        factory: databaseFactoryFfi,
      );
      controller = LibraryController(store, await store.load());
    });
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(controller.library.activePageId, secondId);
    expect(find.text('2'), findsOneWidget);
    expect(tester.widget<TextField>(field).controller!.value, next);
    await turn(160);
    expect(controller.library.activePageId, pageId);
    expect(tester.widget<TextField>(field).controller!.text, body);
    expect(
      tester.widget<TextField>(field).controller!.selection,
      committed.selection,
    );
    expect(tester.widget<TextField>(field).scrollController!.offset, 710);
    await turn(160);
    expect(find.byKey(const ValueKey('book-front-cover')), findsOneWidget);
    await tester.runAsync(() async {
      final stored = await store.load();
      expect(stored.activePageId, pageId);
      expect(stored.pages.length, 2);
      expect(stored.activePage!.text, body);
    });
    await tester.tap(find.text('책 펼치기'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, body);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.runAsync(() => controller.settled);
  });
}
