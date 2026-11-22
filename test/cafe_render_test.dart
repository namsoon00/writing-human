import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_renderer.dart';
import 'package:writing_human/cafe/cafe_world.dart';

void main() {
  testWidgets(
    'Bundled textures render through repeated phone-sized rotations',
    (tester) async {
      await tester.runAsync(() async {
        Future<ui.Image> texture(String path) async {
          final data = await rootBundle.load(path);
          final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(),
            targetWidth: 384,
          );
          final image = (await codec.getNextFrame()).image;
          codec.dispose();
          return image;
        }

        final wood = await texture('assets/images/cafe-oak-albedo.png');
        final garden = await texture('assets/images/cafe-garden-view.png');
        final world = CafeWorld();
        const size = ui.Size(240, 400);
        try {
          for (final position in [
            CafeCamera.entrance.position,
            const CafePoint(2.85, 1.62, .3),
          ]) {
            for (final pitch in [-.72, -.10, .65]) {
              for (var turn = 0; turn < 12; turn++) {
                final recorder = ui.PictureRecorder();
                final painter = CafeRenderer(
                  world: world,
                  wood: wood,
                  garden: garden,
                  camera: CafeCamera(
                    position: position,
                    yaw: turn * math.pi / 6,
                    pitch: pitch,
                  ),
                );
                painter.paint(ui.Canvas(recorder), size);
                final picture = recorder.endRecording();
                final image = await picture.toImage(240, 400);
                final bytes = (await image.toByteData(
                  format: ui.ImageByteFormat.rawRgba,
                ))!.buffer.asUint8List();
                var visible = 0, samples = 0;
                // Exclude the outer vignette, and compare against the empty renderer
                // background. No app labels can disguise a blank 3D room here.
                for (var y = 80; y < 320; y += 8) {
                  for (var x = 48; x < 192; x += 8) {
                    final i = (y * 240 + x) * 4;
                    final delta =
                        (bytes[i] - 201).abs() +
                        (bytes[i + 1] - 188).abs() +
                        (bytes[i + 2] - 165).abs();
                    if (delta > 45) visible++;
                    samples++;
                  }
                }
                expect(
                  visible / samples,
                  greaterThan(.65),
                  reason: 'yaw=$turn pitch=$pitch x=${position.x}',
                );
                image.dispose();
                picture.dispose();
              }
            }
          }
        } finally {
          wood.dispose();
          garden.dispose();
        }
      });
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
