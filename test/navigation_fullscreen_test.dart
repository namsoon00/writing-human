import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/main.dart';
import 'package:writing_human/ui/paper_panel.dart';

import 'navigation_flow_test.dart' show fixture;
import 'widget_test.dart' show MemoryStore;

void main() {
  final platforms = TargetPlatformVariant({
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.linux,
  });

  testWidgets('New routes inherit edge back and keep the same Navigator', (
    tester,
  ) async {
    final navigation = PaperNavigation();
    final navigatorKey = GlobalKey<NavigatorState>();
    addTearDown(navigation.dispose);
    var blocked = true;
    var denied = 0;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [navigation],
        builder: (_, child) =>
            PaperBackGesture(navigation: navigation, child: child!),
        home: const Scaffold(body: Text('쓰는 종이')),
      ),
    );
    final navigator = navigatorKey.currentState;
    expect(find.byKey(const ValueKey('paper-back-edge')), findsNothing);
    // A future screen need not opt into a special route or gesture wrapper.
    navigator!.push<void>(
      MaterialPageRoute(
        builder: (_) => StatefulBuilder(
          builder: (_, update) => PopScope(
            canPop: !blocked,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) denied++;
            },
            child: Scaffold(
              body: TextButton(
                onPressed: () => update(() => blocked = false),
                child: const Text('다시 저장'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(navigatorKey.currentState, same(navigator));
    await tester.dragFrom(const Offset(5, 260), const Offset(240, 0));
    await tester.pumpAndSettle();
    expect(denied, 1);
    expect(find.text('다시 저장'), findsOneWidget);
    await tester.tap(find.text('다시 저장'));
    await tester.pumpAndSettle();
    // Content drags, opposite drags and cancelled short drags keep the page.
    await tester.dragFrom(const Offset(160, 260), const Offset(200, 0));
    await tester.dragFrom(const Offset(5, 260), const Offset(-100, 0));
    await tester.timedDragFrom(
      const Offset(5, 260),
      const Offset(35, 0),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(find.text('다시 저장'), findsOneWidget);
    await tester.dragFrom(const Offset(5, 260), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.text('다시 저장'), findsNothing);
    expect(find.text('쓰는 종이'), findsOneWidget);
    expect(navigatorKey.currentState, same(navigator));
    expect(tester.takeException(), isNull);
  }, variant: platforms);

  for (final width in [390.0, 320.0]) {
    testWidgets('Titles stay centered at width $width with large text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = MemoryStore()..data = fixture;
      await tester.pumpWidget(WritingHumanApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-bookshelf')));
      await tester.pumpAndSettle();
      Finder title(String text) => find.descendant(
        of: find.byType(PaperPanelTitle),
        matching: find.text(text),
      );
      expect(tester.getCenter(title('책장')).dx, closeTo(width / 2, .5));
      expect(
        find.descendant(
          of: find.byType(PaperBackButton),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      await tester.tap(find.widgetWithText(TextButton, '내 글'));
      await tester.pumpAndSettle();
      expect(tester.getCenter(title('내 글')).dx, closeTo(width / 2, .5));
      await tester.tap(find.byKey(const ValueKey('paper-back')).hitTestable());
      await tester.pumpAndSettle();
      final before = store.data.activePage!.toJson();
      await tester.tap(find.text('쓰기 도구'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('paper-panel-page'))),
        Rect.fromLTWH(0, 0, width, 844),
      );
      expect(find.byKey(const ValueKey('paper-sheet-handle')), findsNothing);
      expect(tester.getCenter(title('쓰기 도구')).dx, closeTo(width / 2, .5));
      await tester.dragFrom(const Offset(5, 260), const Offset(240, 0));
      await tester.pumpAndSettle();
      expect(store.data.activePage!.toJson(), before);
      expect(find.byKey(const ValueKey('page-text')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
