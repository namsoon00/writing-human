import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_renderer.dart';
import 'package:writing_human/cafe/cafe_view_controller.dart';
import 'package:writing_human/cafe/cafe_visit.dart';
import 'package:writing_human/ui/cafe_scene.dart';
import 'package:writing_human/ui/cafe_screen.dart';

void arrive(CafeViewController c) {
  c.updateCamera(c.destination!);
  c.finishTravel();
}

void main() {
  testWidgets(
    'Fish motion is visible from the window and pauses with reduced motion',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CafeScreen(
            books: const [],
            currentWritingLabel: '지금 펼친 쪽',
            initialSeat: CafeSeat.window,
            onWrite: (s, b) async => true,
            onLeave: () {},
            onRetry: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      final c = tester.widget<CafeScene>(find.byType(CafeScene)).controller;
      expect(c.inCourtyard, isFalse);
      expect(c.effectTime, greaterThan(0));
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();
      final paused = c.effectTime;
      await tester.pump(const Duration(seconds: 1));
      expect(c.effectTime, paused);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  test(
    'Courtyard travel, resting and return never cross the pond or retain a pending portal',
    () {
      final c = CafeViewController();
      addTearDown(c.dispose);
      expect(c.visit(CafeTarget.courtyard), isTrue);
      c.look(.1, 0);
      expect(c.inCourtyard, isFalse);
      expect(c.arrival, isNull);
      expect(c.visit(CafeTarget.courtyard), isTrue);
      arrive(c);
      expect(c.inCourtyard, isTrue);
      expect(c.world.canStand(const CafePoint(-1.2, 1.62, 1.0)), isFalse);
      expect(c.walkTo(const CafePoint(-1.2, 0, 1.0)), isFalse);
      expect(c.visit(CafeTarget.bench), isTrue);
      arrive(c);
      expect(c.resting, isTrue);
      expect(c.seat, isNull);
      expect(c.visit(CafeTarget.cafeReturn), isTrue);
      arrive(c);
      expect(c.inCourtyard, isFalse);
      expect(c.resting, isFalse);
      final again = CafeViewController(seat: CafeSeat.garden);
      addTearDown(again.dispose);
      expect(again.inCourtyard, isTrue);
      again.stand();
      arrive(again);
      expect(again.world.canStand(again.camera.position), isTrue);
    },
  );

  testWidgets(
    'Rest, tea and bell are explicit actions and only the notebook requests writing',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      var writes = 0;
      final sounds = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: CafeScreen(
            books: const [],
            currentWritingLabel: '지금 펼친 쪽',
            onWrite: (s, b) async {
              writes++;
              expect(s, CafeSeat.garden);
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
      Future<void> guide(String key) async {
        await tester.tap(find.byTooltip('공간 안내'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(ValueKey(key)));
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
      }

      await guide('cafe-guide-courtyard');
      expect(c.inCourtyard, isTrue);
      await guide('cafe-guide-bench');
      expect(c.resting, isTrue);
      expect(writes, 0);
      expect(sounds, isEmpty);
      await guide('cafe-guide-tea'); // nearby explicit tap may play immediately
      expect(c.teaFilled, isTrue);
      expect(sounds, ['tea']);
      expect(writes, 0);
      await guide('cafe-guide-bell');
      await guide('cafe-guide-bell');
      expect(sounds, ['tea', 'bell']);
      c.applySpace(
        c.space.copy(atmosphere: c.space.atmosphere.copy(volume: 0)),
      );
      await guide('cafe-guide-tea');
      await guide('cafe-guide-tea');
      expect(sounds, ['tea', 'bell']);
      await guide('cafe-seat-garden');
      expect(writes, 0);
      await guide('cafe-seat-garden');
      expect(writes, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Courtyard motion stops for reduced motion and app backgrounding',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CafeScreen(
            books: const [],
            currentWritingLabel: '지금 펼친 쪽',
            initialSeat: CafeSeat.garden,
            onWrite: (s, b) async => true,
            onLeave: () {},
            onRetry: () {},
          ),
        ),
      );
      double time() =>
          (tester
                      .widgetList<CustomPaint>(find.byType(CustomPaint))
                      .firstWhere((w) => w.painter is CafeRenderer)
                      .painter
                  as CafeRenderer)
              .time;
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(time(), greaterThan(0));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      final paused = time();
      await tester.pump(const Duration(seconds: 2));
      expect(time(), paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();
      final still = time();
      await tester.pump(const Duration(seconds: 2));
      expect(time(), still);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
