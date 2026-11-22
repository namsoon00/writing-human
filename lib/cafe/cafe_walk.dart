import 'dart:math' as math;
import 'cafe_camera.dart';
import 'cafe_world.dart';

/// A trapezoidal speed profile with quiet acceleration and a bounded top speed.
class CafeWalkTiming {
  CafeWalkTiming(this.distance) : seconds = distance / 1.2 + .32;
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

double cafeTurn(double a, double b, double amount) =>
    a + ((b - a + math.pi) % (2 * math.pi) - math.pi) * amount;
CafePoint cafeForward(double yaw) =>
    CafePoint(math.sin(yaw), 0, -math.cos(yaw));
CafePoint cafeRight(double yaw) => CafePoint(math.cos(yaw), 0, math.sin(yaw));

/// Foot plants stay in world coordinates during stance, including at corners.
class CafeGait {
  double distance = 0;
  CafePoint? _previous;
  final List<CafePoint?> _plants = [null, null], _swing = [null, null];
  final List<double> _phases = [0, .5];
  static const stride = .9, stance = .6;
  CafePoint foot(int side, CafePoint actor, double yaw) {
    final phase = (distance / stride + side * .5) % 1;
    final neutral =
        actor +
        cafeRight(yaw) * (side == 0 ? -.095 : .095) +
        const CafePoint(0, .06, 0);
    final plant = _plants[side] ?? neutral;
    if (phase < stance) return plant;
    final t = (phase - stance) / (1 - stance), ease = t * t * (3 - 2 * t);
    final target = neutral + cafeForward(yaw) * .24;
    return CafePoint.lerp(_swing[side] ?? plant, target, ease) +
        CafePoint(0, math.sin(math.pi * t) * .075, 0);
  }

  void reset(CafePoint p, double yaw) {
    _previous = p;
    for (var i = 0; i < 2; i++) {
      _plants[i] =
          p +
          cafeRight(yaw) * (i == 0 ? -.095 : .095) +
          cafeForward(yaw) * (i == 0 ? .24 : -.21) +
          const CafePoint(0, .06, 0);
      _swing[i] = _plants[i];
      _phases[i] = (distance / stride + i * .5) % 1;
    }
  }

  void move(CafePoint p, double yaw) {
    final old = _previous;
    if (old == null) {
      reset(p, yaw);
      return;
    }
    final delta = CafePoint(p.x - old.x, 0, p.z - old.z).length;
    final before = distance;
    distance += delta;
    for (var i = 0; i < 2; i++) {
      final phase = (distance / stride + i * .5) % 1, previous = _phases[i];
      if (phase < previous || delta > stride * .5) {
        final boundary = (distance / stride + i * .5).floorToDouble() - i * .5;
        final crossing = delta == 0
            ? 1.0
            : ((boundary * stride - before) / delta).clamp(0.0, 1.0);
        final contact = CafePoint.lerp(old, p, crossing);
        _plants[i] =
            contact +
            cafeRight(yaw) * (i == 0 ? -.095 : .095) +
            cafeForward(yaw) * .24 +
            const CafePoint(0, .06, 0);
      }
      if (previous < stance && phase >= stance) _swing[i] = _plants[i];
      _phases[i] = phase;
    }
    _previous = p;
  }
}
