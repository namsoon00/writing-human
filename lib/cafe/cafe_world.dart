import 'dart:math' as math;
import 'dart:ui';

import 'cafe_camera.dart';
import 'cafe_visit.dart';

class CafeFace {
  CafeFace(
    this.points,
    this.color, {
    this.wood = false,
    this.unlit = false,
    this.garden = false,
    this.sign = false,
    this.doubleSided = false,
    this.layer = 2,
    this.textureCoordinates,
    this.target,
    this.signRow = 0,
  });
  final int signRow;
  final CafeTarget? target;
  final List<CafePoint> points;
  final Color color;
  final bool wood, unlit, garden, sign, doubleSided;
  final int layer;
  final List<Offset>? textureCoordinates;
  late final CafePoint center =
      points.reduce((a, b) => a + b) * (1 / points.length);
  late final CafePoint normal = (points[1] - points[0])
      .cross(points[2] - points[0])
      .normalized;
}

/// All geometry is in metres. The viewer stands inside the same room they visit.
class CafeWorld {
  CafeWorld() {
    _build();
  }
  final List<CafeFace> faces = [];
  final List<Rect> obstacles = [];
  static const wall = Color(0xffddd2bd),
      oak = Color(0xffac835b),
      dark = Color(0xff4e392b);
  static const brass = Color(0xffb59964),
      sage = Color(0xff58634f),
      cream = Color(0xffeee4cf);
  CafeTarget? _target;
  static const halfWidth = 4.4, halfDepth = 5.0, ceiling = 2.95;
  static CafePoint desk(CafeSeat seat) => switch (seat) {
    CafeSeat.window => const CafePoint(-3.72, .77, 1.9),
    CafeSeat.shared => const CafePoint(.24, .77, .75),
    CafeSeat.quiet => const CafePoint(-2.25, .77, -4.02),
    CafeSeat.windowMiddle => const CafePoint(-3.72, .77, -.3),
    CafeSeat.windowRear => const CafePoint(-3.72, .77, -2.5),
  };
  static CafePoint anchor(CafeTarget target) => switch (target) {
    CafeTarget.window => desk(CafeSeat.window),
    CafeTarget.shared => const CafePoint(0, .77, .3),
    CafeTarget.quiet => desk(CafeSeat.quiet),
    CafeTarget.windowMiddle => desk(CafeSeat.windowMiddle),
    CafeTarget.windowRear => desk(CafeSeat.windowRear),
    CafeTarget.bookshelf => const CafePoint(3.92, 1.48, .30),
    CafeTarget.recommendations => const CafePoint(3.92, 1.30, -2.20),
    CafeTarget.stationery => const CafePoint(3.82, .94, 2.45),
    CafeTarget.exit => const CafePoint(0, 1.25, 4.92),
  };
  static CafePoint approach(CafeTarget target) => switch (target) {
    CafeTarget.window => const CafePoint(-2.52, 1.62, 1.9),
    CafeTarget.shared => const CafePoint(1.55, 1.62, .75),
    CafeTarget.quiet => const CafePoint(-2.25, 1.62, -2.70),
    CafeTarget.windowMiddle => const CafePoint(-2.52, 1.62, -.3),
    CafeTarget.windowRear => const CafePoint(-2.52, 1.62, -2.5),
    CafeTarget.bookshelf => const CafePoint(2.85, 1.62, .3),
    CafeTarget.recommendations => const CafePoint(2.85, 1.62, -2.20),
    CafeTarget.stationery => const CafePoint(2.85, 1.62, 2.45),
    CafeTarget.exit => const CafePoint(0, 1.62, 4.10),
  };
  static Rect tableBounds(CafeSeat seat) => switch (seat) {
    CafeSeat.window => const Rect.fromLTWH(-4.12, 1.22, .72, 1.36),
    CafeSeat.shared => const Rect.fromLTWH(-.575, -1.65, 1.15, 3),
    CafeSeat.quiet => const Rect.fromLTWH(-2.95, -4.42, 1.4, .8),
    CafeSeat.windowMiddle => const Rect.fromLTWH(-4.12, -.98, .72, 1.36),
    CafeSeat.windowRear => const Rect.fromLTWH(-4.12, -3.18, .72, 1.36),
  };
  bool canStand(CafePoint p) =>
      p.isFinite &&
      p.x.abs() < halfWidth - .25 &&
      p.z.abs() < halfDepth - .25 &&
      !obstacles.any((r) => r.inflate(.22).contains(Offset(p.x, p.z)));

