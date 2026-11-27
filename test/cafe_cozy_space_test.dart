import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_avatar.dart';
import 'package:writing_human/cafe/cafe_renderer.dart';
import 'package:writing_human/cafe/cafe_view_controller.dart';
import 'package:writing_human/cafe/cafe_visit.dart';
import 'package:writing_human/cafe/cafe_world.dart';
import 'package:writing_human/cafe/cafe_yard.dart';

void main() {
  test('A planted short foot holds its ground through the stance phase', () {
    double? planted;
    for (final t in [0.0, .15, .30, .45, .59]) {
      final a = CafeAvatar(
        eye: CafeCamera(position: CafePoint(0, 1.62, -.48 * t)),
        yaw: 0,
        stride: 1,
        phase: t * 2 * math.pi,
      );
      final foot = a.faces
          .where((f) => f.part == 'shoe.sole')
          .expand((f) => f.points)
          .where((p) => p.x > 0)
          .toList();
      final z = foot.map((p) => p.z).reduce((a, b) => a + b) / foot.length;
      planted ??= z;
      expect(z, closeTo(planted, 1e-8));
      expect(foot.map((p) => p.y).reduce(math.min), greaterThanOrEqualTo(0));
    }
  });
  test(
    'Arriving across the bay does not turn a floor tap into a return trip',
    () {
      final c = CafeViewController();
      addTearDown(c.dispose);
      const size = Size(390, 844);
      for (var trip = 0; trip < 3; trip++) {
        expect(c.visit(CafeTarget.courtyard), isTrue);
        c.updateCamera(c.destination!);
        c.finishTravel();
        expect(c.inCourtyard, isTrue);
        final observer = c.viewCamera;
        expect(observer.position.z, greaterThan(3.16));
        // The arrival slab is floor as well, not a return button underfoot.
        for (final point in const [
          CafePoint(1.1, .018, 2.5),
          CafePoint(-.5, .018, 2.5),
        ]) {
          expect(c.world.canStand(point), isTrue);
          final landing = CafeRenderer.project(point, observer, size)!;
          final landingHit = CafeRenderer.pick(
            landing,
            observer,
            size,
            c.world,
            useCamera: c.actorCamera,
          );
          expect(
            landingHit?.floor,
            isTrue,
            reason:
                'trip=$trip point=${point.x},${point.z} hit=${landingHit?.position.x},${landingHit?.position.y},${landingHit?.position.z} target=${landingHit?.target} stand=${landingHit == null ? null : c.world.canStand(landingHit.position)}',
          );
          expect(landingHit?.target, isNull);
        }
        final floor = CafeRenderer.project(
          const CafePoint(0, .014, -.5),
          observer,
          size,
        )!;
        final hit = CafeRenderer.pick(
          floor,
          observer,
          size,
          c.world,
          useCamera: c.actorCamera,
        );
        expect(hit?.floor, isTrue);
        expect(hit?.target, isNot(CafeTarget.cafeReturn));
        expect(c.walkTo(hit!.position), isTrue);
        c.updateCamera(c.destination!);
        c.finishTravel();
        expect(c.inCourtyard, isTrue);
        // The explicit return remains available, including after another visit.
        expect(c.visit(CafeTarget.cafeReturn), isTrue);
        c.updateCamera(c.destination!);
        c.finishTravel();
        expect(c.inCourtyard, isFalse);
        final inner = c.viewCamera;
        final inside = CafeRenderer.project(
          const CafePoint(0, .001, 0),
          inner,
          size,
        )!;
        expect(
          CafeRenderer.pick(
            inside,
            inner,
            size,
            c.world,
            useCamera: c.actorCamera,
          )?.floor,
          isTrue,
        );
      }
    },
  );
  test('Both hands follow the held mug through lift, sip and lowering', () {
    final c = CafeViewController(seat: CafeSeat.shared);
    addTearDown(c.dispose);
    final saved = c.space.encode();
    final pickup = c.performUse('shared.cup', CafeUseKind.pickUp);
    c.advanceUse(1);
    c.finishUse();
    expect(pickup, completion(isTrue));
    for (final kind in [
      CafeUseKind.hold,
      CafeUseKind.sip,
      CafeUseKind.putDown,
    ]) {
      for (final t in [0.0, .25, .5, .75, 1.0]) {
        final frame = CafeUseFrame('shared.cup', kind, held: true, progress: t);
        final a = CafeAvatar(
          eye: c.actorCamera,
          yaw: c.bodyYaw,
          use: frame,
          object: c.world.objects['shared.cup'],
        );
        final palms = a.faces
            .where((f) => f.part == 'hand')
            .expand((f) => f.points)
            .toList();
        expect(palms.every((p) => p.isFinite), isTrue);
        if (kind != CafeUseKind.putDown) {
          final anchor = cafeHeldPoint(
            c.actorCamera,
            CafeItemType.cup,
            frame,
            thirdPerson: true,
          );
          for (final s in [-1.0, 1.0]) {
            final side = palms.where(
              (p) =>
                  (p - c.actorCamera.position).dot(c.actorCamera.right) * s > 0,
            );
            expect(side, isNotEmpty);
            expect(
              side.map((p) => (p - anchor).length).reduce(math.min),
              lessThan(.16),
            );
          }
        }
      }
    }
    expect(c.space.encode(), saved);
  });
  test('Enclosure expands around existing calm places and remains bounded', () {
    final yard = CafeWorld(courtyard: true);
    expect(CafeYard.bounds.width * CafeYard.bounds.height, greaterThan(700));
    expect(yard.faces.where((f) => f.part == 'yard.wall.plaster').length, 6);
    expect(yard.canStand(const CafePoint(-20, 1.62, -18)), isTrue);
    expect(yard.canStand(const CafePoint(-22.4, 1.62, -18)), isFalse);
    expect(yard.validateLayout(), isNull);
    expect(yard.faces.length, lessThan(35000));
  });
}
