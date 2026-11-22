import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_renderer.dart';
import 'package:writing_human/cafe/cafe_world.dart';
import 'package:writing_human/cafe/cafe_avatar.dart';
import 'package:writing_human/cafe/cafe_view_controller.dart';
import 'package:writing_human/cafe/cafe_visit.dart';

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
          sign = await texture(),
          walnut = await texture(),
          limestone = await texture(),
          woven = await texture();
      final originals = [wood, garden, sign, walnut, limestone, woven];
      final world = CafeWorld();
      final courtyard = CafeWorld(courtyard: true);
      final follow = CafeViewController();
      final gardenFollow = CafeViewController(seat: CafeSeat.garden);
      try {
        for (var frame = 0; frame < 24; frame++) {
          final controller = frame < 12 ? follow : gardenFollow;
          controller.updateCamera(
            CafeCamera(
              position: frame < 12
                  ? const CafePoint(2.8, 1.62, .3)
                  : const CafePoint(.4, 1.62, .2),
              yaw: (frame % 12) * math.pi / 6,
            ),
          );
          controller.setViewBlend(1);
          final recorder = ui.PictureRecorder();
          CafeRenderer(
            world: frame < 12 ? world : courtyard,
            time: frame.toDouble(),
            teaFilled: true,
            wood: wood,
            garden: garden,
            sign: sign,
            walnut: walnut,
            limestone: limestone,
            woven: woven,
            camera: controller.displayCamera,
            avatar: controller.showAvatar
                ? CafeAvatar(
                    position: controller.camera.position,
                    yaw: controller.bodyYaw,
                    gait: controller.gait,
                    speed: .8,
                  )
                : null,
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
        follow.dispose();
        gardenFollow.dispose();
        for (final original in originals) {
          if (!original.debugDisposed) original.dispose();
        }
      }
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );
}
