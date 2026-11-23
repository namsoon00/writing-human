import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_materials.dart';
import 'package:writing_human/cafe/cafe_watercolor.dart';
import 'package:writing_human/cafe/cafe_renderer.dart';
import 'package:writing_human/cafe/cafe_world.dart';
import 'package:writing_human/cafe/cafe_visit.dart';

void main() {
  testWidgets(
    'Watercolor materials render through repeated phone-sized rotations',
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

        Future<ui.Image> timber({bool walnut = false}) async {
          final source = await texture(
            'assets/images/cafe-watercolor-oak.webp',
          );
          try {
            return await CafeWatercolor.timber(source, walnut: walnut);
          } finally {
            source.dispose();
          }
        }

        final wood = await timber();
        final walnut = await timber(walnut: true);
        final limestone = await CafeWatercolor.stone();
        final plaster = await CafeWatercolor.plaster();
        final artwork = await CafeMaterials.artwork();
        final gravel = await CafeWatercolor.gravel();
        final tree = await texture('assets/images/cafe-watercolor-tree.webp');
        final flowers = await texture(
          'assets/images/cafe-watercolor-flowers.webp',
        );
        final framedArt = [
          await texture('assets/images/cafe-art-botanical.webp'),
          await texture('assets/images/cafe-art-pond.webp'),
          await texture('assets/images/cafe-art-book.webp'),
        ];
        final world = CafeWorld();
        const size = ui.Size(240, 400);
        try {
          for (final position in [
            CafeCamera.entrance.position,
            const CafePoint(2.85, 1.62, .3),
            CafeCamera.seated(CafeSeat.window).position,
            CafeCamera.seated(CafeSeat.windowMiddle).position,
            CafeCamera.seated(CafeSeat.windowRear).position,
          ]) {
            for (final pitch in [-.72, -.10, .65]) {
              for (var turn = 0; turn < 12; turn++) {
                final recorder = ui.PictureRecorder();
                final painter = CafeRenderer(
                  world: world,
                  wood: wood,
                  walnut: walnut,
                  limestone: limestone,
                  plaster: plaster,
                  artwork: artwork,
                  gravel: gravel,
                  tree: tree,
                  flowers: flowers,
                  framedArt: framedArt,
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
                // background. Ivory surfaces may be close in tone, so a small RGB
                // difference still counts; labels cannot disguise a blank room.
                for (var y = 80; y < 320; y += 8) {
                  for (var x = 48; x < 192; x += 8) {
                    final i = (y * 240 + x) * 4;
                    final delta =
                        (bytes[i] - 243).abs() +
                        (bytes[i + 1] - 234).abs() +
                        (bytes[i + 2] - 219).abs();
                    if (delta > 12) visible++;
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
          walnut.dispose();
          limestone.dispose();
          plaster.dispose();
          artwork.dispose();
          gravel.dispose();
          tree.dispose();
          flowers.dispose();
          for (final image in framedArt) {
            image.dispose();
          }
        }
      });
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
