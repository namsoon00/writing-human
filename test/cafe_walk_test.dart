import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_renderer.dart';
import 'package:writing_human/cafe/cafe_view_controller.dart';
import 'package:writing_human/cafe/cafe_walk.dart';
import 'package:writing_human/cafe/cafe_world.dart';
import 'package:writing_human/cafe/cafe_visit.dart';
import 'package:writing_human/ui/cafe_scene.dart';
import 'package:writing_human/ui/cafe_screen.dart';

void main() {
  test(
    'Speed ramps from rest, stays bounded, and reaches the exact destination',
    () {
      for (final distance in [.02, .3, 1.0, 8.0, 15.0]) {
        final timing = CafeWalkTiming(distance);
        double last = 0, peak = 0;
        for (var i = 1; i <= 1000; i++) {
          final next = timing.at(i / 1000);
          expect(next, greaterThanOrEqualTo(last - 1e-9));
          peak = math.max(peak, (next - last) / (timing.seconds / 1000));
          last = next;
        }
        expect(last, closeTo(distance, 1e-9));
        expect(peak, lessThanOrEqualTo(1.201));
        expect(timing.at(.001), lessThan(distance * .001));
      }
    },
  );
  test(
    'Stance feet stay on the ground at the same world point while hips advance',
    () {
      final gait = CafeGait();
      gait.reset(const CafePoint(0, 0, 0), 0);
      final plant = gait.foot(0, const CafePoint(0, 0, 0), 0);
      for (var i = 1; i <= 45; i++) {
        final actor = CafePoint(0, 0, -i * .01);
        gait.move(actor, 0);
        final foot = gait.foot(0, actor, 0);
        expect((foot - plant).length, lessThan(1e-9));
        expect(foot.y, .06);
      }
      gait.move(const CafePoint(0, 0, -.68), 0);
      expect(gait.foot(0, const CafePoint(0, 0, -.68), 0).y, greaterThan(.06));
    },
  );
  test('Rounded walking paths never cut the table, chair or pond corners', () {
    for (final courtyard in [false, true]) {
      final world = CafeWorld(courtyard: courtyard);
      final start = courtyard
          ? CafeCamera.courtyardEntrance
          : CafeCamera.entrance;
      for (final target in world.targets) {
        final path = world.path(start.position, CafeWorld.approach(target));
        expect(path, isNotEmpty, reason: target.name);
        final route = cafeWalkRoute([
          start,
          ...path.map((p) => CafeCamera(position: p)),
        ], world);
        for (var i = 1; i < route.length; i++) {
          expect(
            world.clearSegment(route[i - 1].position, route[i].position),
            isTrue,
            reason: target.name,
          );
        }
      }
    }
  });
  test(
    'Rear camera stays inside walls and each blended viewpoint remains finite',
    () {
      final c = CafeViewController();
      addTearDown(c.dispose);
      c.togglePerspective();
      for (final p in [
        const CafePoint(0, 1.62, 4.65),
        const CafePoint(-4, 1.62, 3.5),
        const CafePoint(2.9, 1.62, .3),
      ]) {
        for (var i = 0; i < 8; i++) {
          c.updateCamera(CafeCamera(position: p, yaw: i * math.pi / 4));
          for (final blend in [.1, .5, 1.0]) {
            c.setViewBlend(blend);
            final eye = c.displayCamera;
            expect(eye.isFinite, isTrue);
            expect(eye.position.x.abs(), lessThan(4.4));
            expect(eye.position.z.abs(), lessThan(5));
            expect(
              (c.world.clipCamera(c.camera.position, eye.position) -
                      eye.position)
                  .length,
              lessThan(.001),
            );
          }
        }
      }
    },
  );
  test('Retargeting or cancelling a seat walk uses the current position', () {
    final c = CafeViewController();
    addTearDown(c.dispose);
    c.visit(CafeTarget.quiet);
    c.advanceCamera(
      const CafeCamera(position: CafePoint(1.6, 1.62, 2.6)),
      dt: .1,
      walking: true,
    );
    final current = c.camera.position;
    expect(c.seat, isNull);
    expect(c.walkTo(const CafePoint(2.1, 0, 1.8)), isTrue);
    expect(c.world.clearSegment(current, c.journey.first.position), isTrue);
    c.look(.01, 0);
    expect((c.camera.position - current).length, lessThan(1e-9));
    expect(c.seat, isNull);
    expect(c.arrival, isNull);
    expect(c.walkSpeed, 0);
    expect(c.walkTo(const CafePoint(2.3, 0, 2)), isTrue);
  });
  testWidgets(
    'Perspective selection does not write; holding and releasing W starts and stops walking',
    (tester) async {
      var writes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CafeScreen(
            books: const [],
            currentWritingLabel: '지금 펼친 쪽',
            onWrite: (s, b) async {
              writes++;
              return true;
            },
            onLeave: () {},
            onRetry: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final c = tester.widget<CafeScene>(find.byType(CafeScene)).controller;
      c.updateCamera(const CafeCamera(position: CafePoint(2.8, 1.62, 2.8)));
      await tester.tap(find.byKey(const ValueKey('cafe-toggle-perspective')));
      await tester.pumpAndSettle();
      expect(c.thirdPerson, isTrue);
      expect(c.viewBlend, 1);
      expect(writes, 0);
      // A floor click is projected from the rear camera, not the actor's eyes.
      final surface = find.byKey(const ValueKey('cafe-first-person-view'));
      final rect = tester.getRect(surface);
      final destination = CafeRenderer.project(
        const CafePoint(2.8, 0, 1.6),
        c.displayCamera,
        rect.size,
      )!;
      await tester.tapAt(rect.topLeft + destination);
      await tester.pump();
      expect(c.travelling, isTrue);
      expect(c.destination!.position.x, closeTo(2.8, .03));
      expect(c.destination!.position.z, closeTo(1.6, .03));
      // Focus the physical scene, without tapping a walk destination.
      tester
          .widget<KeyboardListener>(
            find.descendant(
              of: find.byType(CafeScene),
              matching: find.byType(KeyboardListener),
            ),
          )
          .focusNode
          .requestFocus();
      await tester.pump();
      final before = c.camera.position;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }
      expect((c.camera.position - before).length, greaterThan(.2));
      expect(c.world.canStand(c.camera.position), isTrue);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
      await tester.pump();
      final stopped = c.camera.position;
      await tester.pump(const Duration(seconds: 1));
      expect((c.camera.position - stopped).length, lessThan(1e-9));
      expect(c.walkSpeed, 0);
      expect(writes, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
