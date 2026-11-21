import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_renderer.dart';
import 'package:writing_human/cafe/cafe_view_controller.dart';
import 'package:writing_human/cafe/cafe_visit.dart';
import 'package:writing_human/cafe/cafe_world.dart';
import 'package:writing_human/main.dart';
import 'package:writing_human/ui/cafe_scene.dart';
import 'package:writing_human/ui/cafe_screen.dart';

import 'widget_test.dart' show MemoryStore;

void main() {
  test(
    'The first-person camera has an orthonormal view and real eye height',
    () {
      const entry = CafeCamera.entrance;
      expect(entry.position.y, 1.62);
      expect(entry.forward.length, closeTo(1, 1e-10));
      expect(entry.up.length, closeTo(1, 1e-10));
      expect(entry.forward.dot(entry.up), closeTo(0, 1e-10));
      expect(entry.right.dot(entry.forward), closeTo(0, 1e-10));
      for (final seat in CafeSeat.values) {
        final camera = CafeCamera.seated(seat);
        expect(camera.position.y, 1.18);
        expect(camera.pitch, lessThan(0));
      }
    },
  );

  test('Looking around preserves position and limits vertical rotation', () {
    final view = CafeViewController();
    addTearDown(view.dispose);
    final before = view.camera.position;
    view.look(2, 200);
    expect(view.camera.position, same(before));
    expect(view.camera.pitch, .65);
    view.look(0, -200);
    expect(view.camera.pitch, -.72);
    expect(view.camera.forward.length, closeTo(1, 1e-10));
  });

  test(
    'Projection hides points behind the eye and narrows distant geometry',
    () {
      const camera = CafeCamera(position: CafePoint(0, 1.62, 0), pitch: 0);
      const size = Size(390, 844);
      expect(
        CafeRenderer.project(const CafePoint(0, 1.62, 1), camera, size),
        isNull,
      );
      expect(
        CafeRenderer.project(const CafePoint(0, 1.62, -.01), camera, size),
        isNull,
      );
      expect(
        CafeRenderer.project(const CafePoint(0, 1.62, -2), camera, size),
        const Offset(195, 422),
      );
      final near = CafeRenderer.project(
        const CafePoint(1, 1.62, -2),
        camera,
        size,
      )!;
      final far = CafeRenderer.project(
        const CafePoint(1, 1.62, -4),
        camera,
        size,
      )!;
      expect(near.dx - 195, closeTo((far.dx - 195) * 2, 1e-9));
    },
  );

  test('Touch picking follows the camera ray to each real desk', () {
    const camera = CafeCamera.entrance;
    const size = Size(1200, 800);
    final world = CafeViewController();
    addTearDown(world.dispose);
    for (final seat in CafeSeat.values) {
      final point = CafeRenderer.project(CafeWorld.desk(seat), camera, size)!;
      expect(CafeRenderer.pickSeat(point, camera, size), seat);
    }
    expect(CafeRenderer.pickSeat(const Offset(600, 0), camera, size), isNull);
  });

  test('Walking respects walls, furniture and seated posture', () {
    final view = CafeViewController();
    addTearDown(view.dispose);
    expect(view.world.canStand(const CafePoint(.2, 1.62, -1.32)), isFalse);
    expect(view.world.canStand(const CafePoint(4, 1.62, 0)), isFalse);
    expect(view.world.canStand(const CafePoint(1.4, 1.62, -4.9)), isFalse);
    for (var i = 0; i < 200; i++) {
      view.step(.24, 0);
    }
    expect(view.camera.position.x, lessThan(3.65));
    expect(view.world.canStand(view.camera.position), isTrue);
    final point = view.camera.position;
    view.sit(CafeSeat.quiet);
    view.step(0, .24);
    expect(view.camera.position, same(point));
    expect(view.destination!.position.y, 1.18);
    view.stand();
    expect(view.seat, isNull);
    expect(view.destination, same(CafeCamera.entrance));
  });

  test('Seat travel takes the short turn across the angle boundary', () {
    const from = CafeCamera(position: CafePoint(0, 1.62, 1), yaw: math.pi - .1);
    const to = CafeCamera(position: CafePoint(1, 1.18, 0), yaw: -math.pi + .1);
    final halfway = CafeCamera.interpolate(from, to, .5);
    expect(halfway.yaw, closeTo(math.pi, 1e-9));
    expect(halfway.position.x, .5);
    expect(halfway.position.y, 1.40);
  });

  Future<void> enter(WidgetTester tester) async {
    await tester.pumpWidget(WritingHumanApp(store: MemoryStore()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-bookshelf')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-cafe')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'An untouched entrance can close without starting a camera ticker',
    (tester) async {
      await enter(tester);
      final scene = tester.widget<CafeScene>(find.byType(CafeScene));
      expect(scene.controller.seat, isNull);
      expect(scene.controller.camera.position.y, 1.62);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('cafe-start-writing')),
            )
            .onPressed,
        isNull,
      );
      expect(find.byTooltip('빗소리 켜기'), findsOneWidget);
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      expect(find.byType(CafeScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Dragging changes the first-person view and walking moves within the room',
    (tester) async {
      await enter(tester);
      final controller = tester
          .widget<CafeScene>(find.byType(CafeScene))
          .controller;
      final yaw = controller.camera.yaw;
      final origin = controller.camera.position;
      await tester.dragFrom(const Offset(400, 220), const Offset(-90, 30));
      await tester.pump();
      expect(controller.camera.yaw, isNot(yaw));
      expect(controller.camera.position, same(origin));
      await tester.tap(find.byTooltip('앞으로 걷기'));
      await tester.pump();
      expect(controller.camera.position.z, isNot(origin.z));
      expect(controller.world.canStand(controller.camera.position), isTrue);
      await tester.tap(find.byKey(const ValueKey('cafe-seat-window')));
      await tester.pumpAndSettle();
      expect(controller.camera.position.y, 1.18);
      expect(find.byTooltip('앞으로 걷기'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('cafe-stand')));
      await tester.pumpAndSettle();
      expect(controller.camera.position.y, 1.62);
    },
  );

  testWidgets('Tapping a visible 3D desk sits in that actual seat', (
    tester,
  ) async {
    await enter(tester);
    final scene = find.byKey(const ValueKey('cafe-first-person-view'));
    final controller = tester
        .widget<CafeScene>(find.byType(CafeScene))
        .controller;
    final local = CafeRenderer.project(
      CafeWorld.desk(CafeSeat.shared),
      controller.camera,
      tester.getSize(scene),
    )!;
    await tester.tapAt(tester.getTopLeft(scene) + local);
    await tester.pumpAndSettle();
    expect(controller.seat, CafeSeat.shared);
    expect(controller.camera.position.y, 1.18);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduced motion goes straight to the seated view', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await enter(tester);
    await tester.tap(find.byKey(const ValueKey('cafe-seat-quiet')));
    await tester.pump();
    final controller = tester
        .widget<CafeScene>(find.byType(CafeScene))
        .controller;
    expect(controller.camera.position.y, 1.18);
    expect(
      controller.camera.position.z,
      CafeCamera.seated(CafeSeat.quiet).position.z,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