  bool clearSegment(CafePoint from, CafePoint to) {
    final steps = ((to - from).length / .09).ceil().clamp(1, 2000);
    for (var i = 1; i <= steps; i++) {
      if (!canStand(CafePoint.lerp(from, to, i / steps))) return false;
    }
    return true;
  }

  /// Grid A* around the same furniture used by the renderer; no teleporting
  /// across the communal table when a floor or distant desk is selected.
  List<CafePoint> path(CafePoint from, CafePoint to) {
    if (!canStand(from) || !canStand(to)) return [];
    if (clearSegment(from, to)) return [to];
    const step = .22, columns = 39, rows = 44;
    CafePoint point(int id) => CafePoint(
      -4.18 + (id % columns) * step,
      1.62,
      -4.73 + (id ~/ columns) * step,
    );
    int id(CafePoint p) =>
        ((p.z + 4.73) / step).round().clamp(0, rows - 1) * columns +
        ((p.x + 4.18) / step).round().clamp(0, columns - 1);
    final start = id(from), end = id(to);
    final open = <int>{start},
        came = <int, int>{},
        costs = <int, double>{start: 0};
    var iterations = 0;
    while (open.isNotEmpty && iterations++ < columns * rows) {
      final current = open.reduce(
        (a, b) =>
            costs[a]! + (point(a) - to).length <
                costs[b]! + (point(b) - to).length
            ? a
            : b,
      );
      if (current == end) {
        final route = <CafePoint>[to];
        var cursor = current;
        while (cursor != start) {
          route.insert(0, point(cursor));
          cursor = came[cursor]!;
        }
        final result = <CafePoint>[];
        var origin = from, next = 0;
        while (next < route.length) {
          var far = next;
          while (far + 1 < route.length &&
              clearSegment(origin, route[far + 1])) {
            far++;
          }
          result.add(route[far]);
          origin = route[far];
          next = far + 1;
        }
        return result;
      }
      open.remove(current);
      for (final dx in [-1, 0, 1]) {
        for (final dz in [-1, 0, 1]) {
          if (dx == 0 && dz == 0) continue;
          final x = current % columns + dx, z = current ~/ columns + dz;
          if (x < 0 || x >= columns || z < 0 || z >= rows) continue;
          final neighbor = z * columns + x;
          final a = current == start ? from : point(current);
          final b = neighbor == end ? to : point(neighbor);
          if (!canStand(b) || !clearSegment(a, b)) continue;
          final cost = costs[current]! + (b - a).length;
          if (cost >= (costs[neighbor] ?? double.infinity)) continue;
          came[neighbor] = current;
          costs[neighbor] = cost;
          open.add(neighbor);
        }
      }
    }
    return [];
  }

  void quad(
    CafePoint a,
    CafePoint b,
    CafePoint c,
    CafePoint d,
    Color color, {
    bool wood = false,
    bool unlit = false,
    int layer = 2,
  }) => faces.add(
    CafeFace(
      [a, b, c, d],
      color,
      wood: wood,
      unlit: unlit,
      layer: layer,
      target: _target,
    ),
  );

  void box(
    double x,
    double y,
    double z,
    double w,
    double h,
    double d,
    Color color, {
    bool wood = false,
  }) {
    final l = x - w / 2,
        r = x + w / 2,
        b = y - h / 2,
        t = y + h / 2,
        n = z - d / 2,
        f = z + d / 2;
    quad(
      CafePoint(l, t, f),
      CafePoint(r, t, f),
      CafePoint(r, t, n),
      CafePoint(l, t, n),
      color,
      wood: wood,
    );
    quad(
      CafePoint(l, b, n),
      CafePoint(r, b, n),
      CafePoint(r, b, f),
      CafePoint(l, b, f),
      color,
      wood: wood,
    );
    quad(
      CafePoint(l, b, f),
      CafePoint(r, b, f),
      CafePoint(r, t, f),
      CafePoint(l, t, f),
      color,
      wood: wood,
    );
    quad(
      CafePoint(r, b, n),
      CafePoint(l, b, n),
      CafePoint(l, t, n),
      CafePoint(r, t, n),
      color,
      wood: wood,
    );
    quad(
      CafePoint(r, b, f),
      CafePoint(r, b, n),
      CafePoint(r, t, n),
      CafePoint(r, t, f),
      color,
      wood: wood,
    );
    quad(
      CafePoint(l, b, n),
      CafePoint(l, b, f),
      CafePoint(l, t, f),
      CafePoint(l, t, n),
      color,
      wood: wood,
    );
  }

