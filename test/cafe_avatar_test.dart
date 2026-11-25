import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_avatar.dart';
import 'package:writing_human/cafe/cafe_body.dart';
import 'package:writing_human/cafe/cafe_chase_camera.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_renderer.dart';
import 'package:writing_human/cafe/cafe_view_controller.dart';
import 'package:writing_human/cafe/cafe_visit.dart';
import 'package:writing_human/cafe/cafe_world.dart';

void main() {
  test(
    'A is a complete smooth lit mesh in standing, walking and seated poses',
    () {
      for (final seated in [false, true]) {
        for (final phase in [0.0, math.pi / 2, math.pi, 3 * math.pi / 2]) {
          final a = CafeAvatar(
            eye: CafeCamera(position: CafePoint(0, seated ? 1.18 : 1.62, 0)),
            yaw: .4,
            phase: phase,
            stride: 1,
          );
          expect(a.faces.length, inInclusiveRange(1000, 3500));
          final parts = a.faces.map((f) => f.part).toSet();
          expect(
            parts,
            containsAll([
              'face',
              'hair',
              'hair.lock',
              'linen.collar',
              'linen.pocket',
              'pocket.pen',
              'linen.cuff',
              'linen.yoke',
              'finger',
              'thumb',
              'shoe.sole',
              'shoe.stitch',
            ]),
          );
          for (final f in a.faces) {
            expect(f.layer, 2);
            expect(f.unlit, isFalse);
            expect(f.points.every((p) => p.isFinite), isTrue);
            expect(f.normal.isFinite, isTrue);
            expect(
              f.vertexNormals!.every(
                (n) => n.isFinite && (n.length - 1).abs() < 1e-8,
              ),
              isTrue,
            );
          }
          final bottom = a.faces
              .expand((f) => f.points)
              .map((p) => p.y)
              .reduce(math.min);
          expect(bottom, inInclusiveRange(0, .03));
        }
      }
    },
  );
  test('A wall corner never pushes the observer through a wall', () {
    final c = CafeViewController();
    addTearDown(c.dispose);
    for (final x in [-4.14, 4.14]) {
      for (final z in [-4.7, 4.7]) {
        if (!c.world.canStand(CafePoint(x, 1.62, z))) continue;
        for (final yaw in [-2.5, -1.5, 0.0, 1.5, 2.5]) {
          c.updateCamera(
            CafeCamera(position: CafePoint(x, 1.62, z), yaw: yaw, pitch: -.72),
          );
          final eye = c.viewCamera;
          expect(eye.position.x.abs(), lessThan(CafeWorld.halfWidth - .13));
          expect(eye.position.z.abs(), lessThan(CafeWorld.halfDepth - .13));
          expect(
            CafeRenderer.project(
              CafePoint(x, 1.77, z),
              eye,
              const Size(390, 844),
            ),
            isNotNull,
          );
        }
      }
    }
  });
  test('Orbit preserves the body; gait advances only by actual travel', () {
    final c = CafeViewController();
    addTearDown(c.dispose);
    final body = c.bodyYaw, origin = c.camera.position;
    c.look(.5, .1);
    expect(c.bodyYaw, body);
    expect(c.camera.position, same(origin));
    expect(c.walkPhase, 0);
    final still = c.avatar;
    expect(c.avatar, same(still));
    c.advanceCamera(
      CafeCamera(position: origin + const CafePoint(.1, 0, 0)),
      dt: .1,
      walking: true,
    );
    expect(c.walkPhase, closeTo(.1 * 2 * math.pi / CafeBody.gaitLength, 1e-8));
    c.stopWalking();
    expect(c.avatar.stride, 0);
    expect(
      c.avatar.faces
          .where((f) => f.part == 'shoe.sole')
          .expand((f) => f.points)
          .map((p) => p.y)
          .reduce(math.min),
      greaterThanOrEqualTo(0),
    );
  });
  test(
    'Following camera remains inside both rooms; lens picking round trips',
    () {
      final c = CafeViewController();
      addTearDown(c.dispose);
      for (final garden in [false, true]) {
        c.inCourtyard = garden;
        for (final target in c.world.targets) {
          for (final yaw in [-math.pi, -1.0, 0.0, 1.0, math.pi]) {
            c.updateCamera(
              CafeCamera(position: c.world.targetApproach(target), yaw: yaw),
            );
            final observer = c.viewCamera;
            expect(observer.isFinite, isTrue);
            expect(cafeCameraWithinRoom(c.world, observer.position), isTrue);
            const size = Size(390, 844);
            final p =
                observer.position + observer.forward * 2 + observer.right * .2;
            final screen = CafeRenderer.project(p, observer, size)!;
            final ray = CafeRenderer.ray(screen, observer, size);
            expect(
              ray.dot((p - observer.position).normalized),
              closeTo(1, 1e-9),
            );
          }
        }
      }
    },
  );
  test(
    'Cup and open book remain in world depth at the same hand anchor',
    () async {
      final c = CafeViewController(seat: CafeSeat.shared);
      addTearDown(c.dispose);
      final original = c.space.toJson();
      final volume = c.world.objects.values
          .firstWhere((o) => o.type == CafeItemType.volume)
          .id;
      for (final id in ['shared.cup', volume]) {
        final done = c.performUse(id, CafeUseKind.pickUp);
        c.advanceUse(.5);
        expect(
          c.avatar.faces.every((f) => f.points.every((p) => p.isFinite)),
          isTrue,
        );
        c.advanceUse(1);
        c.finishUse();
        expect(await done, isTrue);
        final presented = c.world
            .presentedFaces(c.actorCamera, c.useFrame, thirdPerson: true)
            .where((f) => f.objectId == id);
        expect(presented, isNotEmpty);
        expect(presented.any((f) => f.layer == 5), isFalse);
        final anchor = cafeHeldPoint(
          c.actorCamera,
          c.world.objects[id]!.type,
          c.useFrame!,
          thirdPerson: true,
        );
        expect(
          presented
              .expand((f) => f.points)
              .any((p) => (p - anchor).length < .2),
          isTrue,
        );
        if (id == volume) {
          final opening = c.performUse(id, CafeUseKind.open);
          c.advanceUse(.5);
          final openFaces = c.world
              .presentedFaces(c.actorCamera, c.useFrame, thirdPerson: true)
              .where((f) => f.objectId == id)
              .toList();
          expect(openFaces, isNotEmpty);
          expect(
            openFaces.every(
              (f) => f.layer == 2 && f.points.every((p) => p.isFinite),
            ),
            isTrue,
          );
          c.finishUse();
          expect(await opening, isTrue);
        }
        final body = c.bodyYaw;
        c.look(.4, 0);
        expect(c.bodyYaw, body);
        expect(c.actorCamera.yaw, body);
        c.cancelUse();
      }
      expect(c.space.toJson(), original);
    },
  );
}
