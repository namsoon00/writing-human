import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_avatar.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_chase_camera.dart';
import 'package:writing_human/cafe/cafe_renderer.dart';
import 'package:writing_human/cafe/cafe_space.dart';
import 'package:writing_human/cafe/cafe_view_controller.dart';
import 'package:writing_human/cafe/cafe_visit.dart';
import 'package:writing_human/cafe/cafe_world.dart';

void main() {
  test(
    'Open bay keeps the observer at a comfortable distance across the room boundary',
    () {
      final c = CafeViewController()..inCourtyard = true;
      addTearDown(c.dispose);
      c.updateCamera(CafeCamera.courtyardEntrance);
      final eye = c.viewCamera;
      expect(eye.position.z, greaterThan(3.2));
      expect((eye.position - c.camera.position).length, greaterThan(1.8));
      expect(eye.lens, greaterThan(.7));
      expect(cafeCameraWithinRoom(c.world, eye.position), isTrue);
      expect(
        cafeCameraWithinRoom(c.world, const CafePoint(2.5, 1, 4)),
        isFalse,
      );
      expect(cafeCameraWithinRoom(c.world, const CafePoint(0, 1, 7)), isFalse);
      expect(c.world.canStand(c.camera.position), isTrue);
      expect(
        c.world.canStand(eye.position),
        isFalse,
        reason: 'Observer freedom does not extend the walking boundary',
      );
    },
  );

  test(
    'Relocated window notebook is visible and selectable on a short wide screen',
    () {
      final c = CafeViewController(seat: CafeSeat.window);
      addTearDown(c.dispose);
      const size = Size(800, 600);
      final anchor = c.world.targetDesk(CafeSeat.window);
      final pixel = CafeRenderer.project(anchor, c.viewCamera, size)!;
      expect(pixel.dy, inInclusiveRange(130, 544));
      expect(
        CafeRenderer.pick(pixel, c.viewCamera, size, c.world)?.target,
        CafeTarget.window,
      );
    },
  );

  test('Small A leaves the garden visible and keeps grounded short legs', () {
    final c = CafeViewController();
    addTearDown(c.dispose);
    final a = c.avatar;
    final points = a.faces.expand((f) => f.points).toList();
    expect(
      points.map((p) => p.y).reduce(math.max),
      inInclusiveRange(1.20, 1.33),
    );
    expect(points.map((p) => p.y).reduce(math.min), inInclusiveRange(0, .025));
    final face = a.faces.where((f) => f.part == 'face').expand((f) => f.points);
    final height =
        face.map((p) => p.y).reduce(math.max) -
        face.map((p) => p.y).reduce(math.min);
    expect(height, greaterThan(.25));
    const size = Size(390, 844);
    final top = CafeRenderer.project(
      CafePoint(0, 1.27, 0),
      c.viewCamera,
      size,
    )!;
    final feet = CafeRenderer.project(CafePoint(0, 0, 0), c.viewCamera, size)!;
    expect((top.dy - feet.dy).abs(), lessThan(size.height * .44));
    for (var i = 0; i < 12; i++) {
      final walk = CafeAvatar(
        eye: c.actorCamera,
        yaw: c.bodyYaw,
        stride: 1,
        phase: i * math.pi / 6,
      );
      expect(
        walk.faces.every((f) => f.points.every((p) => p.isFinite)),
        isTrue,
      );
      expect(
        walk.faces
            .where((f) => f.part == 'shoe.sole')
            .expand((f) => f.points)
            .map((p) => p.y)
            .reduce(math.min),
        greaterThanOrEqualTo(0),
      );
    }
  });

  test(
    'Wide central passage matches on both sides with a straight clear aisle',
    () {
      final room = CafeWorld();
      final yard = room.linkedWorld;
      final inner = room.faces.singleWhere(
        (f) => f.garden && f.target == CafeTarget.courtyard,
      );
      final outer = yard.faces.singleWhere(
        (f) => f.garden && f.target == CafeTarget.cafeReturn,
      );
      final zs = inner.points.map((p) => p.z),
          xs = outer.points.map((p) => p.x);
      expect((zs.reduce(math.max) + zs.reduce(math.min)).abs(), lessThan(1e-9));
      expect((xs.reduce(math.max) + xs.reduce(math.min)).abs(), lessThan(1e-9));
      expect(zs.reduce(math.max) - zs.reduce(math.min), greaterThan(4));
      for (final side in [-1.0, 0.0, 1.0]) {
        for (var x = -3.7; x < 2.0; x += .1) {
          expect(
            room.canStand(CafePoint(x, 1.62, side)),
            isTrue,
            reason: 'aisle $x,$side',
          );
        }
      }
      expect(
        yard.clearSegment(
          const CafePoint(0, 1.62, 2.35),
          const CafePoint(0, 1.62, 0),
        ),
        isTrue,
      );
      expect(room.validateLayout(), isNull);
      expect(yard.validateLayout(), isNull);
      expect(room.objects['shared.table']!.footprint!.bottom, lessThan(-1.3));
    },
  );

  test(
    'Relocated parents retain saved offsets, states and item identities',
    () {
      const space = CafeSpace(
        poses: {
          'shared.cup': CafePose(x: .03),
          'desk.window.book': CafePose(z: .02),
        },
        bookOpen: false,
        cupFull: false,
        doorOpen: false,
      );
      final before = space.encode();
      final original = CafeWorld(), room = CafeWorld(space: space);
      expect(room.objects.keys.toSet(), original.objects.keys.toSet());
      expect(
        (room.objects['shared.cup']!.pivot -
                original.objects['shared.cup']!.pivot)
            .x,
        closeTo(.03, 1e-9),
      );
      expect(room.space.encode(), before);
      expect(CafeSpace.decode(before).encode(), before);
    },
  );

  test(
    'Small seated hands can meet a held cup without moving its world anchor',
    () {
      final c = CafeViewController(seat: CafeSeat.shared);
      addTearDown(c.dispose);
      c.performUse('shared.cup', CafeUseKind.pickUp);
      c.advanceUse(1);
      c.finishUse();
      final cup = c.world.objects['shared.cup']!;
      final held = cafeHeldPoint(
        c.actorCamera,
        cup.type,
        c.useFrame!,
        thirdPerson: true,
      );
      final hands = c.avatar.faces
          .where((f) => f.part == 'hand')
          .map((f) => f.center);
      expect(
        hands.map((p) => (p - held).length).reduce(math.min),
        lessThan(.14),
      );
      expect(held.y, greaterThanOrEqualTo(.75));
      expect(c.space.poses, isEmpty);
    },
  );
}
