import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/entry_location.dart';
import 'package:writing_human/main.dart';
import 'package:writing_human/ui/book_appearance.dart';
import 'package:writing_human/ui/book_details.dart';
import 'book_details_test.dart' show specimen;
import 'widget_test.dart' show MemoryStore;

void main() {
  test(
    'Legacy demo links become normal URLs without changing the record origin',
    () {
      for (final mode in ['reference', 'typeface']) {
        final old = Uri.parse(
          'https://namsoon00.github.io/writing-human/?demo=$mode',
        );
        final next = normalEntryLocation(old);
        expect(next.toString(), 'https://namsoon00.github.io/writing-human/');
        expect(next.origin, old.origin);
      }
      final old = Uri.parse(
        'https://namsoon00.github.io/writing-human/?tag=1&demo=reference&tag=2&paper=warm#page-2',
      );
      final next = normalEntryLocation(old);
      expect(next.queryParametersAll, {
        'tag': ['1', '2'],
        'paper': ['warm'],
      });
      expect(next.fragment, 'page-2');
      expect(next.path, old.path);
      expect(next.origin, old.origin);
      final normal = Uri.parse(
        'https://namsoon00.github.io/writing-human/?paper=warm',
      );
      expect(normalEntryLocation(normal), same(normal));
      expect(
        normalEntryLocation(
          Uri.parse('https://example.test/a%3Fb?demo=reference#note?tab'),
        ).toString(),
        'https://example.test/a%3Fb#note?tab',
      );
    },
  );

  testWidgets(
    'An empty collection offers actual writing and never creates example records',
    (tester) async {
      final store = MemoryStore();
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      expect(store.writes, 0);
      await tester.tap(find.text('책장'));
      await tester.pumpAndSettle();
      expect(find.textContaining('예시'), findsNothing);
      expect(find.text('새 종이'), findsOneWidget);
      expect(store.writes, 0);
      expect(store.data.records, isEmpty);
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('page-text')),
        '내가 쓰는 실제 기록',
      );
      await tester.pumpAndSettle();
      expect(store.data.pages.single.text, '내가 쓰는 실제 기록');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('page-text')))
            .controller!
            .text,
        '내가 쓰는 실제 기록',
      );
      expect(find.textContaining('예시'), findsNothing);
    },
  );

  testWidgets(
    'Existing writing opens with real details and a live customization preview, without a demo screen',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryStore()..data = specimen();
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      expect(find.textContaining('예시'), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('page-text')))
            .controller!
            .text,
        specimen().activePage!.text,
      );
      await tester.tap(find.byTooltip('쓰기 도구'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('책 꾸미기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('책 꾸미기'));
      await tester.pumpAndSettle();
      expect(find.byType(BookAppearance), findsOneWidget);
      final preview = find.byKey(const ValueKey('book-preview-ribbon'));
      final shape = find.byKey(const ValueKey('detail-ribbon-variant-1'));
      await tester.ensureVisible(shape);
      await tester.pumpAndSettle();
      await tester.tap(shape);
      await tester.pumpAndSettle();
      expect(tester.widget<RibbonBookmark>(preview).choice.variant, 1);
      expect(store.data.books.single.detailOverrides, isEmpty);
      await tester.tap(find.byTooltip('뒤로'));
      await tester.pumpAndSettle();
      expect(store.data.books.single.detailOverrides, isEmpty);

      await tester.tap(find.text('책 꾸미기'));
      await tester.pumpAndSettle();
      expect(tester.widget<RibbonBookmark>(preview).choice.variant, 0);
      await tester.ensureVisible(shape);
      await tester.pumpAndSettle();
      await tester.tap(shape);
      await tester.pumpAndSettle();
      store.fail = true;
      await tester.tap(find.text('완료'));
      await tester.pumpAndSettle();
      expect(find.text('책 꾸밈을 저장하지 못했어요.'), findsOneWidget);
      expect(tester.widget<RibbonBookmark>(preview).choice.variant, 1);
      expect(store.data.books.single.detailOverrides, isEmpty);
      store.fail = false;
      await tester.tap(find.text('다시 저장'));
      await tester.pumpAndSettle();
      expect(find.byType(BookAppearance), findsNothing);
      expect(
        store.data.books.single.detailOverrides[BookDetailKind.ribbon]?.variant,
        1,
      );
      expect(store.data.style.bookDetails.ribbon.variant, 0);
      expect(store.data.activePage!.text, specimen().activePage!.text);
      expect(find.textContaining('예시'), findsNothing);
    },
  );
}
