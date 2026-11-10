import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:writing_human/ui/paper_swipe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/main.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/ui/pages_sheet.dart';
import 'widget_test.dart' show MemoryStore;
import 'package:writing_human/ui/page_turn.dart';
import 'package:writing_human/ui/writing_chrome.dart';

final field = find.byKey(const ValueKey('page-text'));
final overlay = find.byKey(const ValueKey('page-turn-overlay'));

Library twoPages() => Library(
  records: const [WritingRecord(id: 'r', title: '두 쪽 필사')],
  pages: [
    WritingPage(
      id: 'one',
      recordId: 'r',
      number: 1,
      text: List.filled(40, '첫 페이지에 남긴 문장').join('\n'),
      base: 2,
      extent: 6,
      scroll: 180,
    ),
    const WritingPage(id: 'two', recordId: 'r', number: 2, text: '둘째 페이지'),
  ],
  activePageId: 'one',
  writing: true,
);

Future<void> open(WidgetTester tester, MemoryStore store) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(WritingHumanApp(store: store));
  await tester.pumpAndSettle();
}

Future<void> nextSheet(WidgetTester tester) => tester.fling(
  find.byKey(const ValueKey('page-number')),
  const Offset(-140, 0),
  800,
);
Future<void> previousSheet(WidgetTester tester) => tester.fling(
  find.byKey(const ValueKey('page-number')),
  const Offset(140, 0),
  800,
);

