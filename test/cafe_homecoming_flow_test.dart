import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/data/demo_store.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/main.dart';
import 'package:writing_human/ui/cafe_screen.dart';

class _FailLibrary extends DemoStore {
  bool reject = false;
  @override
  Future<void> save(Library value) async {
    if (reject) {
      throw StateError('injected library save');
    }
    await super.save(value);
  }
}

void main() {
  Future<void> guide(WidgetTester tester, String page) async {
    await tester.tap(find.byTooltip('공간 안내'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('cafe-ritual-$page')));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a selected editorial sentence is atomically attached to a new writing while the old text is preserved',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final store = DemoStore();
      final old = WritingPage(
        id: 'old-page',
        recordId: 'old-record',
        number: 1,
        text: '원래 쓰던 글은 남는다.',
      );
      final library = Library(
        books: const [Book(id: 'existing-book', title: '나의 책')],
        records: const [
          WritingRecord(
            id: 'old-record',
            bookId: 'existing-book',
            title: '기존 글',
          ),
        ],
        pages: [old],
        activePageId: old.id,
        writing: true,
      );
      await store.save(library);
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-bookshelf')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-cafe')));
      await tester.pumpAndSettle();
      await guide(tester, 'today');
      final chosen = tester
          .widget<Text>(find.byKey(const ValueKey('cafe-daily-sentence')))
          .data!;
      await tester.tap(find.byKey(const ValueKey('cafe-transcribe-sentence')));
      await tester.pumpAndSettle();
      expect(find.byType(CafeScreen), findsNothing);
      final saved = await store.load();
      expect(saved.pages.firstWhere((p) => p.id == old.id).text, old.text);
      expect(saved.records.length, 2);
      expect(saved.activeRecord!.bookId, 'existing-book');
      expect(saved.books.single.originals.single.text, chosen);
      final active = saved.pages.firstWhere((p) => p.id == saved.activePageId);
      expect(active.passages.first.source, chosen);
      expect(active.text, isEmpty);
      await close(tester);
    },
  );
  testWidgets(
    'an editorial save failure retries the same candidate without replacing existing writing',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final store = _FailLibrary();
      final old = WritingPage(
        id: 'old-page',
        recordId: 'old-record',
        number: 1,
        text: '내가 쓴 글은 지킨다.',
      );
      await store.save(
        Library(
          records: const [WritingRecord(id: 'old-record', title: '기존 글')],
          pages: [old],
          activePageId: old.id,
          writing: true,
        ),
      );
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-bookshelf')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-cafe')));
      await tester.pumpAndSettle();
      await guide(tester, 'today');
      store.reject = true;
      await tester.tap(find.byKey(const ValueKey('cafe-transcribe-sentence')));
      await tester.pumpAndSettle();
      expect(find.byType(CafeScreen), findsOneWidget);
      expect((await store.load()).records.length, 1);
      store.reject = false;
      await tester.tap(
        find
            .descendant(
              of: find.byType(CafeScreen),
              matching: find.widgetWithText(TextButton, '다시 저장'),
            )
            .last,
      );
      await tester.pumpAndSettle();
      expect(find.byType(CafeScreen), findsNothing);
      final saved = await store.load();
      expect(saved.records.length, 2);
      expect(saved.pages.firstWhere((p) => p.id == old.id).text, old.text);
      expect(saved.activePage!.passages.first.source, isNotEmpty);
      await close(tester);
    },
  );
}
