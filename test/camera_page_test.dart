import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:writing_human/source/camera_page.dart';

void main() {
  test(
    'Detect a tilted page and keep OCR positions tied to the original frame',
    () {
      final frame = image.Image(width: 360, height: 400);
      final corners = [
        image.Point(68, 46),
        image.Point(292, 77),
        image.Point(312, 337),
        image.Point(42, 309),
      ];
      image.fillPolygon(
        frame,
        vertices: corners,
        color: image.ColorRgb8(245, 242, 230),
      );
      image.drawLine(
        frame,
        x1: 82,
        y1: 149,
        x2: 266,
        y2: 170,
        color: image.ColorRgb8(23, 23, 23),
        thickness: 4,
      );
      final bytes = image.encodeJpg(frame);
      final page = findCameraPage(bytes)!;
      final project = page.projection;
      final projected = [
        project(0, 0),
        project(1, 0),
        project(1, 1),
        project(0, 1),
      ];
      for (final (index, corner) in corners.indexed) {
        expect(projected[index].dx, closeTo(corner.x / 360, .025));
        expect(projected[index].dy, closeTo(corner.y / 400, .025));
      }
      final corrected = image.decodeJpg(rectifyCameraPage((bytes, page)))!;
      expect(corrected.width, lessThan(frame.width));
      expect(corrected.getPixel(10, 10).luminance, greaterThan(200));
      final bounds = page.originalBounds(const Rect.fromLTRB(.2, .3, .7, .5));
      expect(bounds.contains(project(.4, .4)), isTrue);
    },
  );

  test('A bright frame with no visible page edges is left uncropped', () {
    final frame = image.Image(width: 160, height: 180);
    image.fill(frame, color: image.ColorRgb8(240, 240, 240));
    expect(findCameraPage(image.encodeJpg(frame)), isNull);
  });
}
