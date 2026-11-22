import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import 'cafe_visit.dart';

@immutable
class CafePoint {
  const CafePoint(this.x, this.y, this.z);
  final double x, y, z;
  bool get isFinite => x.isFinite && y.isFinite && z.isFinite;
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
    position: CafePoint(0, 1.62, 4.25),
    pitch: -.10,
  );
  final CafePoint position;
  final double yaw, pitch;
  bool get isFinite => position.isFinite && yaw.isFinite && pitch.isFinite;
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

  CafeCamera look(double dx, double dy) => !dx.isFinite || !dy.isFinite
      ? this
      : CafeCamera(
          position: position,
          yaw: (yaw - dx + math.pi) % (math.pi * 2) - math.pi,
          pitch: (pitch + dy).clamp(-.72, .65),
        );
  CafeCamera moved(double sideways, double ahead) {
    if (!sideways.isFinite || !ahead.isFinite) return this;
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
      position: CafePoint(-3.00, 1.18, 1.9),
      yaw: -math.pi / 2,
      pitch: -.50,
    ),
    CafeSeat.shared => const CafeCamera(
      position: CafePoint(.98, 1.18, .75),
      yaw: -math.pi / 2,
      pitch: -.52,
    ),
    CafeSeat.quiet => const CafeCamera(
      position: CafePoint(-2.25, 1.18, -3.30),
      pitch: -.48,
    ),
    CafeSeat.windowMiddle => const CafeCamera(
      position: CafePoint(-3.0, 1.18, -.3),
      yaw: -math.pi / 2,
      pitch: -.50,
    ),
    CafeSeat.windowRear => const CafeCamera(
      position: CafePoint(-3.0, 1.18, -2.5),
      yaw: -math.pi / 2,
      pitch: -.50,
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
