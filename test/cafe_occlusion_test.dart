import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_renderer.dart';
import 'package:writing_human/cafe/cafe_world.dart';

void main() {
  testWidgets('Intersecting surfaces agree with the nearest physical hit', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final world = CafeWorld();
      world.faces.clear();
      world.linkedWorld.faces.clear();
      world.pendantLights.clear();
      world.pendantGains.clear();
      world.faces.addAll([
        CafeFace(
          [
            const CafePoint(-1, -1, -2),
            const CafePoint(1, -1, -2),
            const CafePoint(1, 1, -2),
            const CafePoint(-1, 1, -2),
          ],
          const ui.Color(0xffff0000),
          objectId: 'red',
          unlit: true,
        ),
        CafeFace(
          [
            const CafePoint(-1, -1, -1.4),
            const CafePoint(1, -1, -2.6),
            const CafePoint(1, 1, -2.6),
            const CafePoint(-1, 1, -1.4),
          ],
          const ui.Color(0xff0000ff),
          objectId: 'blue',
          unlit: true,
        ),
      ]);
      const size = ui.Size(240, 400);
      const camera = CafeCamera(position: CafePoint(0, 0, 0), pitch: 0);
      final recorder = ui.PictureRecorder();
      CafeRenderer(
        world: world,
        camera: camera,
        allowPortal: false,
      ).paint(ui.Canvas(recorder), size);
      final picture = recorder.endRecording();
      final image = await picture.toImage(240, 400);
      try {
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        for (final x in [65, 90, 150, 175]) {
          final hit = CafeRenderer.pick(
            ui.Offset(x.toDouble(), 200),
            camera,
            size,
            world,
          )!;
          final index = (200 * 240 + x) * 4;
          expect(bytes[index], hit.objectId == 'red' ? 255 : 0);
          expect(bytes[index + 2], hit.objectId == 'blue' ? 255 : 0);
        }
      } finally {
        image.dispose();
        picture.dispose();
      }
    });
  });

  testWidgets('A paper stays above its long support from both ends and sides', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final world = CafeWorld();
      world.faces.clear();
      world.linkedWorld.faces.clear();
      world.pendantLights.clear();
      world.pendantGains.clear();
      world.faces.addAll([
        CafeFace(
          [
            const CafePoint(-1, .9, 1),
            const CafePoint(1, .9, 1),
            const CafePoint(1, .9, -1),
            const CafePoint(-1, .9, -1),
          ],
          const ui.Color(0xffa13216),
          unlit: true,
        ),
        CafeFace(
          [
            const CafePoint(-.24, .94, -.55),
            const CafePoint(.24, .94, -.55),
            const CafePoint(.24, .94, -.95),
            const CafePoint(-.24, .94, -.95),
          ],
          const ui.Color(0xffeeeeee),
          unlit: true,
        ),
      ]);
      const size = ui.Size(240, 400);
      for (final angle in [0.0, .5, 1.2, math.pi, -1.1]) {
        final camera = CafeCamera(
          position: CafePoint(math.sin(angle) * 2, 1.62, math.cos(angle) * 2),
          yaw: -angle,
          pitch: -.42,
        );
        final recorder = ui.PictureRecorder();
        CafeRenderer(
          world: world,
          camera: camera,
          allowPortal: false,
        ).paint(ui.Canvas(recorder), size);
        final picture = recorder.endRecording();
        final image = await picture.toImage(240, 400);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        try {
          for (final x in [-.16, 0.0, .16]) {
            for (final z in [-.62, -.75, -.88]) {
              final point = CafeRenderer.project(
                CafePoint(x, .94, z),
                camera,
                size,
              )!;
              if (!(ui.Offset.zero & size).deflate(2).contains(point)) continue;
              final i = (point.dy.round() * 240 + point.dx.round()) * 4;
              expect(
                bytes[i],
                greaterThan(225),
                reason: 'angle=$angle x=$x z=$z',
              );
              expect(bytes[i + 1], greaterThan(225));
              expect(bytes[i + 2], greaterThan(225));
            }
          }
        } finally {
          image.dispose();
          picture.dispose();
        }
      }
    });
  });
}
