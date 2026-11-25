import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/main.dart';
import 'package:writing_human/ui/paper_panel.dart';
import 'package:writing_human/ui/source_reading.dart';
import 'navigation_flow_test.dart' show fixture;
import 'widget_test.dart' show MemoryStore;

void main() {
  testWidgets(
    'iOS edge back follows a local source/list step before leaving the route',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryStore()..data = fixture;
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('writing-originals')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('원문 목록'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('종이 위에 문장을 씁니다.'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('paper-internal-back-edge')),
        findsOneWidget,
      );
      await tester.dragFrom(const Offset(5, 300), const Offset(200, 0));
      await tester.pumpAndSettle();
      expect(find.byType(SourceReading), findsOneWidget);
      expect(find.byKey(const ValueKey('source-reading-text')), findsNothing);
      expect(store.data.activePageId, 'pa');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'iOS native edge gesture pops a full page and keeps the underlying screen',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  paperPanelRoute(
                    (_) => const PaperPanel(
                      child: Column(
                        children: [PaperPanelHeader('원문'), Text('읽는 내용')],
                      ),
                    ),
                  ),
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(1, 300), const Offset(320, 0));
      await tester.pumpAndSettle();
      expect(find.text('읽는 내용'), findsNothing);
      expect(find.text('열기'), findsOneWidget);
    },
  );

  testWidgets('Sheet drag and barrier cannot bypass a failed-save guard', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                paperSheetRoute(
                  (_) => const PopScope(
                    canPop: false,
                    child: PaperPanel(child: Text('저장 실패 · 다시 저장')),
                  ),
                ),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('paper-sheet-handle')),
      const Offset(0, 170),
    );
    await tester.pumpAndSettle();
    expect(find.text('저장 실패 · 다시 저장'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('저장 실패 · 다시 저장'), findsOneWidget);
  });
}
