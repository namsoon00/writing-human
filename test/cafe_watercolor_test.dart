import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_space.dart';
import 'package:writing_human/cafe/cafe_watercolor.dart';
import 'package:writing_human/cafe/cafe_world.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Painted timber survives source disposal and keeps walnut distinct',
    () async {
      // Keep browser asset HTTP outside this ownership test. The render sweep
      // exercises bundled timber; both sources have the same ui.Image contract.
      final source = await CafeWatercolor.wood();
      final images = await Future.wait([
        CafeWatercolor.timber(source),
        CafeWatercolor.timber(source, walnut: true),
      ]);
      source.dispose();
      try {
        final values = <int>[];
        for (final image in images) {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          var sum = 0;
          for (var i = 0; i < bytes.length; i += 64) {
            sum += bytes[i] + bytes[i + 1] + bytes[i + 2];
          }
          values.add(sum);
        }
        expect(values[1], lessThan(values[0] * .85));
      } finally {
        for (final image in images) {
          image.dispose();
        }
      }
    },
  );
  test('Moving furniture carries ceramic pigment as well as wood grain', () {
    final before = CafeWorld();
    final after = CafeWorld(
      space: const CafeSpace(
        poses: {
          'shared': CafePose(x: .12, z: .10, turn: .08),
          'shared.cup': CafePose(x: .03, z: -.02),
        },
      ),
    );
    for (final id in [
      'shared.cup',
      'shared.pen',
      'shared.book',
      'shared.table',
    ]) {
      final a = before.faces.where((f) => f.objectId == id).toList();
      final b = after.faces.where((f) => f.objectId == id).toList();
      expect(a, isNotEmpty);
      expect(b.length, a.length);
      for (var i = 0; i < a.length; i++) {
        expect(
          b[i].textureCoordinates,
          a[i].textureCoordinates,
          reason: 'paint must move with $id, not slide through it',
        );
        expect(b[i].points.every((p) => p.isFinite), isTrue);
      }
    }
  });

  test(
    'Painted plants retain transparent gaps and wood is repeatable',
    () async {
      final images = await Future.wait([
        CafeWatercolor.wood(),
        CafeWatercolor.wood(),
        CafeWatercolor.tree(),
        CafeWatercolor.flowers(),
      ]);
      try {
        final pixels = await Future.wait(
          images.map(
            (image) async => (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List(),
          ),
        );
        expect(
          pixels[0],
          orderedEquals(pixels[1]),
          reason: 'room re-entry must not randomize the paint',
        );
        for (final data in pixels.skip(2)) {
          var transparent = 0, painted = 0;
          for (var i = 3; i < data.length; i += 4) {
            if (data[i] == 0) transparent++;
            if (data[i] > 80) painted++;
          }
          expect(transparent, greaterThan(40000));
          expect(painted, greaterThan(7000));
        }
      } finally {
        for (final image in images) {
          image.dispose();
        }
      }
    },
  );
}
