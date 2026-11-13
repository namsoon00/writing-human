import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as image;

/// Corners ordered clockwise, starting at the top left, in camera coordinates.
class CameraPage {
  const CameraPage(this.corners);

  final List<Offset> corners;

  Offset Function(double, double) get projection {
    final [a, b, c, d] = corners;
    final ab = b - c, ad = d - c, diagonal = a - b + c - d;
    final determinant = ab.dx * ad.dy - ad.dx * ab.dy;
    if (determinant.abs() < .00001) {
      return (u, v) =>
          Offset.lerp(Offset.lerp(a, b, u), Offset.lerp(d, c, u), v)!;
    }
    final g = (diagonal.dx * ad.dy - ad.dx * diagonal.dy) / determinant;
    final h = (ab.dx * diagonal.dy - diagonal.dx * ab.dy) / determinant;
    final horizontal = b * (1 + g) - a, vertical = d * (1 + h) - a;
    return (u, v) => (a + horizontal * u + vertical * v) / (1 + g * u + h * v);
  }

  Rect originalBounds(Rect rect) {
    final project = projection;
    final points = [
      project(rect.left, rect.top),
      project(rect.right, rect.top),
      project(rect.right, rect.bottom),
      project(rect.left, rect.bottom),
    ];
    return Rect.fromLTRB(
      points.map((p) => p.dx).reduce(math.min).clamp(0, 1),
      points.map((p) => p.dy).reduce(math.min).clamp(0, 1),
      points.map((p) => p.dx).reduce(math.max).clamp(0, 1),
      points.map((p) => p.dy).reduce(math.max).clamp(0, 1),
    );
  }
}

CameraPage? findCameraPage(Uint8List bytes) {
  final original = image.decodeJpg(bytes);
  if (original == null) return null;
  final small = image.copyResize(
    original,
    width: original.width >= original.height ? 120 : null,
    height: original.height > original.width ? 120 : null,
  );
  final width = small.width, height = small.height;
  final values = Uint8List(width * height);
  for (final pixel in small) {
    final light = pixel.luminance;
    final spread =
        math.max(pixel.r, math.max(pixel.g, pixel.b)) -
        math.min(pixel.r, math.min(pixel.g, pixel.b));
    if (light >= 132 && spread <= 66) values[pixel.y * width + pixel.x] = 1;
  }
  CameraPage? best;
  var bestCount = 0;
  for (var index = 0; index < values.length; index++) {
    if (values[index] != 1) continue;
    final component = <int>[index];
    values[index] = 0;
    for (var cursor = 0; cursor < component.length; cursor++) {
      final point = component[cursor];
      final x = point % width, y = point ~/ width;
      for (final neighbor in [
        if (x > 0) point - 1,
        if (x + 1 < width) point + 1,
        if (y > 0) point - width,
        if (y + 1 < height) point + width,
      ]) {
        if (values[neighbor] == 0) continue;
        values[neighbor] = 0;
        component.add(neighbor);
      }
    }
    if (component.length <= bestCount ||
        component.length < values.length * .18) {
      continue;
    }
    final points = [
      for (final p in component)
        Offset((p % width + .5) / width, (p ~/ width + .5) / height),
    ];
    final corners = [
      _extreme(points, (p) => p.dx + p.dy),
      _extreme(points, (p) => p.dy - p.dx),
      _extreme(points, (p) => -p.dx - p.dy),
      _extreme(points, (p) => p.dx - p.dy),
    ];
    if (corners.any(
      (p) => p.dx < .016 || p.dx > .984 || p.dy < .016 || p.dy > .984,
    )) {
      continue;
    }
    var area = 0.0;
    for (var i = 0; i < 4; i++) {
      final a = corners[i], b = corners[(i + 1) % 4];
      if ((a - b).distance < .22) {
        area = 0;
        break;
      }
      area += a.dx * b.dy - b.dx * a.dy;
    }
    area /= 2;
    if (area < .23 || component.length < area * values.length * .63) continue;
    best = CameraPage(corners);
    bestCount = component.length;
  }
  return best;
}

Offset _extreme(List<Offset> points, double Function(Offset) score) =>
    points.reduce((a, b) => score(a) <= score(b) ? a : b);

Uint8List rectifyCameraPage((Uint8List, CameraPage) input) {
  final (bytes, page) = input;
  final original = image.decodeJpg(bytes);
  if (original == null) return bytes;
  final [a, b, c, d] = page.corners;
  double distance(Offset p, Offset q) => Offset(
    (p.dx - q.dx) * original.width,
    (p.dy - q.dy) * original.height,
  ).distance;
  final w = math.max(distance(a, b), distance(d, c));
  final h = math.max(distance(a, d), distance(b, c));
  final scale = math.min(1.0, 1700 / math.max(w, h));
  final width = math.max(1, (w * scale).round());
  final height = math.max(1, (h * scale).round());
  final output = image.Image(width: width, height: height);
  final project = page.projection;
  for (final pixel in output) {
    final p = project((pixel.x + .5) / width, (pixel.y + .5) / height);
    pixel.set(
      original.getPixelInterpolate(
        (p.dx * original.width - .5).clamp(0, original.width - 1),
        (p.dy * original.height - .5).clamp(0, original.height - 1),
        interpolation: image.Interpolation.linear,
      ),
    );
  }
  return image.encodeJpg(output, quality: 90);
}
