// Relative native CPU paint measurements, not device FPS.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_renderer.dart';
import 'package:writing_human/cafe/cafe_view_controller.dart';
import 'package:writing_human/cafe/cafe_watercolor.dart';
import 'package:writing_human/cafe/cafe_yard.dart';

void main() {
  test(
    'Record actual camera turns and walking with detailed and distance aware planting',
    () async {
      final tree = await CafeWatercolor.tree();
      final flowers = await CafeWatercolor.flowers();
      final rows = <Object>[];
      for (final detail in [false, true]) {
        for (final yard in [false, true]) {
          final c = CafeViewController()..inCourtyard = yard;
          if (yard) {
            c.updateCamera(
              const CafeCamera(
                position: CafeYard.gate,
                yaw: math.pi,
                pitch: -.1,
              ),
            );
          }
          for (var i = 0; i < 6; i++) {
            c.look(.035, 0);
            if (i >= 3) c.freeStep(0, .07, .1);
            final r = ui.PictureRecorder();
            final ticks = <Object>[];
            CafeRenderer(
              world: c.world,
              camera: c.viewCamera,
              avatar: c.avatar.faces,
              useCamera: c.actorCamera,
              tree: tree,
              flowers: flowers,
              detailCulling: detail,
              onTiming: (t) => ticks.add({
                'courtyard': t.courtyard,
                'projectUs': t.projectMicros,
                'orderUs': t.orderMicros,
                'submitUs': t.submitMicros,
                'linkedUs': t.linkedMicros,
                'visible': t.visibleFaces,
              }),
            ).paint(ui.Canvas(r), const ui.Size(390, 844));
            r.endRecording().dispose();
            rows.add({
              'detailCulling': detail,
              'yard': yard,
              'frame': i,
              'ticks': ticks,
            });
          }
          c.dispose();
        }
      }
      tree.dispose();
      flowers.dispose();
      final file = File('output/cafe-refinement-20261125/native-motion.json');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));
    },
  );
}
