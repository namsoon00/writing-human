import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:writing_human/data/library_controller.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/data/sqlite_store.dart';
import 'package:writing_human/main.dart';
import 'package:writing_human/ui/cafe_screen.dart';
import 'package:writing_human/ui/workspace.dart';

import 'widget_test.dart' show MemoryStore;

final _field = find.byKey(const ValueKey('page-text'));
final _start = find.byKey(const ValueKey('cafe-start-writing'));
final _return = find.byKey(const ValueKey('return-to-cafe'));

const _library = Library(
  books: [
    Book(id: 'a', title: '곁에 둔 문장'),
    Book(id: 'b', title: '저녁의 책'),
  ],
  records: [
    WritingRecord(id: 'ra', bookId: 'a', title: '첫 글'),
    WritingRecord(id: 'rb', bookId: 'b', title: '둘째 글'),
  ],
  pages: [
    WritingPage(
      id: 'pa',
      recordId: 'ra',
      number: 1,
      text: '천천히 쓰는 문장',
      base: 2,
      extent: 5,
    ),
    WritingPage(id: 'pb', recordId: 'rb', number: 1, text: '저녁에 읽는 문장'),
  ],
  activePageId: 'pa',
  writing: true,
);

Future<void> _open(
  WidgetTester tester,
  MemoryStore store, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(WritingHumanApp(store: store));
  await tester.pumpAndSettle();
}

