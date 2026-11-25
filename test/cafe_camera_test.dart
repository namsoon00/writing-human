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

Future<void> _enter(WidgetTester tester) async {
  await tester.pumpWidget(WritingHumanApp(store: MemoryStore()));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('open-bookshelf')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('open-cafe')));
  await tester.pumpAndSettle();
}

void main() {
  test('Eye-height cameras have orthonormal axes and valid seated poses', () {
    for (final c in [
      CafeCamera.entrance,
      ...CafeSeat.values.map(CafeCamera.seated),
    ]) {
      expect(c.isFinite, isTrue);
      expect(c.forward.length, closeTo(1, 1e-10));
      expect(c.up.length, closeTo(1, 1e-10));
      expect(c.forward.dot(c.up), closeTo(0, 1e-10));
      expect(c.right.dot(c.forward), closeTo(0, 1e-10));
    }
    expect(CafeCamera.entrance.position.y, 1.62);
    for (final seat in CafeSeat.values) {
      expect(CafeCamera.seated(seat).position.y, 1.18);
    }
  });

  test('Invalid pointer and camera values cannot poison the view', () {
    final view = CafeViewController();
    addTearDown(view.dispose);
    final before = view.camera;
    view.look(double.nan, 0);
    view.look(0, double.infinity);
    view.step(double.infinity, 0);
    view.updateCamera(const CafeCamera(position: CafePoint(double.nan, 1, 0)));
    expect(view.camera, same(before));
    view.look(20000, 200);
    expect(view.camera.pitch, .65);
    expect(view.camera.yaw.abs(), lessThanOrEqualTo(math.pi));
    view.look(0, -200);
    expect(view.camera.pitch, -.72);
    expect(view.world.canStand(const CafePoint(double.nan, 1, 0)), isFalse);
  });

  test(
    'Projection rejects geometry behind the camera and shrinks distant objects',
    () {
      const c = CafeCamera(position: CafePoint(0, 1.62, 0), pitch: 0);
      const size = Size(390, 844);
      expect(
        CafeRenderer.project(const CafePoint(0, 1.62, 1), c, size),
        isNull,
      );
      expect(
        CafeRenderer.project(const CafePoint(0, 1.62, -.01), c, size),
        isNull,
      );
      expect(
        CafeRenderer.project(const CafePoint(0, 1.62, -2), c, size),
        const Offset(195, 422),
      );
      final a = CafeRenderer.project(const CafePoint(1, 1.62, -2), c, size)!;
      final b = CafeRenderer.project(const CafePoint(1, 1.62, -4), c, size)!;
      expect(a.dx - 195, closeTo((b.dx - 195) * 2, 1e-9));
    },
  );

  test(
    'Nearest physical object owns a click; a desk hides the floor beneath it',
    () {
      final world = CafeWorld();
      const c = CafeCamera.entrance, size = Size(1200, 800);
      final table = CafeRenderer.project(
        CafeWorld.anchor(CafeTarget.shared),
        c,
        size,
      )!;
      final hit = CafeRenderer.pick(table, c, size, world)!;
      expect(hit.target, CafeTarget.shared);
      expect(hit.floor, isFalse);
      final blank = CafeRenderer.project(const CafePoint(2, 0, .5), c, size)!;
      expect(CafeRenderer.pick(blank, c, size, world)!.floor, isTrue);
      // A distant bookcase cannot be selected through the central table.
      final down = CafeCamera.seated(CafeSeat.shared);
      final notebook = CafeRenderer.project(
        CafeWorld.desk(CafeSeat.shared),
        down,
        size,
      )!;
      expect(
        CafeRenderer.pick(notebook, down, size, world)!.target,
        CafeTarget.shared,
      );
    },
  );

  test('Every visible fixture can be hit by its own physical surface', () {
    const size = Size(390, 844);
    for (final target in CafeTarget.values) {
      final world = CafeWorld(courtyard: target.inCourtyard);
      final origin = CafeWorld.approach(target);
      final delta = CafeWorld.anchor(target) - origin;
      final camera = CafeCamera(
        position: origin,
        yaw: math.atan2(delta.x, -delta.z),
        pitch: math.atan2(
          delta.y,
          math.sqrt(delta.x * delta.x + delta.z * delta.z),
        ),
      );
      final hit = CafeRenderer.pick(
        const Offset(195, 422),
        camera,
        size,
        world,
      );
      expect(hit?.target, target, reason: target.name);
    }
  });

  test('Floor routes go around the table with no wall or corner cutting', () {
    final world = CafeWorld();
    const from = CafePoint(-2.0, 1.62, 0), to = CafePoint(2.0, 1.62, 0);
    expect(world.clearSegment(from, to), isFalse);
    final path = world.path(from, to);
    expect(path, isNotEmpty);
    expect(path.length, greaterThan(1));
    var current = from;
    for (final p in path) {
      expect(world.canStand(p), isTrue);
      expect(world.clearSegment(current, p), isTrue);
      current = p;
    }
    expect(current.x, to.x);
    expect(world.path(from, const CafePoint(0, 1.62, 0)), isEmpty);
    expect(world.clearSegment(from, const CafePoint(100, 1.62, 0)), isFalse);
  });

  test(
    'Every object has a walkable reachable approach, including the quiet desk',
    () {
      for (final target in CafeTarget.values) {
        final world = CafeWorld(courtyard: target.inCourtyard);
        final entrance = target.inCourtyard
            ? CafeCamera.courtyardEntrance
            : CafeCamera.entrance;
        final approach = CafeWorld.approach(target);
        expect(world.canStand(approach), isTrue, reason: target.name);
        final path = world.path(entrance.position, approach);
        expect(path, isNotEmpty, reason: target.name);
        var current = entrance.position;
        for (final point in path) {
          expect(
            world.clearSegment(current, point),
            isTrue,
            reason: target.name,
          );
          current = point;
        }
      }
    },
  );

  test(
    'Standing returns beside the current chair and walking never tunnels',
    () {
      final c = CafeViewController();
      addTearDown(c.dispose);
      c.sit(CafeSeat.quiet);
      expect(c.destination!.position.y, 1.18);
      c.updateCamera(c.destination!);
      c.finishTravel();
      c.stand();
      expect(c.destination!.position.z, CafeWorld.approach(CafeTarget.quiet).z);
      c.updateCamera(c.destination!);
      c.finishTravel();
      final before = c.camera;
      c.step(100, 0);
      expect(c.camera, same(before));
    },
  );

  test('Seat travel takes the short turn across the angle boundary', () {
    const a = CafeCamera(position: CafePoint(0, 1.62, 1), yaw: math.pi - .1);
    const b = CafeCamera(position: CafePoint(1, 1.18, 0), yaw: -math.pi + .1);
    final halfway = CafeCamera.interpolate(a, b, .5);
    expect(halfway.yaw, closeTo(math.pi, 1e-9));
    expect(halfway.position.x, .5);
  });

  testWidgets(
    'Entrance keeps the room clear of bottom controls and can close',
    (tester) async {
      await _enter(tester);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byTooltip('앞으로 걷기'), findsNothing);
      expect(find.byKey(const ValueKey('cafe-start-writing')), findsNothing);
      expect(find.byTooltip('공간 안내'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('paper-back')).hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(CafeScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Clicking empty floor walks there; dragging only turns the view',
    (tester) async {
      await _enter(tester);
      final scene = find.byKey(const ValueKey('cafe-first-person-view'));
      final c = tester.widget<CafeScene>(find.byType(CafeScene)).controller;
      final point = CafeRenderer.project(
        const CafePoint(1.6, 0, 1.2),
        c.camera,
        tester.getSize(scene),
      )!;
      expect((Offset.zero & tester.getSize(scene)).contains(point), isTrue);
      await tester.tapAt(tester.getTopLeft(scene) + point);
      await tester.pumpAndSettle();
      expect(c.camera.position.x, closeTo(1.6, .02));
      expect(c.camera.position.z, closeTo(1.2, .02));
      final origin = c.camera.position, yaw = c.camera.yaw;
      await tester.dragFrom(const Offset(380, 250), const Offset(-70, 30));
      await tester.pumpAndSettle();
      expect(c.camera.position, same(origin));
      expect(c.camera.yaw, isNot(yaw));
      expect(c.seat, isNull);
    },
  );

  testWidgets(
    'A real table click sits, and a second notebook click opens writing',
    (tester) async {
      await _enter(tester);
      final scene = find.byKey(const ValueKey('cafe-first-person-view'));
      final c = tester.widget<CafeScene>(find.byType(CafeScene)).controller;
      final local = CafeRenderer.project(
        CafeWorld.anchor(CafeTarget.shared),
        c.camera,
        tester.getSize(scene),
      )!;
      await tester.tapAt(tester.getTopLeft(scene) + local);
      // The window fish keep painting while seated; wait for the route,
      // rather than requiring the whole live scene to become idle.
      await tester.pump();
      for (var i = 0; i < 120 && c.travelling; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(c.travelling, isFalse);
      expect(c.seat, CafeSeat.shared);
      expect(c.camera.position.y, closeTo(1.18, 1e-9));
      expect(
        find.byKey(const ValueKey('cafe-start-writing')).hitTestable(),
        findsOneWidget,
      );
      // Hit the actual notebook surface away from its small attached label.
      final book = CafeRenderer.project(
        const CafePoint(.22, .81, .65),
        c.camera,
        tester.getSize(scene),
      )!;
      await tester.tapAt(tester.getTopLeft(scene) + book);
      await tester.pumpAndSettle();
      expect(find.byType(CafeScreen), findsNothing);
      expect(find.byKey(const ValueKey('page-text')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Reduced motion finishes the full route without a walking ticker',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _enter(tester);
      await tester.tap(find.byTooltip('공간 안내'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cafe-seat-quiet')));
      await tester.pumpAndSettle();
      final c = tester.widget<CafeScene>(find.byType(CafeScene)).controller;
      expect(c.camera.position.y, closeTo(1.18, 1e-9));
      expect(c.travelling, isFalse);
      expect(c.camera.position.z, CafeCamera.seated(CafeSeat.quiet).position.z);
      expect(tester.takeException(), isNull);
    },
  );
}
