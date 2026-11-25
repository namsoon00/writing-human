import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_visit.dart';
import 'package:writing_human/ui/cafe_scene.dart';
import 'package:writing_human/ui/cafe_screen.dart';

void main() {
  testWidgets(
    'A single nearby label follows the gaze and every destination remains in the guide',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CafeScreen(
            books: const [],
            currentWritingLabel: '지금 펼친 쪽',
            onWrite: (seat, book) async => true,
            onLeave: () {},
            onRetry: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final c = tester.widget<CafeScene>(find.byType(CafeScene)).controller;
      final labels = find.byWidgetPredicate(
        (w) =>
            w is TextButton &&
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('cafe-object-'),
      );
      expect(labels.evaluate().length, lessThanOrEqualTo(1));
      c.updateCamera(
        const CafeCamera(
          position: CafePoint(3.0, 1.62, -2.25),
          yaw: math.pi / 2,
          pitch: -.08,
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('cafe-object-recommendations')),
        findsOneWidget,
      );
      expect(labels, findsOneWidget);
      // Gaze dragging gives the scene priority; release restores the label.
      final gesture = await tester.startGesture(
        tester.getTopLeft(
              find.byKey(const ValueKey('cafe-third-person-view')),
            ) +
            const Offset(50, 300),
      );
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      expect(labels, findsNothing);
      await gesture.up();
      await tester.pump();
      expect(labels, findsOneWidget);
      c.updateCamera(
        const CafeCamera(
          position: CafePoint(0, 1.62, 3.6),
          yaw: math.pi,
          pitch: .4,
        ),
      );
      await tester.pump();
      // The former street doorway is now an ordinary wall.
      expect(
        find.byKey(const ValueKey('cafe-object-recommendations')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('cafe-object-exit')), findsNothing);
      expect(labels.evaluate().length, lessThanOrEqualTo(1));
      await tester.tap(find.byTooltip('공간 안내'));
      await tester.pumpAndSettle();
      for (final target in c.world.targets) {
        expect(
          find.byKey(
            target.seat == null
                ? ValueKey('cafe-guide-${target.name}')
                : ValueKey('cafe-seat-${target.seat!.name}'),
          ),
          findsOneWidget,
        );
      }
      await tester.ensureVisible(find.text('닫기').last);
      await tester.tap(find.text('닫기').last);
      await tester.pumpAndSettle();
      c.sit(CafeSeat.window);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('cafe-start-writing')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
