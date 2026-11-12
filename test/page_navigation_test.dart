import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:writing_human/ui/paper_swipe.dart';
import 'package:writing_human/ui/page_turn.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/main.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/ui/pages_sheet.dart';
import 'widget_test.dart' show MemoryStore;
import 'package:writing_human/ui/writing_chrome.dart';

final field = find.byKey(const ValueKey('page-text'));
final reveal = find.byKey(const ValueKey('page-turn-reveal'));
final cover = find.byKey(const ValueKey('book-front-cover'));
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

void expectBoard(
  WidgetTester tester,
  Finder face, {
  required bool back,
  required double edgeX,
  double leftX = 0,
}) {
  final material = find.descendant(
    of: face,
    matching: find.byKey(const ValueKey('full-cover-material')),
  );
  final box = tester.renderObject<RenderBox>(material);
  final spineX = back ? box.size.width : 0.0;
  final outerX = back ? 0.0 : box.size.width;
  final spine = box.localToGlobal(Offset(spineX, box.size.height / 2));
  final edge = box.localToGlobal(Offset(outerX, box.size.height / 2));
  expect(spine.dx, closeTo(leftX + spineX, .01));
  expect(edge.dx, closeTo(edgeX, .01));
  // The free edge lifts toward the reader, so it projects taller.
  final spineTop = box.localToGlobal(Offset(spineX, 0));
  final edgeTop = box.localToGlobal(Offset(outerX, 0));
  expect(edgeTop.dy, lessThan(spineTop.dy));
}

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
    testWidgets('Held drag reveals exactly the distance moved at $size', (
      tester,
    ) async {
      final store = MemoryStore()..data = twoPages();
      await open(tester, store);
      tester.view.physicalSize = size;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
      addTearDown(tester.view.resetPadding);
      await tester.pumpAndSettle();
      final live = tester.widget<TextField>(field).controller!;
      final selection = live.selection;
      final writes = store.writes;
      final origin = tester.getCenter(field);
      final gesture = await tester.startGesture(origin);
      Rect exposed() {
        final clip = tester.widget<ClipRect>(reveal).clipper!;
        return clip.getClip(tester.getSize(reveal));
      }

      await gesture.moveBy(const Offset(-75, 0));
      await tester.pump();
      expect(exposed().width, closeTo(75, .01));
      await gesture.moveBy(const Offset(-130, 0));
      await tester.pump(const Duration(milliseconds: 500));
      expect(exposed().width, closeTo(205, .01));
      expect(exposed().height, size.height);
      expect(tester.getSize(reveal).width, size.width.clamp(0, 760));
      expect(
        find.descendant(of: reveal, matching: find.byType(WritingHeader)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: reveal, matching: find.byType(WritingFooter)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: reveal, matching: find.text('둘째 페이지')),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.widget<TextField>(field).controller, same(live));
      expect(live.selection, selection);
      expect(store.writes, writes);
      expect(store.data.activePageId, 'one');
      await gesture.moveBy(const Offset(145, 0));
      await tester.pump(const Duration(milliseconds: 300));
      expect(exposed().width, closeTo(60, .01));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(reveal, findsNothing);
      expect(store.writes, writes);
      expect(store.data.activePageId, 'one');
      expect(tester.widget<TextField>(field).controller, same(live));
      expect(live.selection, selection);
    });
  }

  testWidgets('Resizing cancels a held turn and retains the editor', (
    tester,
  ) async {
    final store = MemoryStore()..data = twoPages();
    await open(tester, store);
    final controller = tester.widget<TextField>(field).controller!;
    final gesture = await tester.startGesture(tester.getCenter(field));
    await gesture.moveBy(const Offset(-160, 0));
    await tester.pump();
    expect(reveal, findsOneWidget);
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    expect(reveal, findsNothing);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller, same(controller));
    expect(store.data.activePageId, 'one');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bottom corner exposes the neighbour from the bottom up', (
    tester,
  ) async {
    final store = MemoryStore()..data = twoPages();
    await open(tester, store);
    final paper = find.byKey(const ValueKey('paper-swipe'));
    final origin = tester.getBottomRight(paper) - const Offset(27, 105);
    final controller = tester.widget<TextField>(field).controller!;
    final initial = controller.value;
    final drag = await tester.startGesture(origin);
    await drag.moveBy(const Offset(-74, 0));
    await tester.pump();

    final corner = find.descendant(of: reveal, matching: find.byType(ClipPath));
    final clipper = tester.widget<ClipPath>(corner).clipper!;
    final size = tester.getSize(corner);
    final visible = clipper.getClip(size);
    expect(visible.contains(Offset(size.width - 35, 20)), isFalse);
    expect(visible.contains(Offset(size.width - 35, size.height - 20)), isTrue);
    expect(find.byType(TextField), findsOneWidget);

    await drag.cancel();
    await tester.pumpAndSettle();
    expect(reveal, findsNothing);
    expect(store.data.activePageId, 'one');
    expect(tester.widget<TextField>(field).controller, same(controller));
    expect(controller.value, initial);
  });

  testWidgets('Turning with motion disabled still opens the next page', (
    tester,
  ) async {
    final store = MemoryStore()
      ..data = twoPages().copy(style: const WritingStyle(pageMotion: false));
    await open(tester, store);
    final drag = await tester.startGesture(tester.getCenter(field));
    await drag.moveBy(const Offset(-160, 0));
    await tester.pump();
    expect(reveal, findsNothing);
    await drag.up();
    await tester.pumpAndSettle();
    expect(store.data.activePageId, 'two');
    expect(overlay, findsNothing);
  });

  testWidgets('The first sheet peels back to a cover without a saved page', (
    tester,
  ) async {
    final store = MemoryStore()..data = twoPages();
    await open(tester, store);
    final writes = store.writes;
    final live = tester.widget<TextField>(field).controller!;
    final gesture = await tester.startGesture(tester.getCenter(field));
    await gesture.moveBy(const Offset(165, 0));
    await tester.pump();
    expect(find.descendant(of: reveal, matching: cover), findsOneWidget);
    expectBoard(tester, cover, back: false, edgeX: 165);
    expect(store.writes, writes);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(reveal, findsNothing);
    expect(cover, findsOneWidget);
    expect(field, findsNothing);
    expect(store.data.activePageId, 'one');
    expect(store.data.pages.length, 2);
    expect(store.writes, writes);
    final reopen = await tester.startGesture(tester.getCenter(cover));
    await reopen.moveBy(const Offset(-170, 0));
    await tester.pump();
    expect(find.byKey(const ValueKey('page-preview-text:one')), findsOneWidget);
    expectBoard(tester, cover, back: false, edgeX: 220);
    await reopen.up();
    await tester.pumpAndSettle();
    expect(cover, findsNothing);
    expect(tester.widget<TextField>(field).controller, same(live));
    expect(live.selection, const TextSelection(baseOffset: 2, extentOffset: 6));
    expect(tester.widget<TextField>(field).scrollController!.offset, 180);
    expect(store.writes, writes);
  });

  testWidgets('Book turns traverse its records and keep each record intact', (
    tester,
  ) async {
    final store = MemoryStore()
      ..data = Library(
        books: const [Book(id: 'book', title: '한 권의 책', author: '지은이')],
        records: const [
          WritingRecord(id: 'a', title: '앞 기록', bookId: 'book'),
          WritingRecord(id: 'b', title: '뒤 기록', bookId: 'book'),
          WritingRecord(id: 'loose', title: '따로 둔 기록'),
        ],
        pages: const [
          WritingPage(id: 'b1', recordId: 'b', number: 1, text: '뒤의 글'),
          WritingPage(id: 'a1', recordId: 'a', number: 1, text: '앞의 글'),
          WritingPage(id: 'loose1', recordId: 'loose', number: 1, text: '다른 글'),
        ],
        activePageId: 'b1',
        writing: true,
      );
    await open(tester, store);
    expect(find.text('2'), findsOneWidget);
    await previousSheet(tester);
    await tester.pumpAndSettle();
    expect(store.data.activePageId, 'a1');
    await previousSheet(tester);
    await tester.pumpAndSettle();
    expect(find.text('지은이'), findsOneWidget);
    await tester.tap(find.text('책 펼치기'));
    await tester.pumpAndSettle();
    expect(store.data.activePageId, 'a1');
    await nextSheet(tester);
    await tester.pumpAndSettle();
    expect(store.data.activePageId, 'b1');
    expect(store.data.pages.map((p) => p.number), everyElement(1));
    expect(store.data.records.length, 3);
  });

  testWidgets(
    'The back cover closes on its spine and reopens the same editor',
    (tester) async {
      final store = MemoryStore()..data = twoPages().copy(activePageId: 'two');
      await open(tester, store);
      final back = find.byKey(const ValueKey('book-back-cover'));
      final live = tester.widget<TextField>(field).controller!;
      final value = live.value;
      final writes = store.writes;
      final held = await tester.startGesture(tester.getCenter(field));
      await held.moveBy(const Offset(-100, 0));
      await tester.pump();
      expect(find.descendant(of: reveal, matching: back), findsOneWidget);
      expectBoard(tester, back, back: true, edgeX: 290);
      final hinge = tester.widget<CoverHinge>(
        find.byWidgetPredicate((w) => w is CoverHinge && w.enabled),
      );
      expect(find.text('마지막 장 펼치기'), findsNothing);
      expect(hinge.incoming, isTrue);
      expect(hinge.forward, isTrue);
      expect(find.byKey(const ValueKey('page-turn-fold')), findsNothing);
      expect(live.value, value);
      await held.cancel();
      await tester.pumpAndSettle();
      expect(back, findsNothing);
      expect(store.writes, writes);
      expect(tester.widget<TextField>(field).controller, same(live));

      await nextSheet(tester);
      await tester.pumpAndSettle();
      expect(back, findsOneWidget);
      expect(store.data.activePageId, 'two');
      expect(store.data.pages.length, 2);
      expect(store.writes, writes);
      await tester.fling(back, const Offset(-140, 0), 800);
      await tester.pumpAndSettle();
      expect(back, findsOneWidget);
      final opening = await tester.startGesture(tester.getCenter(back));
      await opening.moveBy(const Offset(100, 0));
      await tester.pump();
      expectBoard(tester, back, back: true, edgeX: 100);
      await opening.cancel();
      await tester.pumpAndSettle();
      await tester.tap(find.text('마지막 장 펼치기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byWidgetPredicate(
          (w) => w is CoverHinge && w.enabled && !w.incoming,
        ),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      expect(back, findsNothing);
      expect(tester.widget<TextField>(field).controller, same(live));
      expect(live.value, value);
      expect(store.writes, writes);
    },
  );

  testWidgets(
    'A front cover button turns the board with reduced motion support',
    (tester) async {
      final store = MemoryStore()..data = twoPages();
      await open(tester, store);
      await previousSheet(tester);
      await tester.pumpAndSettle();
      expect(cover, findsOneWidget);
      await tester.tap(find.text('책 펼치기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byWidgetPredicate(
          (w) => w is CoverHinge && w.enabled && !w.incoming,
        ),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      expect(store.data.activePageId, 'one');
      expect(store.data.pages.length, 2);

      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: true);
      await tester.pumpAndSettle();
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('뒷표지'));
      await tester.tap(find.text('뒷표지'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('book-back-cover')), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is CoverHinge && w.enabled),
        findsNothing,
      );
      await tester.tap(find.text('한 쪽 더'));
      await tester.pumpAndSettle();
      expect(store.data.pages.length, 3);
      expect(store.data.activePage!.text, isEmpty);
      expect(field, findsOneWidget);
    },
  );

  testWidgets(
    'The rear cover closes over the centered editor on wide screens',
    (tester) async {
      final store = MemoryStore()..data = twoPages();
      await open(tester, store);
      const viewport = Size(1440, 900);
      tester.view.physicalSize = viewport;
      tester.view.padding = const FakeViewPadding(top: 28, bottom: 24);
      addTearDown(tester.view.resetPadding);
      await tester.pumpAndSettle();
      final surface = find.byKey(const ValueKey('paper-swipe'));
      final material = find.byKey(const ValueKey('full-cover-material'));
      final editor = tester.widget<TextField>(field).controller;
      expect(tester.getSize(surface).width, 760);

      await previousSheet(tester);
      await tester.pumpAndSettle();
      expect(tester.getRect(material), Offset.zero & viewport);
      expect(tester.getTopLeft(find.text('보관함')).dy, greaterThan(28));
      await tester.tap(find.text('책 펼치기'));
      await tester.pumpAndSettle();
      expect(tester.getSize(surface).width, 760);
      expect(tester.widget<TextField>(field).controller, same(editor));

      await nextSheet(tester);
      await tester.pumpAndSettle();
      final back = find.byKey(const ValueKey('book-back-cover'));
      final closing = await tester.startGesture(tester.getCenter(field));
      await closing.moveBy(const Offset(-130, 0));
      await tester.pump();
      final closedRect = Rect.fromLTWH(
        (viewport.width - 760) / 2,
        0,
        760,
        viewport.height,
      );
      expectBoard(
        tester,
        back,
        back: true,
        edgeX: closedRect.right - 130,
        leftX: closedRect.left,
      );
      await closing.cancel();
      await tester.pumpAndSettle();
      await nextSheet(tester);
      await tester.pumpAndSettle();
      expect(back, findsOneWidget);
      expect(tester.getRect(material), closedRect);
      expect(store.data.pages.length, 2);
    },
  );

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
      expect(cover, findsOneWidget);
      await tester.fling(cover, const Offset(140, 0), 800);
      await tester.pumpAndSettle();
      expect(cover, findsOneWidget);
      await tester.tap(find.text('책 펼치기'));
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
      expect(find.byKey(const ValueKey('book-back-cover')), findsOneWidget);
      expect(store.data.pages.length, 2);
      await tester.tap(find.text('한 쪽 더'));
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
      await tester.pumpAndSettle();
      expect(overlay, findsNothing);
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
    await tester.pumpAndSettle();
    expect(overlay, findsNothing);
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
    expect(find.text('표지'), findsOneWidget);
    expect(find.text('1쪽'), findsOneWidget);
    expect(find.text('2쪽 · 현재'), findsOneWidget);
    await tester.tap(find.text('1쪽'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(store.data.activePageId, 'two');
    await tester.pumpAndSettle();
    expect(store.data.activePageId, 'one');
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('한 쪽 더'),
      160,
      scrollable: find.descendant(
        of: find.byType(PagesSheet),
        matching: find.byType(Scrollable),
      ),
    );
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
