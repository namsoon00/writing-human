import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_avatar.dart';
import 'package:writing_human/cafe/cafe_body.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_view_controller.dart';
import 'package:writing_human/cafe/cafe_world.dart';
import 'package:writing_human/cafe/cafe_walk.dart';
import 'package:writing_human/cafe/cafe_visit.dart';

void main() {
  test('Seated hands rest flat above the table instead of pointing upward', () {
    final a = CafeAvatar(
      eye: const CafeCamera(position: CafePoint(0, 1.18, 0)),
      yaw: 0,
    );
    final hand = a.faces
        .where((f) => {'hand', 'finger', 'thumb'}.contains(f.part))
        .expand((f) => f.points);
    expect(hand.map((p) => p.y).reduce(math.min), greaterThan(.7525));
    expect(hand.map((p) => p.y).reduce(math.max), lessThan(.82));
  });
  test('Resting transitions fold and rise in place before walking away', () {
    final c = CafeViewController();
    addTearDown(c.dispose);
    c.visit(CafeTarget.courtyard);
    c.updateCamera(c.destination!);
    c.finishTravel();
    c.visit(CafeTarget.meditation);
    void check(List<CafeCamera> route) {
      for (var i = 1; i < route.length; i++) {
        final delta = route[i].position - route[i - 1].position;
        if (delta.y.abs() > .01) {
          expect(CafePoint(delta.x, 0, delta.z).length, lessThan(1e-8));
        }
      }
    }

    check(cafeWalkRoute([c.camera, ...c.journey], c.world));
    c.updateCamera(c.destination!);
    c.finishTravel();
    c.look(1.0, 0);
    final yaw = c.bodyYaw;
    c.stand();
    final route = cafeWalkRoute([c.camera, ...c.journey], c.world);
    check(route);
    expect(route[1].position.y, 1.62);
    c.advanceCamera(
      CafeCamera.interpolate(route[0], route[1], .4),
      dt: .1,
      walking: false,
    );
    expect(c.bodyYaw, yaw);
  });
  test(
    'Slow cadence has fixed bones throughout folding and every footfall',
    () {
      expect(
        CafeBody.walkSpeed / CafeBody.gaitLength * 120,
        inInclusiveRange(85, 110),
      );
      for (var i = 0; i <= 30; i++) {
        final fold = i / 30;
        for (var j = 0; j < 12; j++) {
          final a = CafeAvatar(
            eye: CafeCamera(position: CafePoint(0, 1.62 - fold * .84, 0)),
            yaw: 0,
            phase: j * math.pi / 6,
            stride: 1 - fold,
            meditation: fold,
          );
          for (final leg in a.skeleton.legs) {
            expect(
              (leg.knee - leg.hip).length,
              closeTo(CafeSkeleton.thigh, 1e-5),
            );
            expect(
              (leg.ankle - leg.knee).length,
              closeTo(CafeSkeleton.shin, 1e-5),
            );
            expect(leg.knee.isFinite && leg.ankle.isFinite, isTrue);
          }
        }
      }
    },
  );

  test('Meditation separates the calves and turns feet out onto the mat', () {
    final a = CafeAvatar(
      eye: const CafeCamera(position: CafePoint(0, .78, 0)),
      yaw: 0,
      meditation: 1,
    );
    final left = a.skeleton.legs[0], right = a.skeleton.legs[1];
    expect(left.knee.x, lessThan(-.12));
    expect(right.knee.x, greaterThan(.12));
    expect((left.ankle.z - right.ankle.z).abs(), greaterThan(.10));
    var gap = double.infinity;
    for (var i = 1; i < 10; i++) {
      for (var j = 1; j < 10; j++) {
        gap = math.min(
          gap,
          (CafePoint.lerp(left.knee, left.ankle, i / 10) -
                  CafePoint.lerp(right.knee, right.ankle, j / 10))
              .length,
        );
      }
    }
    expect(gap, greaterThan(.085));
    expect(left.yaw, greaterThan(1));
    expect(right.yaw, lessThan(-1));
    final feet = a.faces.where((f) => f.part == 'foot').expand((f) => f.points);
    expect(feet.map((p) => p.y).reduce(math.min), inInclusiveRange(.045, .060));
  });

  test(
    'Stopping keeps position and settles one foot before the support foot',
    () {
      final c = CafeViewController();
      addTearDown(c.dispose);
      c.advanceCamera(
        CafeCamera(position: c.camera.position + const CafePoint(0, 0, -.08)),
        dt: .2,
        walking: true,
      );
      c.stopWalking(smooth: true);
      final origin = c.camera.position;
      final before = c.avatar.skeleton.legs[1].ankle;
      expect(c.settling, isTrue);
      c.advanceSettle(.25);
      expect(c.avatar.skeleton.legs[1].ankle.z, closeTo(before.z, 1e-6));
      c.advanceSettle(1);
      expect(c.avatar.stride, 0);
      expect(c.camera.position, same(origin));
      expect(c.settling, isFalse);
    },
  );

  test('A renewed tap blends out of the recovery step without a foot jump', () {
    final c = CafeViewController();
    addTearDown(c.dispose);
    c.advanceCamera(
      CafeCamera(position: c.camera.position + const CafePoint(0, 0, -.56)),
      dt: 1.2,
      walking: true,
    );
    c.stopWalking(smooth: true);
    c.advanceSettle(.2);
    final before = c.avatar.skeleton.legs[1].ankle;
    c.advanceCamera(
      CafeCamera(position: c.camera.position + const CafePoint(0, 0, -.002)),
      dt: .016,
      walking: true,
    );
    final after = c.avatar.skeleton.legs[1].ankle;
    expect((after - before).length, lessThan(.04));
  });

  test(
    'Touch keeps a lamp grounded; a chair moves only after hand contact',
    () {
      final w = CafeWorld();
      final lamp = w.objects.values.firstWhere(
        (o) => o.type == CafeItemType.lamp,
      );
      final chair = w.objects.values.firstWhere(
        (o) => o.type == CafeItemType.chair,
      );
      const eye = CafeCamera(position: CafePoint(0, 1.62, 0));
      CafePoint corner(String id, CafeUseFrame? frame) => w
          .presentedFaces(eye, frame, thirdPerson: true)
          .firstWhere((f) => f.objectId == id && f.color.a > .99)
          .points
          .first;
      final fixed = corner(lamp.id, null);
      expect(
        (corner(
                  lamp.id,
                  CafeUseFrame(lamp.id, CafeUseKind.touch, progress: .5),
                ) -
                fixed)
            .length,
        lessThan(1e-8),
      );
      final before = corner(chair.id, null);
      expect(
        (corner(
                  chair.id,
                  CafeUseFrame(chair.id, CafeUseKind.pull, progress: .1),
                ) -
                before)
            .length,
        lessThan(1e-8),
      );
      expect(
        (corner(
                  chair.id,
                  CafeUseFrame(chair.id, CafeUseKind.pull, progress: .9),
                ) -
                before)
            .length,
        closeTo(.06, 1e-8),
      );
    },
  );

  test(
    'A prop stays on its support until reach and grip; release follows placement',
    () {
      const id = 'shared.cup';
      for (final p in [0.0, .10, .20, .30]) {
        final frame = CafeUseFrame(id, CafeUseKind.pickUp, progress: p);
        expect(cafePropLift(frame), 0);
      }
      expect(
        cafeHandReach(
          const CafeUseFrame(id, CafeUseKind.pickUp, progress: .30),
        ),
        closeTo(1, 1e-9),
      );
      expect(
        cafeGrip(const CafeUseFrame(id, CafeUseKind.pickUp, progress: .30)),
        closeTo(1, 1e-9),
      );
      const placed = CafeUseFrame(
        id,
        CafeUseKind.putDown,
        held: true,
        progress: .72,
      );
      expect(cafePropLift(placed), 0);
      expect(cafeGrip(placed), 1);
    },
  );
}
