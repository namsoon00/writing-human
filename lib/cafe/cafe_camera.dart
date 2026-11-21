import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import 'cafe_visit.dart';

@immutable
class CafePoint {
  const CafePoint(this.x, this.y, this.z);
  final double x, y, z;
  CafePoint operator +(CafePoint b) => CafePoint(x + b.x, y + b.y, z + b.z);
  CafePoint operator -(CafePoint b) => CafePoint(x - b.x, y - b.y, z - b.z);
  CafePoint operator *(double t) => CafePoint(x * t, y * t, z * t);
  double dot(CafePoint b) => x * b.x + y * b.y + z * b.z;
  CafePoint cross(CafePoint b) =>
      CafePoint(y * b.z - z * b.y, z * b.x - x * b.z, x * b.y - y * b.x);
  double get length => math.sqrt(dot(this));
  CafePoint get normalized =>
      length == 0 ? const CafePoint(0, 1, 0) : this * (1 / length);
  static CafePoint lerp(CafePoint a, CafePoint b, double t) => a + (b - a) * t;
}

@immutable
class CafeCamera {
  const CafeCamera({required this.position, this.yaw = 0, this.pitch = -.06});
  static const entrance = CafeCamera(
    position: CafePoint(.6, 1.62, 4.5),
    yaw: -.17,
  );
  final CafePoint position;
  final double yaw, pitch;
  // Yaw zero faces into the cafe along -Z; pitch zero is a level human gaze.
  CafePoint get forward => CafePoint(
    math.sin(yaw) * math.cos(pitch),
    math.sin(pitch),
    -math.cos(yaw) * math.cos(pitch),
  );
  CafePoint get right => CafePoint(math.cos(yaw), 0, math.sin(yaw));
  CafePoint get up => right.cross(forward);
  CafePoint toView(CafePoint point) {
    final delta = point - position;
    return CafePoint(delta.dot(right), delta.dot(up), delta.dot(forward));
  }

  CafeCamera look(double dx, double dy) => CafeCamera(
    position: position,
    yaw: yaw - dx,
    pitch: (pitch + dy).clamp(-.72, .65),
  );
  CafeCamera moved(double sideways, double ahead) {
    final delta = CafePoint(
      math.cos(yaw) * sideways + math.sin(yaw) * ahead,
      0,
      math.sin(yaw) * sideways - math.cos(yaw) * ahead,
    );
    final p = position + delta;
    return CafeCamera(
      position: CafePoint(p.x, position.y, p.z),
      yaw: yaw,
      pitch: pitch,
    );
  }

  static CafeCamera seated(CafeSeat seat) => switch (seat) {
    CafeSeat.window => const CafeCamera(
      position: CafePoint(-2.8, 1.18, 1.08),
      yaw: -.10,
      pitch: -.40,
    ),
    CafeSeat.shared => const CafeCamera(
      position: CafePoint(.2, 1.18, -.52),
      yaw: .05,
      pitch: -.40,
    ),
    CafeSeat.quiet => const CafeCamera(
      position: CafePoint(2.7, 1.18, -2.82),
      yaw: -.12,
      pitch: -.40,
    ),
  };
  static CafeCamera interpolate(CafeCamera a, CafeCamera b, double t) {
    final turn = (b.yaw - a.yaw + math.pi) % (2 * math.pi) - math.pi;
    return CafeCamera(
      position: CafePoint.lerp(a.position, b.position, t),
      yaw: a.yaw + turn * t,
      pitch: a.pitch + (b.pitch - a.pitch) * t,
    );
  }
}
