import 'dart:math' as math;
import 'dart:ui';
import 'cafe_camera.dart';

/// Metre-based layout shared by soil geometry, walking, picking and the camera.
/// The cafe glazing stays on z=3.165; the complete loop is inside the walls.
class CafeYard {
  static const bounds = Rect.fromLTRB(-18, -17, 6, 2.8);
  static const gate = CafePoint(-6, 1.62, -14.8);
  static const shoeApproach = CafePoint(-3, 1.62, -12.6);
  static const meditationApproach = CafePoint(2.8, 1.62, -6.65);
  static const meditation = CafePoint(2.8, .78, -8.5);
  static const readingApproach = CafePoint(-11.5, 1.62, -7.5);
  static const reading = CafePoint(-11.5, 1.18, -8.55);
  static final trail = smooth(const [
    CafePoint(-5.5, 0, -14.8),
    CafePoint(.5, 0, -14.3),
    CafePoint(5.0, 0, -11),
    CafePoint(5.0, 0, -5.5),
    CafePoint(1.7, 0, -3.1),
    CafePoint(-4, 0, -3.7),
    CafePoint(-11.8, 0, -3.2),
    CafePoint(-15.5, 0, -5.8),
    CafePoint(-15.4, 0, -12.8),
    CafePoint(-11, 0, -15),
  ], closed: true);
  static final stone = smooth(const [
    CafePoint(-6, 0, -16.8),
    CafePoint(-5.5, 0, -12.8),
    CafePoint(-2.8, 0, -8.4),
    CafePoint(.3, 0, -4.8),
    CafePoint(1.45, 0, -1.8),
    CafePoint(1.45, 0, 1.5),
    CafePoint(2.2, 0, 2.05),
    CafePoint(3.55, 0, 2.35),
  ]);
  static double get length => List.generate(
    trail.length - 1,
    (i) => (trail[i + 1] - trail[i]).length,
  ).fold(0, (a, b) => a + b);

  static List<CafePoint> smooth(List<CafePoint> points, {bool closed = false}) {
    CafePoint at(int i) => closed
        ? points[i % points.length]
        : points[i.clamp(0, points.length - 1)];
    final result = <CafePoint>[];
    final count = closed ? points.length : points.length - 1;
    for (var i = 0; i < count; i++) {
      final a = at(i - 1), b = at(i), c = at(i + 1), d = at(i + 2);
      for (var j = 0; j < 7; j++) {
        final t = j / 7, tt = t * t, ttt = tt * t;
        result.add(
          (b * 2 +
                  (c - a) * t +
                  (a * 2 - b * 5 + c * 4 - d) * tt +
                  (b * 3 - a - c * 3 + d) * ttt) *
              .5,
        );
      }
    }
    result.add(closed ? result.first : points.last);
    return List.unmodifiable(result);
  }

  static double distanceToTrail(CafePoint p) {
    var nearest = double.infinity;
    for (var i = 1; i < trail.length; i++) {
      final a = trail[i - 1], b = trail[i], v = b - a;
      final t = ((p - a).dot(v) / v.dot(v)).clamp(0.0, 1.0);
      final q = a + v * t;
      nearest = math.min(
        nearest,
        math.sqrt(math.pow(p.x - q.x, 2) + math.pow(p.z - q.z, 2)),
      );
    }
    return nearest;
  }
}
