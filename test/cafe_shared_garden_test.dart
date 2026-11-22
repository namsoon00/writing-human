import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_renderer.dart';
import 'package:writing_human/cafe/cafe_view_controller.dart';
import 'package:writing_human/cafe/cafe_visit.dart';
import 'package:writing_human/cafe/cafe_world.dart';

Future<ui.Image> render(
  CafeWorld world,
  CafeCamera camera,
  double time, {
  bool portal = true,
}) async {
  final recorder = ui.PictureRecorder();
  CafeRenderer(
    world: world,
    camera: camera,
    time: time,
    allowPortal: portal,
  ).paint(ui.Canvas(recorder), const ui.Size(800, 600));
  final picture = recorder.endRecording();
  final image = await picture.toImage(800, 600);
  picture.dispose();
  return image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Entering the garden visits the exact world seen through the windows',
    () {
      final c = CafeViewController();
      addTearDown(c.dispose);
      final cafe = c.world, garden = c.world.linkedWorld;
      expect(garden.courtyard, isTrue);
      expect(identical(garden.linkedWorld, cafe), isTrue);
      final eye = CafeCamera.seated(CafeSeat.window);
      final roundTrip = garden.linkedCamera(cafe.linkedCamera(eye));
      expect((roundTrip.position - eye.position).length, lessThan(1e-9));
      expect((roundTrip.forward - eye.forward).length, lessThan(1e-9));
      expect(c.visit(CafeTarget.courtyard), isTrue);
      c.updateCamera(c.destination!);
      c.finishTravel();
      expect(identical(c.world, garden), isTrue);
      expect(c.world.canStand(c.camera.position), isTrue);
      expect(c.visit(CafeTarget.cafeReturn), isTrue);
      c.updateCamera(c.destination!);
      c.finishTravel();
      expect(identical(c.world, cafe), isTrue);
      expect(c.world.canStand(c.camera.position), isTrue);
    },
  );

  test(
    'A visible pond patch matches its direct garden render at two times',
    () async {
      final cafe = CafeWorld();
      const camera = CafeCamera(
        position: CafePoint(-3, 1.18, 1.9),
        yaw: -1.57079632679,
        pitch: -.10,
      );
      final outsideCamera = cafe.linkedCamera(camera);
      final point = CafeRenderer.project(
        const CafePoint(-.9, .13, 1.0),
        outsideCamera,
        const ui.Size(800, 600),
      )!;
      for (final time in [0.0, 2.0]) {
        final inside = await render(cafe, camera, time);
        final outside = await render(
          cafe.linkedWorld,
          outsideCamera,
          time,
          portal: false,
        );
        try {
          final a = (await inside.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          final b = (await outside.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          var matches = 0, count = 0;
          for (var dy = -5; dy <= 5; dy++) {
            for (var dx = -12; dx <= 12; dx++) {
              final i =
                  ((point.dy.round() + dy) * 800 + point.dx.round() + dx) * 4;
              final delta =
                  (a[i] - b[i]).abs() +
                  (a[i + 1] - b[i + 1]).abs() +
                  (a[i + 2] - b[i + 2]).abs();
              if (delta < 15) matches++;
              count++;
            }
          }
          expect(
            matches / count,
            greaterThan(.9),
            reason: 'window must show the same pond at time=$time',
          );
        } finally {
          inside.dispose();
          outside.dispose();
        }
      }
    },
  );

  test('Low garden stepping stones remain directly walkable', () {
    final world = CafeWorld(courtyard: true);
    const camera = CafeCamera(position: CafePoint(1.2, 1.62, 2.2), pitch: -.5);
    const size = ui.Size(800, 600);
    final pixel = CafeRenderer.project(
      const CafePoint(1.2, .028, 1.15),
      camera,
      size,
    )!;
    final hit = CafeRenderer.pick(pixel, camera, size, world)!;
    expect(hit.floor, isTrue);
    expect(hit.position.y, closeTo(.028, .002));
  });
}