Future<void> _enterCafe(
  WidgetTester tester, {
  LibraryController? controller,
}) async {
  await tester.tap(find.byKey(const ValueKey('open-bookshelf')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('open-cafe')));
  await tester.pumpAndSettle();
  if (controller != null) {
    await tester.runAsync(() => controller.settled);
    await tester.pumpAndSettle();
  }
  expect(find.byType(CafeScreen), findsOneWidget);
  await tester.ensureVisible(find.byKey(const ValueKey('cafe-seat-window')));
  await tester.tap(find.byKey(const ValueKey('cafe-seat-window')));
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.tap(find.byKey(const ValueKey('cafe-choose-book')));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'A cafe visit preserves the editor, selection and saved writing',
    (tester) async {
      final store = MemoryStore()..data = _library;
      await _open(tester, store);
      final original = tester.widget<TextField>(_field).controller!;
      final value = original.value;
      final snapshot = store.data.encode();
      final writes = store.writes;
      await _enterCafe(tester);
      expect(find.textContaining('혼자 머무는'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cafe-seat-quiet')));
      await tester.pump();
      await tester.tap(_start);
      await tester.pumpAndSettle();
      expect(find.byType(CafeScreen), findsNothing);
      expect(tester.widget<TextField>(_field).controller, same(original));
      expect(original.value, value);
      expect(store.data.encode(), snapshot);
      expect(store.writes, writes);
      expect(find.text('안쪽 자리'), findsOneWidget);
      await tester.tap(_return);
      await tester.pumpAndSettle();
      expect(find.text('안쪽 자리에서 쓰기'), findsOneWidget);
      final leave = find.byKey(const ValueKey('leave-cafe'));
      await _reveal(tester, leave);
      await tester.tap(leave);
      await tester.pumpAndSettle();
      expect(_return, findsNothing);
      expect(original.value, value);
      expect(store.data.encode(), snapshot);
    },
  );

  testWidgets('An empty cafe and canceling a visit create no records', (
    tester,
  ) async {
    final store = MemoryStore();
    await _open(tester, store, size: const Size(320, 640));
    await _enterCafe(tester);
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    expect(store.writes, 0);
    await _enterCafe(tester);
    await tester.tap(_start);
    await tester.pumpAndSettle();
    expect(store.writes, 0);
    expect(store.data.records, isEmpty);
    expect(store.data.pages, isEmpty);
    await tester.enterText(_field, '카페에서 처음 쓰는 글');
    await tester.pumpAndSettle();
    expect(store.data.pages.single.text, '카페에서 처음 쓰는 글');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'A different book resumes its own page and keeps the previous book',
    (tester) async {
      final store = MemoryStore()..data = _library;
      await _open(tester, store);
      await _enterCafe(tester);
      final book = find.byKey(const ValueKey('cafe-book-b'));
      await _reveal(tester, book);
      await tester.tap(book);
      await tester.tap(find.text('고르기'));
      await tester.pumpAndSettle();
      await tester.tap(_start);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_field).controller!.text, '저녁에 읽는 문장');
      expect(store.data.activePageId, 'pb');
      expect(store.data.pages.first.text, _library.pages.first.text);
      expect(store.data.pages.first.base, 2);
      expect(store.data.pages.first.extent, 5);
    },
  );

  testWidgets('Composition cannot be interrupted by returning to the cafe', (
    tester,
  ) async {
    final store = MemoryStore()..data = _library;
    await _open(tester, store);
    await _enterCafe(tester);
    await tester.tap(_start);
    await tester.pumpAndSettle();
    await tester.tap(_field);
    await tester.pump();
    const composing = TextEditingValue(
      text: '한글을 쓰는 사ㄹ',
      selection: TextSelection.collapsed(offset: 9),
      composing: TextRange(start: 7, end: 9),
    );
    tester.testTextInput.updateEditingValue(composing);
    await tester.pumpAndSettle();
    await tester.tap(_return);
    await tester.pumpAndSettle();
    expect(find.byType(CafeScreen), findsNothing);
    expect(tester.widget<TextField>(_field).controller!.value, composing);
    expect(find.text('입력을 마친 뒤 카페를 열어 주세요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Failed saves keep the cafe open until an explicit successful retry',
    (tester) async {
      final store = MemoryStore()..data = _library;
      await _open(tester, store);
      await _enterCafe(tester);
      final book = find.byKey(const ValueKey('cafe-book-b'));
      await _reveal(tester, book);
      await tester.tap(book);
      await tester.tap(find.text('고르기'));
      await tester.pumpAndSettle();
      store.fail = true;
      await tester.tap(_start);
      await tester.pumpAndSettle();
      expect(find.byType(CafeScreen), findsOneWidget);
      expect(find.textContaining('글을 저장하지 못했어요.'), findsOneWidget);
      expect(store.data.activePageId, 'pa');
      expect(tester.widget<FilledButton>(_start).onPressed, isNull);
      store.fail = false;
      await tester.tap(find.text('다시 저장'));
      await tester.pumpAndSettle();
      await tester.tap(_start);
      await tester.pumpAndSettle();
      expect(find.byType(CafeScreen), findsNothing);
      expect(store.data.activePageId, 'pb');
      expect(store.data.pages.first.text, _library.pages.first.text);
    },
  );

  testWidgets(
    'Large text keeps cafe choices scrollable and the action reachable',
    (tester) async {
      final store = MemoryStore();
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _open(tester, store, size: const Size(320, 640));
      await _enterCafe(tester);
      expect(MediaQuery.textScalerOf(tester.element(_start)).scale(20), 40);
      final seat = find.byKey(const ValueKey('cafe-seat-quiet'));
      await _reveal(tester, seat);
      await tester.tap(seat);
      await tester.pumpAndSettle();
      expect(_start.hitTestable(), findsOneWidget);
      await tester.tap(_start);
      await tester.pumpAndSettle();
      expect(_return.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('A visit waits for pending writes before opening the room', (
    tester,
  ) async {
    final store = _GatedStore()..data = _library;
    await _open(tester, store);
    await _enterCafe(tester);
    await tester.tap(_start);
    await tester.pumpAndSettle();
    store.gate = Completer<void>();
    await tester.enterText(_field, '저장을 기다리는 글');
    await tester.pump();
    await tester.tap(_return);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CafeScreen), findsNothing);
    store.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CafeScreen), findsOneWidget);
    expect(store.data.activePage!.text, '저장을 기다리는 글');
  });

  testWidgets(
    'Cafe writing survives closing and reopening an actual SQLite file',
    (tester) async {
      sqfliteFfiInit();
      late Directory directory;
      late SqliteLibraryStore store;
      late LibraryController controller;
      await tester.runAsync(() async {
        directory = await Directory.systemTemp.createTemp('writing-cafe-');
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
      await tester.pumpWidget(
        MaterialApp(home: Workspace(controller: controller)),
      );
      await tester.pumpAndSettle();
      await _enterCafe(tester, controller: controller);
      await tester.runAsync(() async {
        await tester.tap(_start);
        await controller.settled;
      });
      await tester.pumpAndSettle();
      await tester.enterText(_field, '실제 파일에 남기는 카페의 문장');
      await tester.pump();
      await tester.runAsync(() => controller.settled);
      await tester.pumpAndSettle();
      final id = controller.library.activePageId;
      await tester.tap(_return);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        controller.dispose();
        await store.close();
        store = await SqliteLibraryStore.open(
          '${directory.path}/library.db',
          factory: databaseFactoryFfi,
        );
        controller = LibraryController(store, await store.load());
      });
      await tester.pumpWidget(
        MaterialApp(home: Workspace(controller: controller)),
      );
      await tester.pumpAndSettle();
      expect(controller.library.activePageId, id);
      expect(
        tester.widget<TextField>(_field).controller!.text,
        '실제 파일에 남기는 카페의 문장',
      );
      expect(_return, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _GatedStore extends MemoryStore {
  Completer<void>? gate;
  @override
  Future<void> save(Library library) async {
    if (gate case final pending?) await pending.future;
    await super.save(library);
  }
}
