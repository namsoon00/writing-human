import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_renderer.dart';
import 'package:writing_human/cafe/cafe_space.dart';
import 'package:writing_human/cafe/cafe_world.dart';
import 'package:writing_human/ui/cafe_scene.dart';
import 'package:writing_human/ui/cafe_screen.dart';

void main() {
  testWidgets(
    'A real cup hit toggles only that cup; edit, save and reset are item scoped',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final store = MemoryCafeSpaceStore();
      await tester.pumpWidget(
        MaterialApp(
          home: CafeScreen(
            books: const [],
            currentWritingLabel: 'test',
            spaceStore: store,
            onWrite: (_, _) async => true,
            onLeave: () {},
            onRetry: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final c = tester.widget<CafeScene>(find.byType(CafeScene)).controller;
      final cup = c.world.objects['shared.cup']!.pivot;
      c.updateCamera(
        CafeCamera(position: cup + const CafePoint(0, .65, .7), pitch: -.70),
      );
      await tester.pumpAndSettle();
      final scene = find.byKey(const ValueKey('cafe-first-person-view'));
      final size = tester.getSize(scene);
      final point = CafeRenderer.project(
        cup + const CafePoint(0, .055, 0),
        c.camera,
        size,
      )!;
      expect(
        CafeRenderer.pick(point, c.camera, size, c.world)?.objectId,
        'shared.cup',
      );
      await tester.tapAt(tester.getTopLeft(scene) + point);
      await tester.pumpAndSettle();
      expect(store.value.state('shared.cup'), isFalse);
      expect(store.value.states.containsKey('desk.window.cup'), isFalse);
      await tester.tap(find.byKey(const ValueKey('room-edit')));
      await tester.pumpAndSettle();
      tester.widget<CafeScene>(find.byType(CafeScene)).onObjectSelected!(
        'desk.window.cup',
      );
      await tester.pumpAndSettle();
      final finish = find.byKey(
        const ValueKey('room-option-desk.window.cup-색-2'),
      );
      await tester.ensureVisible(finish);
      await tester.tap(finish);
      await tester.pumpAndSettle();
      expect(c.space.finish('desk.window.cup'), 2);
      expect(c.space.finishes.containsKey('shared.cup'), isFalse);
      final save = find.byKey(const ValueKey('room-finish'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(store.value.finish('desk.window.cup'), 2);
      expect(store.value.state('shared.cup'), isFalse);
      await tester.tap(find.byKey(const ValueKey('room-edit')));
      await tester.pumpAndSettle();
      tester.widget<CafeScene>(find.byType(CafeScene)).onObjectSelected!(
        'desk.window.cup',
      );
      await tester.pumpAndSettle();
      final reset = find.byKey(const ValueKey('room-reset-item'));
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(c.space.finishes.containsKey('desk.window.cup'), isFalse);
      expect(c.space.state('shared.cup'), isFalse);
      final cancel = find.byKey(const ValueKey('room-cancel'));
      await tester.ensureVisible(cancel);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(c.space.finish('desk.window.cup'), 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'A pre-upgrade overhanging layout is retained and can be corrected',
    (tester) async {
      final store = MemoryCafeSpaceStore()
        ..value = const CafeSpace(poses: {'shared.cup': CafePose(x: -.30)});
      await tester.pumpWidget(
        MaterialApp(
          home: CafeScreen(
            books: const [],
            currentWritingLabel: 'test',
            spaceStore: store,
            onWrite: (_, _) async => true,
            onLeave: () {},
            onRetry: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final c = tester.widget<CafeScene>(find.byType(CafeScene)).controller;
      expect(c.space.pose('shared.cup').x, -.30);
      expect(store.value.pose('shared.cup').x, -.30);
      await tester.tap(find.byKey(const ValueKey('room-edit')));
      await tester.pumpAndSettle();
      tester.widget<CafeScene>(find.byType(CafeScene)).onObjectSelected!(
        'shared.cup',
      );
      await tester.pumpAndSettle();
      final reset = find.byKey(const ValueKey('room-reset-item'));
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(c.space.pose('shared.cup').x, 0);
      expect(c.world.validateLayout(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
