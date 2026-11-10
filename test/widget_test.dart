import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/main.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/data/store.dart';

class MemoryStore implements LibraryStore {
  Library data = const Library();
  bool fail = false;
  @override
  Future<Library> load() async => Library.decode(data.encode());
  @override
  Future<void> save(Library library) async {
    if (fail) {
      throw StateError('disk full');
    }
    data = Library.decode(library.encode());
  }

  @override
  Future<void> close() async {}
}

void main() {
  testWidgets(
    'Create book, compose Korean, reopen and restore text and selection',
    (tester) async {
      final store = MemoryStore();
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('첫 책 만들기'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '오래 곁에 둘 문장들');
      await tester.tap(find.text('책 만들고 쓰기'));
      await tester.pumpAndSettle();
      final editor = find.byKey(const ValueKey('page-text'));
      await tester.tap(editor);
      await tester.pump();
      const composing = TextEditingValue(
        text: '한글을 쓰는 사ㄹ',
        selection: TextSelection.collapsed(offset: 9),
        composing: TextRange(start: 7, end: 9),
      );
      tester.testTextInput.updateEditingValue(composing);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(editor).controller!.value, composing);
      const committed = TextEditingValue(
        text: '한글을 쓰는 사람.\n천천히, 나의 속도로.',
        selection: TextSelection(baseOffset: 2, extentOffset: 6),
      );
      tester.testTextInput.updateEditingValue(committed);
      await tester.pumpAndSettle();
      expect(store.data.activePage!.text, committed.text);
      expect(store.data.activePage!.base, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      final restored = tester.widget<TextField>(editor).controller!.value;
      expect(restored.text, committed.text);
      expect(restored.selection, committed.selection);
      expect(find.text('저장됨'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Save failure is visible; retry persists the latest draft', (
    tester,
  ) async {
    final store = MemoryStore();
    await tester.pumpWidget(WritingHumanApp(store: store));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('책 없이, 먼저 한 문장 쓰기'));
    await tester.tap(find.text('책 없이, 먼저 한 문장 쓰기'));
    await tester.pumpAndSettle();
    store.fail = true;
    await tester.enterText(
      find.byKey(const ValueKey('page-text')),
      '지워지면 안 되는 문장',
    );
    await tester.pumpAndSettle();
    expect(find.text('저장 실패'), findsOneWidget);
    expect(find.text('저장됨'), findsNothing);
    store.fail = false;
    await tester.tap(find.text('저장 재시도'));
    await tester.pumpAndSettle();
    expect(store.data.activePage!.text, '지워지면 안 되는 문장');
    expect(find.text('저장됨'), findsOneWidget);
  });

  testWidgets(
    'Narrow screen restores long-page scroll and fits an open keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final store = MemoryStore();
      store.data = Library(
        books: const [Book(id: 'b', title: '긴 문장')],
        records: const [WritingRecord(id: 'r', bookId: 'b', title: '필사 1')],
        pages: [
          WritingPage(
            id: 'p',
            recordId: 'r',
            number: 1,
            text: List.filled(70, '천천히 적는 긴 한글 문장입니다.').join('\n'),
            scroll: 340,
            base: 10,
            extent: 10,
          ),
        ],
        activePageId: 'p',
        writing: true,
      );
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      final editor = find.byKey(const ValueKey('page-text'));
      expect(tester.widget<TextField>(editor).scrollController!.offset, 340);
      tester.widget<TextField>(editor).scrollController!.jumpTo(710);
      await tester.pumpAndSettle();
      expect(store.data.activePage!.scroll, 710);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(editor).scrollController!.offset, 710);
      await tester.tap(editor);
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = const FakeViewPadding();
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Writing tools change independently without replacing text or selection',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryStore();
      store.data = const Library(
        records: [WritingRecord(id: 'r', title: '필사 1')],
        pages: [
          WritingPage(
            id: 'p',
            recordId: 'r',
            number: 1,
            text: '끝까지 남아야 하는 문장',
            base: 2,
            extent: 5,
          ),
        ],
        activePageId: 'p',
        writing: true,
      );
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      final editor = find.byKey(const ValueKey('page-text'));
      final controller = tester.widget<TextField>(editor).controller!;
      await tester.tap(find.text('Aa'));
      await tester.pumpAndSettle();
      expect(find.text('브랜드 전용 · 개발 중'), findsOneWidget);
      await tester.tap(find.text('나눔고딕'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('종이'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('다음 종이'));
      await tester.pumpAndSettle();
      expect(store.data.style.paperIndex, 1);
      expect(store.data.style.fontIndex, 2);
      expect(store.data.style.penIndex, 0);
      await tester.tap(find.text('펜'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('펜 움직임'));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(store.data.style.penMotion, isFalse);
      await tester.tap(find.byTooltip('돌아가기'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(editor).controller, same(controller));
      expect(controller.text, '끝까지 남아야 하는 문장');
      expect(
        controller.selection,
        const TextSelection(baseOffset: 2, extentOffset: 5),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Unreadable data shows recovery screen without saving', (
    tester,
  ) async {
    final store = UnreadableStore();
    await tester.pumpWidget(WritingHumanApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('기록을 불러오지 못했습니다.'), findsOneWidget);
    expect(store.writes, 0);
  });
}

class UnreadableStore implements LibraryStore {
  int writes = 0;
  @override
  Future<Library> load() async => throw const FormatException('broken');
  @override
  Future<void> save(Library library) async {
    writes++;
  }

  @override
  Future<void> close() async {}
}