  void cylinder(
    double x,
    double y,
    double z,
    double radius,
    double height,
    Color color, {
    int sides = 12,
    double? topRadius,
    bool unlit = false,
  }) {
    final rt = topRadius ?? radius;
    for (var i = 0; i < sides; i++) {
      final a = i * math.pi * 2 / sides, b = (i + 1) * math.pi * 2 / sides;
      final p = CafePoint(
        x + math.cos(a) * radius,
        y - height / 2,
        z + math.sin(a) * radius,
      );
      final q = CafePoint(
        x + math.cos(b) * radius,
        y - height / 2,
        z + math.sin(b) * radius,
      );
      final r = CafePoint(
        x + math.cos(b) * rt,
        y + height / 2,
        z + math.sin(b) * rt,
      );
      final s = CafePoint(
        x + math.cos(a) * rt,
        y + height / 2,
        z + math.sin(a) * rt,
      );
      quad(p, s, r, q, color, unlit: unlit);
      faces.add(
        CafeFace(
          [CafePoint(x, y + height / 2, z), r, s],
          color,
          unlit: unlit,
          target: _target,
        ),
      );
    }
  }

  void shadow(
    double x,
    double z,
    double rx,
    double rz, {
    double strength = .09,
  }) {
    for (var ring = 0; ring < 3; ring++) {
      final scale = 1 - ring * .22;
      final pts = <CafePoint>[];
      for (var i = 0; i < 20; i++) {
        final a = i * math.pi / 10;
        pts.add(
          CafePoint(
            x + math.cos(a) * rx * scale,
            .012 + ring * .001,
            z + math.sin(a) * rz * scale,
          ),
        );
      }
      faces.add(
        CafeFace(
          pts,
          Color.fromRGBO(39, 26, 16, strength),
          unlit: true,
          layer: 1,
        ),
      );
    }
  }

