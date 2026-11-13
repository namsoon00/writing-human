import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/entry_location.dart';
import 'package:writing_human/main.dart';
import 'package:writing_human/ui/book_detail_tools.dart';
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
    'Existing writing opens with real details and immediate settings, without a demo screen',
    (tester) async {
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
      await tester.ensureVisible(find.text('책의 디테일'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('책의 디테일'));
      await tester.pumpAndSettle();
      expect(find.byType(BookDetailTools), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('detail-ribbon-variant-1')));
      await tester.pumpAndSettle();
      expect(store.data.style.bookDetails.ribbon.variant, 1);
      expect(store.data.activePage!.text, specimen().activePage!.text);
      expect(find.textContaining('예시'), findsNothing);
    },
  );
}
