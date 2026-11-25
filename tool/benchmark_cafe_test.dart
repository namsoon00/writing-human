// Synthetic render CPU measurements, not physical-device FPS.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_renderer.dart';
import 'package:writing_human/cafe/cafe_view_controller.dart';
import 'package:writing_human/cafe/cafe_visit.dart';

void main() {
  test('Record projection, ordering and submission costs in the cafe', () {
    final samples = <Object>[];
    for (final seat in [null, CafeSeat.window, CafeSeat.shared]) {
      final c = CafeViewController(seat: seat);
      for (var frame = 0; frame < 3; frame++) {
        final recorder = ui.PictureRecorder();
        final timings = <Object>[];
        CafeRenderer(
          cacheGeometry: !const bool.fromEnvironment('CAFE_REFERENCE'),
          world: c.world,
          camera: c.viewCamera,
          avatar: c.avatar.faces,
          useCamera: c.actorCamera,
          onTiming: (t) => timings.add({
            'courtyard': t.courtyard,
            'cacheHit': t.cacheHit,
            'projectUs': t.projectMicros,
            'orderUs': t.orderMicros,
            'submitUs': t.submitMicros,
            'linkedUs': t.linkedMicros,
            'visible': t.visibleFaces,
            'ordered': t.orderedFaces,
          }),
        ).paint(ui.Canvas(recorder), const ui.Size(390, 844));
        recorder.endRecording().dispose();
        samples.add({
          'seat': seat?.name ?? 'entrance',
          'frame': frame,
          'timings': timings,
        });
      }
      c.dispose();
    }
    final file = File(
      'output/cafe-response-20261125/${const String.fromEnvironment('CAFE_BENCHMARK', defaultValue: 'current')}.json',
    );
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(samples));
    expect(samples, hasLength(9));
  });
}
