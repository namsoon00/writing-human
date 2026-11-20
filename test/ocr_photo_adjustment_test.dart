import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:writing_human/source/ocr_photo_adjustment.dart';

void main() {
  test('Clean, level paper keeps the same OCR input', () {
    final page = image.Image(width: 360, height: 240);
    image.fill(page, color: image.ColorRgb8(245, 245, 245));
    for (var y = 55; y <= 185; y += 26) {
      image.drawLine(
        page,
        x1: 55,
        y1: y,
        x2: 305,
        y2: y,
        color: image.ColorRgb8(30, 30, 30),
        thickness: 3,
      );
    }
    final bytes = image.encodePng(page);
    final adjusted = adjustOcrPhoto(bytes);
    expect(adjusted.bytes, same(bytes));
    expect(adjusted.projection, isNull);
  });

  test('Diagonal print is leveled and its positions map to the photo', () {
    const width = 360, height = 240;
    final page = image.Image(width: width, height: height);
    for (final pixel in page) {
      final light = 114 + 135 * pixel.x / width;
      pixel.setRgb(light, light, light);
    }
    final dark = image.ColorRgb8(24, 24, 24);
    for (var y = 55; y <= 165; y += 22) {
      image.drawLine(
        page,
        x1: 50,
        y1: y,
        x2: 310,
        y2: y + 23,
        color: dark,
        thickness: 3,
      );
    }
    final adjusted = adjustOcrPhoto(image.encodePng(page));
    final corrected = image.decodePng(adjusted.bytes)!;
    final projection = adjusted.projection!.projection;
    expect(corrected.width, greaterThan(width));
    final atLeft = projection(.25, .5);
    final atRight = projection(.75, .5);
    expect(
      (atRight.dy - atLeft.dy) * height / ((atRight.dx - atLeft.dx) * width),
      closeTo(23 / 260, .02),
    );
    final middle = projection(.5, .5);
    expect(middle.dx, closeTo(.5, .005));
    expect(middle.dy, closeTo(.5, .005));

    // The paper background brightens without erasing the ink in that area.
    final levels = Uint8List(3);
    for (final (i, x, y) in [(0, .2, .18), (1, .8, .18), (2, .5, .5)]) {
      levels[i] = corrected
          .getPixel(
            (x * corrected.width).round(),
            (y * corrected.height).round(),
          )
          .luminance
          .round();
    }
    expect(levels[0], greaterThan(225));
    expect(levels[1], greaterThan(225));
    expect(corrected.any((pixel) => pixel.luminance < 60), isTrue);
  });
}
