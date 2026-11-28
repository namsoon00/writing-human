import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:writing_human/cafe/cafe_renderer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_avatar.dart';
import 'package:writing_human/cafe/cafe_view_controller.dart';
import 'package:writing_human/cafe/cafe_visit.dart';
import 'package:writing_human/cafe/cafe_world.dart';
import 'package:writing_human/cafe/cafe_yard.dart';

void finish(CafeViewController c) {
  c.updateCamera(c.destination!);
  c.finishTravel();
}

CafeViewController enter() {
  final c = CafeViewController();
  expect(c.visit(CafeTarget.courtyard), isTrue);
  finish(c);
  return c;
}

void main() {
  test('Natural banks stay low, clear and within a fixed geometry budget', () {
    final yard = CafeWorld(courtyard: true);
    final wall = yard.faces
        .where((f) => f.part?.startsWith('yard.wall.') == true)
        .toList();
    expect(wall, isNotEmpty);
    expect(wall.any((f) => f.surface == CafeSurface.fieldstone), isTrue);
    expect(
      wall.expand((f) => f.points).map((p) => p.y).reduce(math.max),
      closeTo(CafeYard.wallHeight, .001),
    );
    expect(
      wall.any(
        (f) =>
            f.surface == CafeSurface.plaster && f.points.any((p) => p.y > .7),
      ),
      isFalse,
    );
    expect(yard.faces.length, lessThan(35000));
    for (final f in yard.faces) {
      expect(f.normal.isFinite && f.points.every((p) => p.isFinite), isTrue);
    }
    final blades = yard.faces
        .where((f) => f.part == 'yard.grass.blade')
        .toList();
    expect(blades.length, inInclusiveRange(400, 1200));
    for (final f in blades) {
      expect(CafeYard.distanceToTrail(f.center), greaterThan(.66));
      expect(CafeYard.distanceToStone(f.center), greaterThan(.78));
    }
    expect(
      yard.faces
          .where((f) => f.part == 'yard.earth')
          .every((f) => f.surface == CafeSurface.earth),
      isTrue,
    );
  });

  test('Fine grass does not intercept walking clicks', () {
    final yard = CafeWorld(courtyard: true);
    final blade = yard.faces.firstWhere(
      (f) =>
          f.part == 'yard.grass.blade' &&
          yard.canStand(CafePoint(f.center.x, 1.62, f.center.z)),
    );
    final aim = blade.center;
    final camera = CafeCamera(
      position: aim + const CafePoint(0, .6, .6),
      pitch: -math.pi / 4,
    );
    final hit = CafeRenderer.pick(
      const ui.Offset(200, 200),
      camera,
      const ui.Size(400, 400),
      yard,
    );
    expect(hit, isNotNull);
    expect(hit!.floor, isTrue);
    expect(hit.position.y, lessThan(.03));
  });

  test(
    'The sustained earthen loop closes inside the enclosure and stays clear',
    () {
      final yard = CafeWorld(courtyard: true);
      expect(CafeYard.bounds.width, greaterThanOrEqualTo(30));
      expect(CafeYard.length, inInclusiveRange(50, 90));
      expect(
        (CafeYard.trail.first - CafeYard.trail.last).length,
        lessThan(1e-9),
      );
      for (var i = 0; i < CafeYard.trail.length; i++) {
        final p = CafeYard.trail[i];
        expect(
          yard.canStand(CafePoint(p.x, 1.62, p.z)),
          isTrue,
          reason: 'trail $i at ${p.x},${p.z}',
        );
        if (i > 0) {
          expect(
            yard.clearSegment(CafeYard.trail[i - 1], p),
            isTrue,
            reason: 'trail segment $i',
          );
        }
      }
      for (final face in yard.faces.where((f) => f.part == 'yard.earth')) {
        for (final p in face.points) {
          expect(p.x, inInclusiveRange(-22.2, 8.2));
          expect(p.z, inInclusiveRange(-21.2, 3.165));
        }
      }
      expect(yard.canStand(const CafePoint(-6, 1.62, -21.4)), isFalse);
      expect(yard.faces.length, lessThan(35000));
    },
  );

  test(
    'Cafe access, resting places and longer detours share the same collision model',
    () {
      final yard = CafeWorld(courtyard: true);
      expect(yard.validateLayout(), isNull);
      for (final p in CafeYard.stone) {
        expect(
          yard.canStand(CafePoint(p.x, 1.62, p.z)),
          isTrue,
          reason: 'direct path ${p.x},${p.z}',
        );
      }
      for (final t in [
        CafeTarget.meditation,
        CafeTarget.trailRest,
        CafeTarget.barefoot,
        CafeTarget.trail,
        CafeTarget.cafeReturn,
      ]) {
        final path = yard.path(CafeYard.gate, yard.targetApproach(t));
        expect(path, isNotEmpty, reason: t.name);
        var start = CafeYard.gate;
        for (final p in path) {
          expect(yard.clearSegment(start, p), isTrue);
          start = p;
        }
      }
    },
  );

  test(
    'Meditation lowers and folds the avatar; standing returns to clear ground',
    () {
      final c = enter();
      addTearDown(c.dispose);
      final room = c.space.encode();
      expect(c.visit(CafeTarget.meditation), isTrue);
      finish(c);
      expect(c.resting, isTrue);
      expect(c.meditating, isTrue);
      expect(c.avatar.meditation, closeTo(1, 1e-8));
      expect(c.avatar.faces.any((f) => f.part == 'foot.toe'), isTrue);
      expect(
        c.avatar.faces.any((f) => f.part?.startsWith('shoe') == true),
        isFalse,
      );
      final head = c.avatar.faces
          .where((f) => f.part == 'face')
          .expand((f) => f.points);
      expect(head.map((p) => p.y).reduce(math.max), lessThan(1.2));
      c.stand();
      finish(c);
      expect(c.resting, isFalse);
      expect(c.meditating, isFalse);
      expect(c.world.canStand(c.camera.position), isTrue);
      expect(c.avatar.meditation, 0);
      expect(c.space.encode(), room);
    },
  );

  test(
    'Barefoot appearance is reversible session state, separate from saved items',
    () {
      final c = enter();
      addTearDown(c.dispose);
      final saved = c.space.encode();
      c.toggleBarefoot();
      expect(c.barefoot, isTrue);
      expect(c.avatar.faces.any((f) => f.part == 'foot'), isTrue);
      expect(c.avatar.faces.any((f) => f.part == 'shoe.sole'), isFalse);
      c.toggleBarefoot();
      expect(c.avatar.faces.any((f) => f.part == 'shoe.sole'), isTrue);
      expect(c.space.encode(), saved);
    },
  );

  test(
    'A complete stroll follows clear loop segments and can be interrupted by looking',
    () {
      final c = enter();
      addTearDown(c.dispose);
      expect(c.startStroll(), isTrue);
      expect(c.strolling, isTrue);
      expect(c.journey.length, greaterThan(60));
      var start = c.world.targetApproach(CafeTarget.cafeReturn);
      for (final frame in c.journey) {
        expect(c.world.clearSegment(start, frame.position), isTrue);
        start = frame.position;
      }
      final future = c.travelFinished;
      c.look(.1, 0);
      expect(c.strolling, isFalse);
      expect(c.travelling, isFalse);
      expect(future, completion(isFalse));
      expect(c.startStroll(), isTrue);
      finish(c);
      expect(c.strolling, isFalse);
      expect(c.world.canStand(c.camera.position), isTrue);
    },
  );

  test(
    'Folded poses and bare feet remain finite throughout the seating transition',
    () {
      for (final amount in [0.0, .2, .5, .8, 1.0]) {
        final a = CafeAvatar(
          eye: const CafeCamera(position: CafePoint(0, 1.3, 0)),
          yaw: .5,
          meditation: amount,
          barefoot: true,
        );
        expect(
          a.faces.every(
            (f) => f.points.every((p) => p.isFinite) && f.normal.isFinite,
          ),
          isTrue,
        );
      }
    },
  );
}
