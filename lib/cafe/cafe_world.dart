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
  });
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
  static CafePoint desk(CafeSeat seat) => switch (seat) {
    CafeSeat.window => const CafePoint(-2.8, .77, .28),
    CafeSeat.shared => const CafePoint(.2, .77, -1.32),
    CafeSeat.quiet => const CafePoint(2.7, .77, -3.62),
  };

  bool canStand(CafePoint p) =>
      p.x > -3.65 &&
      p.x < 3.65 &&
      p.z > -5.12 &&
      p.z < 5.12 &&
      !obstacles.any((r) => r.inflate(.20).contains(Offset(p.x, p.z)));

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
    CafeFace([a, b, c, d], color, wood: wood, unlit: unlit, layer: layer),
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
        CafeFace([CafePoint(x, y + height / 2, z), r, s], color, unlit: unlit),
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
      box(p.x, p.y, p.z, w, h, d, c, wood: true);
    }

    part(0, .43, 0, .48, .065, .45, oak);
    for (final dx in [-.19, .19]) {
      for (final dz in [-.16, .16]) {
        part(dx, .21, dz, .045, .42, .045, dark);
      }
    }
    for (final dx in [-.20, .20]) {
      part(dx, .66, .18, .045, .44, .045, oak);
    }
    for (var i = 0; i < 3; i++) {
      part(0, .64 + i * .09, .18, .44, .055, .04, oak);
    }
    obstacles.add(
      Rect.fromCenter(center: Offset(x, z), width: .48, height: .45),
    );
    shadow(x, z, .32, .3, strength: .045);
  }

  void _table(CafeSeat seat, {double width = 1.45}) {
    final p = desk(seat);
    obstacles.add(
      Rect.fromCenter(center: Offset(p.x, p.z), width: width, height: .80),
    );
    box(p.x, .735, p.z, width, .075, .80, oak, wood: true);
    for (final dx in [-width / 2 + .10, width / 2 - .10]) {
      for (final dz in [-.30, .30]) {
        box(p.x + dx, .36, p.z + dz, .055, .72, .055, dark);
      }
    }
    // Chamfered underside, book, pen, stoneware cup and saucer.
    box(p.x, .684, p.z, width - .10, .035, .68, dark);
    _book(p.x - .13, .786, p.z + .13);
    cylinder(p.x + .44, .798, p.z - .12, .105, .014, cream, sides: 18);
    cylinder(
      p.x + .44,
      .855,
      p.z - .12,
      .068,
      .10,
      cream,
      sides: 18,
      topRadius: .079,
    );
    cylinder(
      p.x + .44,
      .907,
      p.z - .12,
      .062,
      .004,
      const Color(0xff492e1b),
      sides: 18,
    );
    cylinder(p.x + .525, .858, p.z - .12, .025, .045, cream, sides: 8);
    box(p.x + .16, .789, p.z + .22, .017, .012, .25, const Color(0xff514231));
    box(p.x + .16, .789, p.z + .095, .014, .014, .025, brass);
    _chair(p.x, p.z + .68);
    if (seat == CafeSeat.shared) {
      _chair(p.x - .48, p.z - .70);
      _chair(p.x + .48, p.z - .70);
    }
    shadow(p.x, p.z, width * .7, .63);
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

  void _build() {
    quad(
      const CafePoint(-4, -.006, -5.5),
      const CafePoint(-4, -.006, 5.5),
      const CafePoint(4, -.006, 5.5),
      const CafePoint(4, -.006, -5.5),
      dark,
      layer: -1,
    );
    // Individual boards allow correct near-plane clipping while moving.
    final random = math.Random(74);
    for (var row = 0; row < 23; row++) {
      final x = -4.0 + row * .35;
      for (var col = 0; col < 8; col++) {
        final z = -5.5 + col * 1.45 - (row.isEven ? .5 : 0);
        final a = z.clamp(-5.5, 5.5).toDouble(),
            b = (z + 1.445).clamp(-5.5, 5.5).toDouble();
        final tone = Color.lerp(
          const Color(0xff96744f),
          const Color(0xffc4a478),
          random.nextDouble(),
        )!;
        quad(
          CafePoint(x, .0, a),
          CafePoint(x, .0, b),
          CafePoint(x + .344, .0, b),
          CafePoint(x + .344, .0, a),
          tone,
          wood: true,
          layer: 0,
        );
      }
    }
    // Four enclosing walls and an actual ceiling, rather than a backdrop.
    void wallGrid(
      CafePoint a,
      CafePoint b,
      CafePoint c,
      CafePoint d,
      Color color, {
      bool unlit = false,
      int u = 12,
      int v = 5,
    }) {
      for (var i = 0; i < u; i++) {
        for (var j = 0; j < v; j++) {
          CafePoint at(double s, double t) => CafePoint.lerp(
            CafePoint.lerp(a, b, s),
            CafePoint.lerp(d, c, s),
            t,
          );
          quad(
            at(i / u, j / v),
            at((i + 1) / u, j / v),
            at((i + 1) / u, (j + 1) / v),
            at(i / u, (j + 1) / v),
            color,
            unlit: unlit,
            layer: 0,
          );
        }
      }
    }

    wallGrid(
      const CafePoint(-4, 0, -5.5),
      const CafePoint(4, 0, -5.5),
      const CafePoint(4, 3.35, -5.5),
      const CafePoint(-4, 3.35, -5.5),
      wall,
    );
    wallGrid(
      const CafePoint(4, 0, -5.5),
      const CafePoint(4, 0, 5.5),
      const CafePoint(4, 3.35, 5.5),
      const CafePoint(4, 3.35, -5.5),
      const Color(0xffcabea7),
    );
    wallGrid(
      const CafePoint(4, 0, 5.5),
      const CafePoint(-4, 0, 5.5),
      const CafePoint(-4, 3.35, 5.5),
      const CafePoint(4, 3.35, 5.5),
      wall,
    );
    wallGrid(
      const CafePoint(-4, 0, 5.5),
      const CafePoint(-4, 0, -5.5),
      const CafePoint(-4, 3.35, -5.5),
      const CafePoint(-4, 3.35, 5.5),
      const Color(0xffd4c9b1),
    );
    wallGrid(
      const CafePoint(-4, 3.35, 5.5),
      const CafePoint(-4, 3.35, -5.5),
      const CafePoint(4, 3.35, -5.5),
      const CafePoint(4, 3.35, 5.5),
      const Color(0xffe2d6bf),
    );
    box(0, .09, -5.45, 8, .18, .1, dark, wood: true);
    box(3.95, .09, 0, .1, .18, 11, dark, wood: true);
    box(-3.95, .09, 0, .1, .18, 11, dark, wood: true);
    // Tall windows on the left wall, with distant greenery beyond glass.
    for (final z in [-3.9, -1.15, 1.6, 4.1]) {
      box(-3.91, 1.90, z - 1.10, .10, 1.92, .065, dark, wood: true);
      box(-3.91, 1.90, z + 1.10, .10, 1.92, .065, dark, wood: true);
      box(-3.91, .96, z, .10, .065, 2.25, dark, wood: true);
      box(-3.91, 2.84, z, .10, .065, 2.25, dark, wood: true);
      for (var i = 0; i < 4; i++) {
        for (var j = 0; j < 4; j++) {
          final u = i / 4, v = j / 4, du = (i + 1) / 4, dv = (j + 1) / 4;
          CafePoint point(double u, double v) =>
              CafePoint(-3.835, 2.81 - v * 1.82, z - 1.06 + u * 2.12);
          faces.add(
            CafeFace(
              [point(u, dv), point(du, dv), point(du, v), point(u, v)],
              const Color(0xffc4d1c2),
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
      // Glass streaks and mullions have their own depth, and follow perspective.
      for (var i = 0; i < 20; i++) {
        final zz = z - 1 + random.nextDouble() * 2;
        final yy = 1.10 + random.nextDouble() * 1.5;
        quad(
          CafePoint(-3.81, yy, zz),
          CafePoint(-3.81, yy + .11, zz + .014),
          CafePoint(-3.81, yy + .11, zz + .02),
          CafePoint(-3.81, yy, zz + .006),
          const Color(0x55ffffff),
          unlit: true,
        );
      }
      box(-3.79, 1.9, z, .12, 1.9, .045, dark, wood: true);
      box(-3.79, 1.68, z, .12, .055, 2.2, dark, wood: true);
      box(-3.75, .96, z, .37, .055, 2.4, oak, wood: true);
      // Soft pools of daylight across the floor.
      for (var i = 0; i < 3; i++) {
        final xx = -3.7 + i * .65;
        quad(
          CafePoint(xx, .006, z - .95),
          CafePoint(xx + .62, .006, z - .95),
          CafePoint(xx + 1.2, .006, z + .9),
          CafePoint(xx + .58, .006, z + .9),
          Color.fromRGBO(255, 231, 178, .055 - i * .012),
          unlit: true,
          layer: 1,
        );
      }
    }
    _table(CafeSeat.window);
    _table(CafeSeat.shared, width: 1.9);
    _table(CafeSeat.quiet);
    // Coffee counter, ribbed wooden front, stone worktop.
    obstacles.add(const Rect.fromLTWH(-.35, -5.4, 3.8, 1.1));
    box(1.4, .50, -4.93, 3.7, 1, .9, oak, wood: true);
    for (var i = 0; i < 36; i++) {
      box(-.38 + i * .10, .48, -4.45, .022, .91, .028, dark);
    }
    box(1.4, 1.035, -4.93, 3.88, .085, 1.02, const Color(0xffb2a99a));
    box(1.35, 1.30, -5.02, .75, .43, .43, const Color(0xff44423b));
    box(1.35, 1.30, -4.79, .67, .25, .025, const Color(0xffb5b0a3));
    for (final x in [1.18, 1.52]) {
      cylinder(x, 1.15, -4.70, .065, .11, cream);
    }
    cylinder(2.25, 1.27, -5.05, .12, .36, dark);
    cylinder(
      2.25,
      1.53,
      -5.05,
      .12,
      .20,
      const Color(0xff7c7261),
      topRadius: .085,
    );
    for (var i = 0; i < 5; i++) {
      cylinder(.15 + i * .14, 1.12, -4.92, .045, .09, cream);
    }
    box(-.25, 2.05, -5.40, 1.8, .83, .06, dark, wood: true);
    faces.add(
      CafeFace(
        [
          const CafePoint(-1.10, 1.68, -5.355),
          const CafePoint(.60, 1.68, -5.355),
          const CafePoint(.60, 2.42, -5.355),
          const CafePoint(-1.10, 2.42, -5.355),
        ],
        cream,
        sign: true,
        unlit: true,
      ),
    );
    // Right wall bookcase; book spines catch the warm room light.
    box(3.72, 1.28, -.7, .45, 2.5, 2.9, dark, wood: true);
    for (var row = 0; row < 5; row++) {
      final y = .24 + row * .47;
      box(3.43, y, -.7, .65, .055, 3, oak, wood: true);
      for (var i = 0; i < 17; i++) {
        final h = .24 + random.nextDouble() * .13;
        final colors = [
          sage,
          const Color(0xff97735d),
          const Color(0xffb6a682),
          const Color(0xff65787b),
          const Color(0xff845b4b),
        ];
        box(
          3.45,
          y + h / 2 + .03,
          -2.04 + i * .16,
          .35,
          h,
          .10,
          colors[(i + row) % colors.length],
        );
        box(3.264, y + h - .02, -2.04 + i * .16, .004, .008, .078, brass);
      }
    }
    obstacles.add(const Rect.fromLTWH(3.15, -2.3, .8, 3.3));
    // Ceiling beams and practical pendant lights.
    for (final z in [-4.0, -.8, 2.5]) {
      box(0, 3.22, z, 8, .15, .13, dark, wood: true);
      cylinder(.1, 2.92, z, .012, .55, dark, sides: 5);
      cylinder(.1, 2.60, z, .29, .19, sage, topRadius: .10, sides: 20);
      cylinder(
        .1,
        2.502,
        z,
        .255,
        .006,
        const Color(0xffffd49a),
        sides: 20,
        unlit: true,
      );
    }
    // Linen bench, framed prints, small pots and entrance rug.
    box(2.8, .43, 2.9, 1.6, .40, .65, const Color(0xff787d65));
    box(2.8, .83, 3.18, 1.6, .53, .14, const Color(0xff878970));
    for (final x in [2.18, 3.40]) {
      box(x, .15, 2.9, .06, .3, .5, dark);
    }
    obstacles.add(const Rect.fromLTWH(1.95, 2.50, 1.75, .9));
    for (final z in [1.9, 3.6]) {
      box(3.93, 2.1, z, .065, .8, .63, dark, wood: true);
      box(3.89, 2.1, z, .012, .71, .54, cream);
      box(3.88, 2.12, z, .014, .44, .30, sage);
    }
    _plant(-3.2, -4.80, height: 1.35);
    _plant(3.1, 4.2, height: 1.10);
    _plant(-3.45, 2.8, height: .55);
    quad(
      const CafePoint(-.9, .008, 3.9),
      const CafePoint(-.9, .008, 5.3),
      const CafePoint(1.6, .008, 5.3),
      const CafePoint(1.6, .008, 3.9),
      const Color(0xff828269),
    );
    for (var i = 0; i < 23; i++) {
      box(.35, .012, 3.94 + i * .058, 2.4, .003, .009, const Color(0xffa19f80));
    }
    // The door remains visible when looking back at the entrance.
    box(.35, 1.35, 5.43, 1.45, 2.7, .10, dark, wood: true);
    box(.35, 1.62, 5.36, 1.23, 1.9, .025, const Color(0xff8d9b8b));
    box(.35, .35, 5.35, 1.25, .46, .06, oak, wood: true);
    cylinder(.87, 1.18, 5.28, .024, .28, brass, sides: 8);
  }
}
