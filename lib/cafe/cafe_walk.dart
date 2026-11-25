import 'dart:math' as math;
import 'cafe_camera.dart';
import 'cafe_world.dart';

/// A trapezoidal speed profile with quiet acceleration and a bounded top speed.
class CafeWalkTiming {
  CafeWalkTiming(this.distance, {double speed = 1.2})
    : seconds = distance / speed + .32;
  final double distance, seconds;
  double at(double progress) {
    final t = progress.clamp(0.0, 1.0) * seconds;
    final ramp = math.min(.32, seconds / 2),
        speed = distance / (seconds - ramp);
    if (t < ramp) return .5 * speed / ramp * t * t;
    if (t > seconds - ramp) {
      return distance - .5 * speed / ramp * (seconds - t) * (seconds - t);
    }
    return speed * (t - ramp / 2);
  }
}

/// Fillet only corners that remain inside the collision-tested walking region.
List<CafeCamera> cafeWalkRoute(List<CafeCamera> input, CafeWorld world) {
  if (input.length < 3) return input;
  final result = <CafeCamera>[input.first];
  for (var i = 1; i + 1 < input.length; i++) {
    final a = input[i - 1], b = input[i], c = input[i + 1];
    if ((a.position.y - 1.62).abs() > .01 ||
        (b.position.y - 1.62).abs() > .01 ||
        (c.position.y - 1.62).abs() > .01) {
      result.add(b);
      continue;
    }
    final u = a.position - b.position, v = c.position - b.position;
    if (u.length < .05 ||
        v.length < .05 ||
        u.normalized.dot(v.normalized) < -.98) {
      result.add(b);
      continue;
    }
    final radius = math.min(.28, math.min(u.length, v.length) * .24);
    final start = b.position + u.normalized * radius,
        end = b.position + v.normalized * radius;
    final curve = <CafeCamera>[];
    for (var j = 0; j <= 8; j++) {
      final t = j / 8;
      final p = CafePoint.lerp(
        CafePoint.lerp(start, b.position, t),
        CafePoint.lerp(b.position, end, t),
        t,
      );
      curve.add(
        CafeCamera(
          position: p,
          yaw: CafeCamera.interpolate(a, c, t).yaw,
          pitch: b.pitch,
        ),
      );
    }
    var from = result.last.position;
    var safe = true;
    for (final p in curve) {
      if (!world.clearSegment(from, p.position)) {
        safe = false;
        break;
      }
      from = p.position;
    }
    if (safe && world.clearSegment(from, c.position)) {
      result.addAll(curve);
    } else {
      result.add(b);
    }
  }
  result.add(input.last);
  return result;
}