  void _chair(double x, double z, {double angle = 0}) {
    CafePoint rot(double dx, double y, double dz) => CafePoint(
      x + dx * math.cos(angle) - dz * math.sin(angle),
      y,
      z + dx * math.sin(angle) + dz * math.cos(angle),
    );
    void part(
      double dx,
      double y,
      double dz,
      double w,
      double h,
      double d,
      Color c,
    ) {
      final p = rot(dx, y, dz);
      // Chairs in this room share the desk alignment.
      box(
        p.x,
        p.y,
        p.z,
        w * math.cos(angle).abs() + d * math.sin(angle).abs(),
        h,
        d * math.cos(angle).abs() + w * math.sin(angle).abs(),
        c,
        wood: true,
      );
    }

    part(0, .43, 0, .48, .055, .45, oak);
    for (final dx in [-.18, .18]) {
      for (final dz in [-.16, .16]) {
        part(dx, .21, dz, .035, .42, .035, dark);
      }
      part(dx, .59, .16, .035, .36, .035, dark);
    }
    // Open curved back, rather than three opaque fence-like planks.
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 12, b = (i + 1) * math.pi / 12;
      final pa = rot(math.cos(a) * .245, .77, math.sin(a) * .21 - .02);
      final pb = rot(math.cos(b) * .245, .77, math.sin(b) * .21 - .02);
      final direction = pb - pa;
      final side = const CafePoint(0, 1, 0).cross(direction).normalized * .022;
      const up = CafePoint(0, .024, 0);
      quad(
        pa + up + side,
        pb + up + side,
        pb + up - side,
        pa + up - side,
        oak,
        wood: true,
      );
      quad(
        pa - up - side,
        pb - up - side,
        pb - up + side,
        pa - up + side,
        oak,
        wood: true,
      );
      quad(
        pa - up + side,
        pb - up + side,
        pb + up + side,
        pa + up + side,
        oak,
        wood: true,
      );
      quad(
        pb - up - side,
        pa - up - side,
        pa + up - side,
        pb + up - side,
        oak,
        wood: true,
      );
    }
    obstacles.add(
      Rect.fromCenter(center: Offset(x, z), width: .48, height: .45),
    );
    shadow(x, z, .32, .3, strength: .045);
  }

  void _book(double x, double y, double z) {
    box(x, y, z, .43, .018, .30, sage);
    box(x, y + .013, z, .40, .016, .28, cream);
    box(x - .104, y + .023, z, .19, .009, .276, const Color(0xfff5efdf));
    box(x + .104, y + .023, z, .19, .009, .276, const Color(0xfff5efdf));
    box(x, y + .027, z, .007, .009, .28, const Color(0xffbfb29b));
    for (var side = 0; side < 2; side++) {
      for (var line = 0; line < 8; line++) {
        final start = x + (side == 0 ? -.18 : .025);
        final length = .12 + ((line * 13) % 4) * .009;
        quad(
          CafePoint(start, y + .029, z - .10 + line * .025),
          CafePoint(start + length, y + .029, z - .10 + line * .025),
          CafePoint(start + length, y + .029, z - .098 + line * .025),
          CafePoint(start, y + .029, z - .098 + line * .025),
          const Color(0xffb3a791),
          unlit: true,
        );
      }
    }
  }

  void _plant(double x, double z, {double height = .9}) {
    obstacles.add(
      Rect.fromCenter(center: Offset(x, z), width: .35, height: .35),
    );
    cylinder(x, .16, z, .16, .30, const Color(0xff9e7353), topRadius: .21);
    cylinder(x, .315, z, .18, .01, dark);
    box(x, .40 + height / 2, z, .018, height, .018, const Color(0xff777052));
    final random = math.Random((x * 100 + z * 50).round());
    for (var i = 0; i < 22; i++) {
      final a = random.nextDouble() * math.pi * 2;
      final yy = .42 + random.nextDouble() * height;
      final rr = .12 + random.nextDouble() * .15;
      final p = CafePoint(x, yy - .07, z);
      final tip = CafePoint(
        x + math.cos(a) * rr,
        yy + .20,
        z + math.sin(a) * rr,
      );
      final edge = CafePoint(-math.sin(a) * .09, .04, math.cos(a) * .09);
      faces.add(
        CafeFace(
          [
            p,
            CafePoint.lerp(p, tip, .5) + edge,
            tip,
            CafePoint.lerp(p, tip, .5) - edge,
          ],
          i.isEven ? sage : const Color(0xff6d7a59),
          doubleSided: true,
        ),
      );
    }
    shadow(x, z, .3, .3, strength: .04);
  }

  void _pendant(double x, double z, {double radius = .25}) {
    cylinder(x, 2.65, z, .012, .56, dark, sides: 5);
    cylinder(x, 2.28, z, radius, .20, brass, topRadius: .08, sides: 16);
    cylinder(
      x,
      2.175,
      z,
      radius * .88,
      .008,
      const Color(0xffffdfad),
      sides: 16,
      unlit: true,
    );
    shadow(x, z, .65, .70, strength: .025);
  }

  void _writingSurface(Rect bounds, {required CafeTarget target}) {
    _target = target;
    obstacles.add(bounds);
    final x = bounds.center.dx, z = bounds.center.dy;
    box(x, .72, z, bounds.width, .065, bounds.height, oak, wood: true);
    box(x, .676, z, bounds.width - .08, .025, bounds.height - .08, dark);
    for (final dx in [-bounds.width / 2 + .10, bounds.width / 2 - .10]) {
      for (final dz in [-bounds.height / 2 + .10, bounds.height / 2 - .10]) {
        box(x + dx, .34, z + dz, .055, .68, .055, dark, wood: true);
      }
    }
    shadow(x, z, bounds.width * .65, bounds.height * .65);
    _target = null;
  }

  void _build() {
    final random = math.Random(74);
    // Subdivide the enclosing room to clip safely even when looking at a wall.
    void wallGrid(
      CafePoint a,
      CafePoint b,
      CafePoint c,
      CafePoint d,
      Color color,
    ) {
      for (var i = 0; i < 14; i++) {
        for (var j = 0; j < 5; j++) {
          CafePoint at(double u, double v) => CafePoint.lerp(
            CafePoint.lerp(a, b, u),
            CafePoint.lerp(d, c, u),
            v,
          );
          quad(
            at(i / 14, j / 5),
            at((i + 1) / 14, j / 5),
            at((i + 1) / 14, (j + 1) / 5),
            at(i / 14, (j + 1) / 5),
            color,
            layer: 0,
          );
        }
      }
    }

    const w = halfWidth, d = halfDepth, h = ceiling;
    quad(
      const CafePoint(-w, -.008, -d),
      const CafePoint(-w, -.008, d),
      const CafePoint(w, -.008, d),
      const CafePoint(w, -.008, -d),
      oak,
      layer: -1,
    );
    for (var row = 0; row < 26; row++) {
      final x = -w + row * .34;
      for (var col = 0; col < 9; col++) {
        final z = -d + col * 1.3 - (row.isEven ? .6 : 0);
        final a = z.clamp(-d, d).toDouble(),
            b = (z + 1.295).clamp(-d, d).toDouble();
        if (b <= a) continue;
        quad(
          CafePoint(x, 0, a),
          CafePoint(x, 0, b),
          CafePoint(math.min(x + .335, w), 0, b),
          CafePoint(math.min(x + .335, w), 0, a),
          Color.lerp(
            const Color(0xffac855f),
            const Color(0xffc6a17b),
            random.nextDouble(),
          )!,
          wood: true,
          layer: 0,
        );
      }
    }
    wallGrid(
      const CafePoint(-w, 0, -d),
      const CafePoint(w, 0, -d),
      const CafePoint(w, h, -d),
      const CafePoint(-w, h, -d),
      wall,
    );
    wallGrid(
      const CafePoint(w, 0, -d),
      const CafePoint(w, 0, d),
      const CafePoint(w, h, d),
      const CafePoint(w, h, -d),
      wall,
    );
    wallGrid(
      const CafePoint(w, 0, d),
      const CafePoint(-w, 0, d),
      const CafePoint(-w, h, d),
      const CafePoint(w, h, d),
      wall,
    );
    wallGrid(
      const CafePoint(-w, 0, d),
      const CafePoint(-w, 0, -d),
      const CafePoint(-w, h, -d),
      const CafePoint(-w, h, d),
      wall,
    );
    wallGrid(
      const CafePoint(-w, h, d),
      const CafePoint(-w, h, -d),
      const CafePoint(w, h, -d),
      const CafePoint(w, h, d),
      const Color(0xffe9ddc8),
    );
    box(0, .08, -4.96, 8.8, .16, .08, dark, wood: true);
    for (final x in [-4.36, 4.36]) {
      box(x, .08, 0, .08, .16, 10, dark, wood: true);
    }
    // Rainy windows, wooden reveals and shallow pools of reflected daylight.
    for (final z in [-3.35, -1.05, 1.25, 3.55]) {
      for (final dz in [-1.08, 1.08]) {
        box(-4.31, 1.72, z + dz, .12, 2.25, .07, dark, wood: true);
      }
      box(-4.30, .61, z, .12, .07, 2.20, dark, wood: true);
      box(-4.30, 2.83, z, .12, .07, 2.20, dark, wood: true);
      for (var i = 0; i < 4; i++) {
        for (var j = 0; j < 4; j++) {
          final u = i / 4, v = j / 4, du = (i + 1) / 4, dv = (j + 1) / 4;
          CafePoint at(double u, double v) =>
              CafePoint(-4.235, 2.78 - v * 2.12, z - 1.02 + u * 2.04);
          faces.add(
            CafeFace(
              [at(u, dv), at(du, dv), at(du, v), at(u, v)],
              const Color(0xffbfccb6),
              garden: true,
              unlit: true,
              layer: 1,
              textureCoordinates: [
                Offset(u, dv),
                Offset(du, dv),
                Offset(du, v),
                Offset(u, v),
              ],
            ),
          );
        }
      }
      box(-4.20, 1.70, z, .12, 2.2, .04, dark, wood: true);
      box(-4.20, .63, z, .30, .055, 2.20, oak, wood: true);
      for (var i = 0; i < 14; i++) {
        final zz = z - 1 + random.nextDouble() * 2,
            yy = .8 + random.nextDouble() * 1.7;
        quad(
          CafePoint(-4.18, yy, zz),
          CafePoint(-4.18, yy + .14, zz),
          CafePoint(-4.18, yy + .14, zz + .008),
          CafePoint(-4.18, yy, zz + .008),
          const Color(0x50ffffff),
          unlit: true,
        );
      }
      quad(
        CafePoint(-4.1, .007, z - .9),
        CafePoint(-2.0, .007, z - .6),
        CafePoint(-1.65, .007, z + .6),
        CafePoint(-4.1, .007, z + .9),
        const Color(0x12ffedcc),
        unlit: true,
        layer: 1,
      );
    }
    // Three individual window desks, facing the garden, with their own chair zone.
    for (final seat in [
      CafeSeat.windowRear,
      CafeSeat.windowMiddle,
      CafeSeat.window,
    ]) {
      final z = desk(seat).z;
      final target = CafeTarget.forSeat(seat);
      _writingSurface(
        Rect.fromCenter(center: Offset(-3.76, z), width: .72, height: 1.36),
        target: target,
      );
      _target = target;
      _chair(-3.0, z, angle: math.pi / 2);
      _book(-3.72, .773, z);
      cylinder(-3.8, .83, z - .40, .06, .10, cream, sides: 12);
      _target = null;
      _pendant(-3.68, z, radius: .19);
    }
    // A true longitudinal communal table; six side chairs, open short ends.
    _writingSurface(tableBounds(CafeSeat.shared), target: CafeTarget.shared);
    _target = CafeTarget.shared;
    for (final z in [-.95, .05, 1.05]) {
      _chair(.98, z, angle: -math.pi / 2);
      _chair(-.98, z, angle: math.pi / 2);
    }
    _book(.24, .773, .75);
    _book(-.23, .773, -.85);
    box(.29, .805, .49, .22, .012, .015, dark);
    cylinder(-.2, .82, .18, .06, .10, cream, sides: 14);
    cylinder(
      0,
      .84,
      -.30,
      .065,
      .19,
      const Color(0xffbdad89),
      sides: 12,
      topRadius: .04,
    );
    _target = null;
    _pendant(0, -.83);
    _pendant(0, .68);
    // Rear writing alcove, framed in walnut and lit like the selected concept.
    box(-2.25, 1.42, -4.90, 1.95, 2.7, .12, dark, wood: true);
    box(-2.25, 1.46, -4.81, 1.65, 2.42, .035, const Color(0xff81765e));
    for (final x in [-3.16, -1.34]) {
      box(x, 1.35, -4.68, .12, 2.7, .32, dark, wood: true);
    }
    box(-2.25, 2.70, -4.68, 1.9, .12, .32, dark, wood: true);
    _writingSurface(tableBounds(CafeSeat.quiet), target: CafeTarget.quiet);
    _target = CafeTarget.quiet;
    _chair(-2.25, -3.3);
    _book(-2.25, .773, -4.02);
    _target = null;
    _pendant(-2.25, -3.95, radius: .18);
    // Coffee counter with narrow walnut ribs and an ivory stone top.
    obstacles.add(const Rect.fromLTWH(-.65, -4.9, 3.2, .85));
    box(.95, .49, -4.48, 3.2, .98, .80, dark, wood: true);
    for (var i = 0; i < 43; i++) {
      box(-.61 + i * .074, .48, -4.06, .029, .91, .025, oak, wood: true);
    }
    box(.95, 1.015, -4.47, 3.32, .07, .91, cream);
    box(1.05, 1.29, -4.52, .75, .45, .40, const Color(0xff55534b));
    box(1.05, 1.26, -4.29, .67, .23, .04, const Color(0xffb5aea0));
    for (var i = 0; i < 4; i++) {
      cylinder(.0 + i * .15, 1.10, -4.45, .048, .10, cream, sides: 12);
    }
    cylinder(1.95, 1.21, -4.5, .09, .32, dark, sides: 12);
    faces.add(
      CafeFace(
        [
          const CafePoint(-.25, 1.82, -4.94),
          const CafePoint(1.65, 1.82, -4.94),
          const CafePoint(1.65, 2.65, -4.94),
          const CafePoint(-.25, 2.65, -4.94),
        ],
        wall,
        sign: true,
        unlit: true,
      ),
    );
    // Right wall cabinetry: face-out recommendations, private shelf, pen ledge.
    for (final section in [
      (-2.25, CafeTarget.recommendations),
      (.30, CafeTarget.bookshelf),
    ]) {
      final z = section.$1;
      _target = section.$2;
      obstacles.add(
        Rect.fromCenter(center: Offset(4.12, z), width: .52, height: 2.2),
      );
      box(4.19, 1.42, z, .36, 2.8, 2.25, dark, wood: true);
      for (final dz in [-1.1, 1.1]) {
        box(3.98, 1.42, z + dz, .45, 2.8, .07, dark, wood: true);
      }
      for (var row = 0; row < 4; row++) {
        final y = .64 + row * .55;
        box(3.97, y, z, .51, .055, 2.20, oak, wood: true);
        box(3.72, y + .06, z, .025, .025, 2.05, const Color(0xffffd69b));
        for (var i = 0; i < 5; i++) {
          final colors = [
            sage,
            cream,
            const Color(0xffa78167),
            const Color(0xffc2b493),
          ];
          box(
            3.91,
            y + .23,
            z - .86 + i * .41,
            .065,
            .36,
            .25,
            colors[(row + i) % 4],
          );
          box(3.87, y + .19, z - .86 + i * .41, .005, .006, .13, brass);
        }
      }
      final row = section.$2 == CafeTarget.recommendations ? 1 : 2;
      faces.add(
        CafeFace(
          [
            CafePoint(3.68, 2.35, z - .88),
            CafePoint(3.68, 2.35, z + .88),
            CafePoint(3.68, 2.84, z + .88),
            CafePoint(3.68, 2.84, z - .88),
          ],
          cream,
          sign: true,
          signRow: row,
          unlit: true,
          target: section.$2,
        ),
      );
      _target = null;
    }
    // Olive bench beneath the private bookshelf, kept off the walking route.
    box(3.91, .39, .30, .67, .32, 1.85, sage);
    box(4.17, .74, .30, .12, .48, 1.85, const Color(0xff7c8368));
    obstacles.add(const Rect.fromLTWH(3.55, -.65, .74, 1.90));
    _target = CafeTarget.stationery;
    obstacles.add(const Rect.fromLTWH(3.55, 1.58, .78, 1.75));
    box(3.98, .43, 2.45, .74, .86, 1.75, dark, wood: true);
    box(3.94, .9, 2.45, .87, .06, 1.85, oak, wood: true);
    for (var i = 0; i < 3; i++) {
      box(3.58, .24 + i * .23, 2.45, .012, .015, 1.58, oak);
      cylinder(3.55, .31 + i * .23, 2.45, .018, .13, brass, sides: 6);
    }
    for (var i = 0; i < 4; i++) {
      box(3.92, .95 + i * .022, 2.89, .31, .018, .28, i.isEven ? sage : cream);
      box(3.86, .95, 1.94 + i * .10, .23, .013, .018, dark);
    }
    _book(3.87, .947, 2.4);
    faces.add(
      CafeFace(
        [
          const CafePoint(4.25, 1.65, 1.67),
          const CafePoint(4.25, 1.65, 3.23),
          const CafePoint(4.25, 2.14, 3.23),
          const CafePoint(4.25, 2.14, 1.67),
        ],
        cream,
        sign: true,
        signRow: 3,
        unlit: true,
        target: CafeTarget.stationery,
      ),
    );
    _target = null;
    // A few plants at the perimeter rather than obstacles in the aisles.
    _plant(3.77, -3.90, height: .9);
    _plant(-3.90, 3.75, height: .85);
    // Entrance, visible when turning around; it is also the in-room exit.
    _target = CafeTarget.exit;
    box(0, 1.31, 4.94, 1.5, 2.62, .09, dark, wood: true);
    box(0, 1.53, 4.87, 1.26, 1.92, .025, const Color(0xff9baa92));
    box(0, .32, 4.85, 1.26, .48, .05, oak, wood: true);
    cylinder(.5, 1.12, 4.80, .024, .25, brass, sides: 8);
    _target = null;
  }
}
