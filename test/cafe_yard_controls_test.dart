import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_space.dart';
import 'package:writing_human/ui/cafe_scene.dart';
import 'package:writing_human/ui/cafe_screen.dart';

void main() {
  testWidgets(
    'Yard guide supports barefoot rest and return without creating writing or replaying sound',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final store = MemoryCafeSpaceStore();
      var writes = 0;
      final sounds = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: CafeScreen(
            books: const [],
            currentWritingLabel: '지금 펼친 쪽',
            spaceStore: store,
            onWrite: (_, _) async {
              writes++;
              return true;
            },
            onLeave: () {},
            onRetry: () {},
            playCalmSound: (s) async {
              sounds.add(s);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final c = tester.widget<CafeScene>(find.byType(CafeScene)).controller;
      final saved = store.value.encode();
      Future<void> guide(String name) async {
        await tester.tap(find.byTooltip('공간 안내'));
        await tester.pumpAndSettle();
        final choice = find.byKey(ValueKey('cafe-guide-$name'));
        await tester.ensureVisible(choice);
        await tester.pumpAndSettle();
        await tester.tap(choice);
        await tester.pumpAndSettle();
      }

      await guide('courtyard');
      expect(c.inCourtyard, isTrue);
      await guide('barefoot');
      expect(
        c.barefoot,
        isFalse,
        reason: 'First approach does not silently change footwear',
      );
      await guide('barefoot');
      expect(c.barefoot, isTrue);
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await tester.pump();
      expect(c.startStroll(), isTrue);
      await tester.pump();
      final stop = find.byKey(const ValueKey('cafe-stroll-stop'));
      expect(stop, findsOneWidget);
      await tester.tap(stop);
      await tester.pump();
      expect(c.strolling, isFalse);
      expect(c.travelling, isFalse);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      await tester.pumpAndSettle();
      await guide('meditation');
      expect(c.meditating, isTrue);
      expect(c.avatar.meditation, 1);
      expect(find.text('명상 자리 · 편하게 숨을 쉬어요.'), findsOneWidget);
      await guide('trailRest');
      expect(c.resting, isTrue);
      expect(c.meditating, isFalse);
      await guide('cafeReturn');
      expect(c.inCourtyard, isFalse);
      expect(c.barefoot, isFalse);
      expect(writes, 0);
      expect(sounds, isEmpty);
      expect(store.value.encode(), saved);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
