import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_renderer.dart';
import 'package:writing_human/cafe/cafe_world.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Repeated camera paints keep their source images alive',
    () async {
      // An embedded PNG avoids the browser widget-test asset messenger. The test
      // exercises the real CanvasKit image/shader APIs, without UI automation.
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAYAAACp8Z5+AAAAFUlEQVR4nGPct6DiPwMSYGJAA4QFALqGAt3Gl4wfAAAAAElFTkSuQmCC',
      );
      Future<ui.Image> texture() async {
        final codec = await ui.instantiateImageCodec(png);
        final image = (await codec.getNextFrame()).image;
        codec.dispose();
        return image;
      }

      final wood = await texture(),
          garden = await texture(),
          sign = await texture();
      final originals = [wood, garden, sign];
      final world = CafeWorld();
      try {
        for (var frame = 0; frame < 24; frame++) {
          final recorder = ui.PictureRecorder();
          CafeRenderer(
            world: world,
            wood: wood,
            garden: garden,
            sign: sign,
            camera: CafeCamera(
              position: frame < 12
                  ? CafeCamera.entrance.position
                  : const CafePoint(2.85, 1.62, .3),
              yaw: (frame % 12) * math.pi / 6,
              pitch: -.18,
            ),
          ).paint(ui.Canvas(recorder), const ui.Size(240, 400));
          final picture = recorder.endRecording();
          try {
            for (final original in originals) {
              expect(
                original.debugDisposed,
                isFalse,
                reason: 'scene image closed by paint $frame',
              );
              final retained = original.clone();
              retained.dispose();
            }
            final image = await picture.toImage(240, 400);
            final pixels = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List();
            var visible = 0, samples = 0;
            for (var y = 80; y < 320; y += 16) {
              for (var x = 48; x < 192; x += 16) {
                final i = (y * 240 + x) * 4;
                final difference =
                    (pixels[i] - 243).abs() +
                    (pixels[i + 1] - 234).abs() +
                    (pixels[i + 2] - 219).abs();
                if (difference > 45) visible++;
                samples++;
              }
            }
            expect(
              visible / samples,
              greaterThan(.65),
              reason: 'blank room at frame $frame',
            );
            image.dispose();
          } finally {
            picture.dispose();
          }
        }
      } finally {
        for (final original in originals) {
          if (!original.debugDisposed) original.dispose();
        }
      }
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );
}
