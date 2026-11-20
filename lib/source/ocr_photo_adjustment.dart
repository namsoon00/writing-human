import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:image/image.dart' as image;

import 'camera_page.dart';

typedef OcrPhotoAdjustment = ({Uint8List bytes, CameraPage? projection});

/// Only changes the pixels sent to OCR. The app keeps the original image and
/// maps recognized boxes back to it if the page was rotated.
OcrPhotoAdjustment adjustOcrPhoto(Uint8List bytes) {
  final original = image.decodePng(bytes);
  if (original == null) return (bytes: bytes, projection: null);
  final small = image.copyResize(
    original,
    width: original.width >= original.height
        ? math.min(original.width, 540)
        : null,
    height: original.height > original.width
        ? math.min(original.height, 540)
        : null,
    interpolation: image.Interpolation.average,
  );
  final light = _PaperLight(small);
  final angle = _deskewAngle(small, light);
  if (!light.needsAdjustment && angle == 0) {
    return (bytes: bytes, projection: null);
  }

  final flat = light.needsAdjustment ? light.flatten(original) : original;
  if (angle == 0) {
    return (bytes: image.encodePng(flat, level: 3), projection: null);
  }
  final white = image.ColorRgb8(255, 255, 255);
  flat.backgroundColor = white;
  final corrected = image.copyRotate(
    flat,
    angle: angle,
    interpolation: image.Interpolation.linear,
  );
  final radians = angle * math.pi / 180;
  final cos = math.cos(radians), sin = math.sin(radians);
  final centerX = (cos.abs() * flat.width + sin.abs() * flat.height) / 2;
  final centerY = (sin.abs() * flat.width + cos.abs() * flat.height) / 2;

  Offset inOriginal(double x, double y) => Offset(
    .5 + ((x - centerX) * cos + (y - centerY) * sin) / flat.width,
    .5 + ((y - centerY) * cos - (x - centerX) * sin) / flat.height,
  );

  return (
    bytes: image.encodePng(corrected, level: 3),
    projection: CameraPage([
      inOriginal(0, 0),
      inOriginal(corrected.width.toDouble(), 0),
      inOriginal(corrected.width.toDouble(), corrected.height.toDouble()),
      inOriginal(0, corrected.height.toDouble()),
    ]),
  );
}

/// Estimates the paper brightness on a coarse grid. Sampling near the top of
/// each cell's brightness distribution prevents dark print from setting it.
class _PaperLight {
  _PaperLight(image.Image sample) {
    for (var row = 0; row < _cells; row++) {
      for (var col = 0; col < _cells; col++) {
        final left = col * sample.width ~/ _cells;
        final top = row * sample.height ~/ _cells;
        final right = (col + 1) * sample.width ~/ _cells;
        final bottom = (row + 1) * sample.height ~/ _cells;
        final levels = <int>[
          for (var y = top; y < bottom; y += 2)
            for (var x = left; x < right; x += 2)
              sample.getPixel(x, y).luminance.round().clamp(0, 255),
        ]..sort();
        _grid.add(
          levels.isEmpty ? 255 : levels[(levels.length - 1) * 85 ~/ 100],
        );
      }
    }
    final ordered = [..._grid]..sort();
    // Ignore unusually dark borders and isolated bright marks.
    final dim = ordered[ordered.length ~/ 5];
    final bright = ordered[ordered.length * 4 ~/ 5];
    needsAdjustment = bright >= 100 && (bright - dim >= 14 || dim < 213);
  }

  static const _cells = 12;
  final _grid = <int>[];
  late final bool needsAdjustment;

  double at(double x, double y) {
    final col = (x * _cells - .5).clamp(0.0, _cells - 1.0);
    final row = (y * _cells - .5).clamp(0.0, _cells - 1.0);
    final left = col.floor(), top = row.floor();
    final right = math.min(left + 1, _cells - 1);
    final bottom = math.min(top + 1, _cells - 1);
    double across(int r) {
      final a = _grid[r * _cells + left];
      return a + (_grid[r * _cells + right] - a) * (col - left);
    }

    final a = across(top);
    return a + (across(bottom) - a) * (row - top);
  }

  image.Image flatten(image.Image source) {
    final result = image.Image(width: source.width, height: source.height);
    for (final pixel in source) {
      final paper = math.max(
        76.0,
        at(pixel.x / source.width, pixel.y / source.height),
      );
      final value = (pixel.luminance * 255 / paper).round().clamp(0, 255);
      result.setPixelRgb(pixel.x, pixel.y, value, value, value);
    }
    return result;
  }
}

/// Finds the rotation that concentrates dark print into the fewest rows.
/// Only corrects a slight skew when the row pattern is clear.
double _deskewAngle(image.Image sample, _PaperLight light) {
  final width = sample.width, height = sample.height;
  final edgeX = width ~/ 12, edgeY = height ~/ 12;
  final points = <(int, int)>[];
  for (var y = edgeY; y < height - edgeY; y++) {
    for (var x = edgeX; x < width - edgeX; x++) {
      final paper = light.at(x / width, y / height);
      if (sample.getPixel(x, y).luminance < paper * .7) {
        points.add((x - width ~/ 2, y - height ~/ 2));
      }
    }
  }
  if (points.length < 160 || points.length > width * height * .2) return 0;

  final padding = (width + height) ~/ 2 + 2;
  int rowScore(double angle) {
    final radians = angle * math.pi / 180;
    final sin = math.sin(radians), cos = math.cos(radians);
    final rows = Int32List(padding * 2);
    for (final (x, y) in points) {
      rows[padding + (y * cos + x * sin).round()]++;
    }
    return rows.fold(0, (sum, count) => sum + count * count);
  }

  final upright = rowScore(0);
  var best = upright;
  var angle = 0.0;
  for (var step = -24; step <= 24; step++) {
    if (step == 0) continue;
    final candidate = step / 2;
    final score = rowScore(candidate);
    if (score > best) {
      best = score;
      angle = candidate;
    }
  }
  return angle.abs() >= 1 && best > upright * 1.12 ? angle : 0;
}
