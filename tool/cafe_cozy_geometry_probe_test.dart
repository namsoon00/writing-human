import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_avatar.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_world.dart';

void main() {
  test('Record geometry and avatar construction CPU cost, not display FPS', () {
    final room = CafeWorld(), yard = room.linkedWorld;
    final counts = <String, int>{};
    for (final f in yard.faces) {
      final key = f.objectId ?? f.part ?? 'fixed.${f.surface.name}';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    const eye = CafeCamera(position: CafePoint(0, 1.62, 0));
    CafeAvatar(eye: eye, yaw: 0).faces;
    final times = <int>[];
    var faces = 0;
    for (var i = 0; i < 60; i++) {
      final watch = Stopwatch()..start();
      faces = CafeAvatar(
        eye: eye,
        yaw: .1,
        stride: 1,
        phase: i * .12,
      ).faces.length;
      watch.stop();
      times.add(watch.elapsedMicroseconds);
    }
    times.sort();
    final result = {
      'scope':
          'Native test-process CPU construction; not GPU paint or device FPS',
      'roomFaces': room.faces.length,
      'yardFaces': yard.faces.length,
      'avatarFaces': faces,
      'avatarMedianUs': times[30],
      'avatarP95Us': times[57],
      'yardByObjectOrSurface': {for (final e in sorted) e.key: e.value},
    };
    final out = File(
      const String.fromEnvironment(
        'CAFE_GEOMETRY_REPORT',
        defaultValue: 'output/cozy-geometry.json',
      ),
    );
    out.parent.createSync(recursive: true);
    out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
    stdout.writeln(jsonEncode(result));
  });
}
