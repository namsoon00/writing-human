import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_renderer.dart';
import 'package:writing_human/cafe/cafe_view_controller.dart';
import 'package:writing_human/cafe/cafe_visit.dart';
import 'package:writing_human/cafe/cafe_world.dart';

void main() {
  test('GPU batches retain shared world coordinates, IDs and saved values', () {
    final c = CafeViewController();
    addTearDown(c.dispose);
    final saved = c.space.encode();
    final g = CafeGpuGeometry(
      CafeRenderer(
        world: c.world,
        camera: c.viewCamera,
        avatar: c.avatar.faces,
      ),
    );
    final batches = g.staticBatches();
    expect(batches, isNotEmpty);
    for (final b in batches) {
      expect(b.values.length % 48, 0);
      expect(b.values.every((v) => v.isFinite), isTrue);
    }
    expect(g.id('shared.cup'), greaterThan(0));
    final dynamic = g.moving(
      CafeRenderer(
        world: c.world,
        camera: c.viewCamera,
        avatar: c.avatar.faces,
      ),
    );
    for (final b in dynamic) {
      for (var i = 13; i < b.values.length; i += 16) {
        expect(
          b.values[i],
          0,
          reason: 'Held geometry is not hidden with its static original',
        );
      }
    }
    final p = const CafePoint(1, 2, 3);
    final linked = c.world.linkedCamera(
      const CafeCamera(position: CafePoint(1, 2, 3)),
    );
    final back = g.transform(linked.position, 1);
    expect((back - p).length, lessThan(1e-9));
    expect(c.space.encode(), saved);
  });
  test(
    'A held cup eases the observer beside the shoulder without turning the person',
    () {
      final c = CafeViewController(seat: CafeSeat.shared);
      addTearDown(c.dispose);
      final before = c.viewCamera, body = c.bodyYaw;
      c.performUse('shared.cup', CafeUseKind.pickUp);
      c.advanceUse(.5);
      final halfway = c.viewCamera;
      c.advanceUse(1);
      c.finishUse();
      final held = c.viewCamera;
      expect((halfway.position - before.position).length, greaterThan(.05));
      expect((held.position - before.position).length, greaterThan(.10));
      expect(c.bodyYaw, body);
      expect(held.isFinite, isTrue);
    },
  );
  test(
    'Low shoe benches do not collapse the orbit into a distorted close-up',
    () {
      final c = CafeViewController()..inCourtyard = true;
      addTearDown(c.dispose);
      c.updateCamera(
        const CafeCamera(position: CafePoint(-3, 1.62, -12.6), yaw: math.pi),
      );
      final eye = c.viewCamera;
      expect((eye.position - c.camera.position).length, greaterThan(1.8));
      expect(eye.lens, greaterThan(.65));
    },
  );
  test(
    'Neutral legs are almost straight and fingers hang along relaxed forearms',
    () {
      final c = CafeViewController();
      addTearDown(c.dispose);
      final body = c.avatar;
      final knee = body.faces
          .where((f) => f.part == 'trousers')
          .expand((f) => f.points)
          .where((p) => p.y > .25 && p.y < .35)
          .toList();
      final origin = c.camera.position;
      final forward = CafePoint(math.sin(c.bodyYaw), 0, -math.cos(c.bodyYaw));
      expect(
        knee.map((p) => (p - origin).dot(forward)).reduce(math.max),
        lessThan(.13),
      );
      final fingers = body.faces
          .where((f) => f.part == 'finger')
          .expand((f) => f.points);
      expect(fingers.map((p) => p.y).reduce(math.max), lessThan(.87));
      expect(body.faces.any((f) => f.part == 'linen.shoulder'), isTrue);
      c.sit(CafeSeat.shared);
      c.updateCamera(c.destination!);
      c.finishTravel();
      expect(
        c.avatar.faces.every((f) => f.points.every((p) => p.isFinite)),
        isTrue,
      );
    },
  );
}
