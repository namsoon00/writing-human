import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_renderer.dart';
import 'package:writing_human/cafe/cafe_world.dart';
import 'package:writing_human/cafe/cafe_space.dart';
import 'package:writing_human/cafe/cafe_visit.dart';

void main() {
  test(
    'The old street exit is absent and the veranda stays physically open for legacy rooms',
    () {
      for (final open in [false, true]) {
        final room = CafeWorld(space: CafeSpace(doorOpen: open));
        expect(room.targets.any((t) => t.label == '출입문'), isFalse);
        expect(room.objects.containsKey('garden.door'), isFalse);
        final eye = CafeCamera(
          position: const CafePoint(-2, 1.62, 0),
          yaw: -math.pi / 2,
        );
        const size = Size(390, 844);
        final p = CafeRenderer.project(
          const CafePoint(-4.19, 1.35, 0),
          eye,
          size,
        )!;
        expect(
          CafeRenderer.pick(p, eye, size, room)?.target,
          CafeTarget.courtyard,
        );
        final yard = room.linkedWorld;
        const outside = CafeCamera(
          position: CafePoint(0, 1.62, 1.7),
          yaw: math.pi,
        );
        final back = CafeRenderer.project(
          const CafePoint(0, 1.35, 3.16),
          outside,
          size,
        )!;
        expect(
          CafeRenderer.pick(back, outside, size, yard)?.target,
          CafeTarget.cafeReturn,
        );
        expect(yard.validateLayout(), isNull);
        expect(
          room.space.doorOpen,
          open,
          reason: 'Legacy saved choices are retained without reviving a door',
        );
      }
    },
  );
  test(
    'The open bay is centered and wider than four metres and has no opaque lower wall across it',
    () {
      final yard = CafeWorld(courtyard: true);
      final bay = yard.faces.singleWhere(
        (f) => f.garden && f.target == CafeTarget.cafeReturn,
      );
      final xs = bay.points.map((p) => p.x);
      expect(xs.reduce(math.max) - xs.reduce(math.min), greaterThan(4.0));
      for (final face in yard.faces.where(
        (f) => !f.garden && f.color.a > .99,
      )) {
        if (face.points.every((p) => (p.z - 3.165).abs() < .001)) {
          expect(
            face.points.any((p) => p.x > -2.09 && p.x < 2.09 && p.y < .6),
            isFalse,
          );
        }
      }
    },
  );
}