void main() {
  testWidgets(
    'Mouse selection stays native while the page number accepts mouse swipes',
    (tester) async {
      final store = MemoryStore()..data = twoPages();
      await open(tester, store);
      final original = store.data.pages.first.text;
      final controller = tester.widget<TextField>(field).controller!;
      await tester.drag(
        field,
        const Offset(-140, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(store.data.activePageId, 'one');
      expect(tester.widget<TextField>(field).controller, same(controller));
      expect(controller.text, original);
      await tester.drag(
        find.byKey(const ValueKey('page-number')),
        const Offset(-140, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(store.data.activePageId, 'two');
    },
  );

  testWidgets('A native long press selects text instead of turning the paper', (
    tester,
  ) async {
    final store = MemoryStore()..data = twoPages();
    await open(tester, store);
    final controller = tester.widget<TextField>(field).controller!;
    final original = controller.text;
    await tester.longPressAt(tester.getTopLeft(field) + const Offset(90, 80));
    await tester.pumpAndSettle();
    expect(store.data.activePageId, 'one');
    expect(tester.widget<TextField>(field).controller, same(controller));
    expect(controller.text, original);
    expect(controller.selection.isCollapsed, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(390, 844), const Size(1440, 1000)]) {
    testWidgets('Turn includes header and footer at $size', (tester) async {
      final store = MemoryStore()..data = twoPages();
      await open(tester, store);
      tester.view.physicalSize = size;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
      addTearDown(tester.view.resetPadding);
      await tester.pumpAndSettle();
      await nextSheet(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      final rect = tester.getRect(overlay);
      expect(rect, tester.getRect(find.byType(PageTurnView)));
      expect(rect.top, 0);
      expect(rect.bottom, size.height);
      expect(
        rect.contains(tester.getCenter(find.byType(WritingHeader))),
        isTrue,
      );
      expect(
        rect.contains(tester.getCenter(find.byType(WritingFooter))),
        isTrue,
      );
      final image = tester
          .widget<RawImage>(
            find.descendant(of: overlay, matching: find.byType(RawImage)),
          )
          .image!;
      expect(
        image.width,
        inInclusiveRange(rect.width.ceil(), (rect.width * 2).ceil()),
      );
      expect(
        image.height,
        inInclusiveRange(rect.height.ceil(), (rect.height * 2).ceil()),
      );
      expect(image.width * image.height, lessThan(2004000));
      expect(find.byType(TextField), findsOneWidget);
      // A quick reverse turn replaces the disposable image, not the editor tree.
      await previousSheet(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(overlay, findsOneWidget);
      expect(store.data.activePageId, 'one');
      await tester.pumpAndSettle();
      expect(overlay, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Resizing ends the turn without stretching the old screen', (
    tester,
  ) async {
    final store = MemoryStore()..data = twoPages();
    await open(tester, store);
    await nextSheet(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(overlay, findsOneWidget);
    final controller = tester.widget<TextField>(field).controller!;
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    expect(overlay, findsNothing);
    expect(tester.widget<TextField>(field).controller, same(controller));
    expect(controller.text, '둘째 페이지');
    expect(store.data.activePageId, 'two');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Paper swipes turn pages; editing gestures stay in the text', (
    tester,
  ) async {
    final store = MemoryStore()..data = twoPages();
    await open(tester, store);
    final original = store.data.pages.first.text;
    expect(find.byTooltip('페이지 추가'), findsNothing);
    expect(find.byTooltip('이전 페이지'), findsNothing);
    expect(find.byTooltip('다음 페이지'), findsNothing);
    expect(
      tester.getSize(find.byType(WritingFooter)).height,
      inInclusiveRange(64, 80),
    );
    await tester.fling(field, const Offset(-140, 0), 800);
    await tester.pumpAndSettle();
    expect(store.data.activePageId, 'two');
    await tester.fling(field, const Offset(140, 0), 800);
    await tester.pumpAndSettle();
    expect(store.data.activePageId, 'one');
    await tester.tap(field);
    await tester.pumpAndSettle();
    final controller = tester.widget<TextField>(field).controller!;
    await tester.fling(field, const Offset(-140, 0), 800);
    await tester.pumpAndSettle();
    expect(store.data.activePageId, 'one');
    expect(tester.widget<TextField>(field).controller, same(controller));
    expect(controller.text, original);
    await nextSheet(tester);
    await tester.pumpAndSettle();
    expect(store.data.activePageId, 'two');
    expect(store.data.pages.length, 2);
  });

  testWidgets(
    'Vertical scroll, small movements and the first edge do not add pages',
    (tester) async {
      final store = MemoryStore()..data = twoPages();
      await open(tester, store);
      await previousSheet(tester);
      await tester.pumpAndSettle();
      await tester.drag(field, const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(store.data.activePageId, 'one');
      expect(store.data.pages.length, 2);
      expect(
        tester.widget<TextField>(field).scrollController!.offset,
        greaterThan(180),
      );
      await tester.drag(
        find.byKey(const ValueKey('page-number')),
        const Offset(-32, 0),
      );
      await tester.pumpAndSettle();
      expect(store.data.activePageId, 'one');
      await tester.timedDrag(
        find.byKey(const ValueKey('page-number')),
        const Offset(-130, 0),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(store.data.activePageId, 'two');
      await tester.timedDrag(
        field,
        const Offset(-130, 0),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(store.data.pages.length, 3);
      expect(store.data.activePage!.text, isEmpty);
    },
  );
  testWidgets(
    'Explicit blank-page addition turns to a saved second page with one editor',
    (tester) async {
      final store = MemoryStore();
      await open(tester, store);
      expect(store.writes, 0);
      expect(find.text('1'), findsOneWidget);
      await nextSheet(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(overlay, findsOneWidget);
      expect(find.byKey(const ValueKey('page-text')), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(store.data.pages.length, 2);
      expect(store.data.records.length, 1);
      expect(store.data.pages.every((p) => p.text.isEmpty), isTrue);
      await tester.tap(field);
      await tester.pumpAndSettle();
      expect(overlay, findsNothing);
      await tester.enterText(field, '새 페이지에 바로 입력');
      await tester.pumpAndSettle();
      expect(store.data.pages.first.text, '');
      expect(store.data.activePage!.text, '새 페이지에 바로 입력');
      final id = store.data.activePageId;
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      expect(store.data.activePageId, id);
      expect(find.text('2'), findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, '새 페이지에 바로 입력');
    },
  );

  testWidgets('Previous and next restore each page selection and scroll', (
    tester,
  ) async {
    final store = MemoryStore()..data = twoPages();
    final firstText = store.data.pages.first.text;
    await open(tester, store);
    await nextSheet(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(overlay, findsOneWidget);
    expect(tester.widget<TextField>(field).controller!.text, '둘째 페이지');
    await tester.enterText(field, '둘째 페이지 수정 🌿');
    await tester.pumpAndSettle();
    expect(overlay, findsNothing);
    await previousSheet(tester);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, firstText);
    expect(
      tester.widget<TextField>(field).controller!.selection,
      const TextSelection(baseOffset: 2, extentOffset: 6),
    );
    expect(tester.widget<TextField>(field).scrollController!.offset, 180);
    expect(store.data.pages.last.text, '둘째 페이지 수정 🌿');
    expect(find.text('1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Overview shows paper previews and switches only after closing', (
    tester,
  ) async {
    final store = MemoryStore()..data = twoPages().copy(activePageId: 'two');
    await open(tester, store);
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    expect(find.byType(PagesSheet), findsOneWidget);
    expect(find.text('1쪽'), findsOneWidget);
    expect(find.text('2쪽 · 현재'), findsOneWidget);
    await tester.tap(find.text('1쪽'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(store.data.activePageId, 'two');
    await tester.pumpAndSettle();
    expect(store.data.activePageId, 'one');
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('한 쪽 더'));
    await tester.pumpAndSettle();
    expect(store.data.pages.length, 3);
    expect(find.text('3'), findsOneWidget);
    expect(tester.widget<TextField>(field).controller!.text, isEmpty);
  });

  testWidgets(
    'Composing input disables page actions without changing its value',
    (tester) async {
      final store = MemoryStore()..data = twoPages();
      await open(tester, store);
      await tester.tap(field);
      await tester.pumpAndSettle();
      const value = TextEditingValue(
        text: '조합 중인 하ㄴ',
        selection: TextSelection.collapsed(offset: 8),
        composing: TextRange(start: 6, end: 8),
      );
      tester.testTextInput.updateEditingValue(value);
      await tester.pumpAndSettle();
      final controller = tester.widget<TextField>(field).controller!;
      expect(
        tester
            .widget<PaperSwipe>(find.byKey(const ValueKey('page-number-swipe')))
            .onNext,
        isNull,
      );
      await nextSheet(tester);
      await tester.pumpAndSettle();
      expect(controller.value, value);
      expect(store.data.activePageId, 'one');
      tester.testTextInput.updateEditingValue(
        value.copyWith(composing: TextRange.empty),
      );
      await tester.pumpAndSettle();
      await nextSheet(tester);
      await tester.pumpAndSettle();
      expect(store.data.activePageId, 'two');
      expect(store.data.pages.first.text, value.text);
    },
  );

  testWidgets(
    'Reduced motion changes the page immediately without an overlay',
    (tester) async {
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: true);
      final store = MemoryStore()..data = twoPages();
      await open(tester, store);
      await nextSheet(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(overlay, findsNothing);
      expect(find.text('2'), findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, '둘째 페이지');
      await tester.pumpAndSettle();
    },
  );

  testWidgets('A save failure retains the current page until retry succeeds', (
    tester,
  ) async {
    final store = MemoryStore()..data = twoPages();
    await open(tester, store);
    store.fail = true;
    await tester.enterText(field, '아직 디스크에 쓰지 못한 문장');
    await tester.pumpAndSettle();
    expect(find.text('저장 실패'), findsOneWidget);
    await nextSheet(tester);
    await tester.pumpAndSettle();
    expect(store.data.activePageId, 'one');
    expect(
      tester.widget<TextField>(field).controller!.text,
      '아직 디스크에 쓰지 못한 문장',
    );
    expect(overlay, findsNothing);
    store.fail = false;
    await tester.tap(find.text('저장 재시도'));
    await tester.pumpAndSettle();
    await nextSheet(tester);
    await tester.pumpAndSettle();
    expect(store.data.activePageId, 'two');
    expect(store.data.pages.first.text, '아직 디스크에 쓰지 못한 문장');
  });
}
