import 'dart:math' as math;
import 'dart:ui';

import 'cafe_camera.dart';
import 'cafe_visit.dart';

part 'cafe_courtyard.dart';
part 'cafe_interior.dart';

enum CafeSurface {
  plain,
  oak,
  walnut,
  limestone,
  cord,
  brass,
  plaster,
  artwork,
  gravel,
  tree,
  flowers,
  water,
}

enum CafeGrain { x, y, z }

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
    CafeSurface? surface,
    this.grain = CafeGrain.y,
    this.vertexNormals,
    this.vertexColors,
  }) : surface =
           surface ??
           (wood
               ? (color == CafeWorld.oak ? CafeSurface.oak : CafeSurface.walnut)
               : color == CafeWorld.brass
               ? CafeSurface.brass
               : CafeSurface.plain);
  final CafeSurface surface;
  final CafeGrain grain;
  final List<CafePoint>? vertexNormals;
  final List<Color>? vertexColors;
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

class CafePlant {
  const CafePlant(
    this.base,
    this.width,
    this.height,
    this.surface, {
    this.flip = false,
  });
  final CafePoint base;
  final double width, height;
  final CafeSurface surface;
  final bool flip;
}

/// All geometry is in metres. The viewer stands inside the same room they visit.
class CafeWorld {
  CafeWorld({this.courtyard = false}) {
    _buildRoom();
    linkedWorld = CafeWorld._room(!courtyard);
    linkedWorld.linkedWorld = this;
  }
  CafeWorld._room(this.courtyard) {
    _buildRoom();
  }
  late CafeWorld linkedWorld;
  void _buildRoom() {
    if (courtyard) {
      _buildCourtyard();
    } else {
      _build();
    }
    _subdividePrints();
  }

  CafeCamera linkedCamera(CafeCamera camera) => CafeCamera(
    position: courtyard
        ? CafePoint(
            camera.position.z - 7.4,
            camera.position.y,
            -camera.position.x,
          )
        : CafePoint(
            -camera.position.z,
            camera.position.y,
            camera.position.x + 7.4,
          ),
    yaw: camera.yaw + (courtyard ? -math.pi / 2 : math.pi / 2),
    pitch: camera.pitch,
  );
  final bool courtyard;
  Iterable<CafeTarget> get targets =>
      CafeTarget.values.where((t) => t.inCourtyard == courtyard);
  final List<CafeFace> faces = [];
  final List<Rect> obstacles = [];
  final List<CafePlant> plants = [];
  final List<CafePoint> pendantLights = [];
  Iterable<CafeFace> lightFaces(CafeCamera camera) sync* {
    for (final center in pendantLights) {
      for (var ring = 0; ring < 3; ring++) {
        final inner = ring / 3, outer = (ring + 1) / 3;
        Color color(double radius) =>
            Color.fromRGBO(255, 218, 163, .16 * (1 - radius) * (1 - radius));
        CafePoint at(double r, double a) =>
            center +
            camera.right * (math.cos(a) * r * .16) +
            camera.up * (math.sin(a) * r * .16);
        for (var i = 0; i < 16; i++) {
          final a = i * math.pi / 8, b = (i + 1) * math.pi / 8;
          yield CafeFace(
            [at(inner, a), at(outer, a), at(outer, b), at(inner, b)],
            color(inner),
            unlit: true,
            doubleSided: true,
            vertexColors: [
              color(inner),
              color(outer),
              color(outer),
              color(inner),
            ],
          );
        }
      }
    }
  }

  Iterable<CafeFace> plantFaces(CafeCamera camera) sync* {
    final across = CafePoint(camera.right.x, 0, camera.right.z).normalized;
    for (final plant in plants) {
      final nx = plant.surface == CafeSurface.tree ? 6 : 3,
          ny = plant.surface == CafeSurface.tree ? 8 : 3;
      CafePoint point(double u, double v) =>
          plant.base +
          across * ((u - .5) * plant.width) +
          CafePoint(0, (1 - v) * plant.height, 0);
      Offset uv(double u, double v) => Offset(plant.flip ? 1 - u : u, v);
      for (var x = 0; x < nx; x++) {
        for (var y = 0; y < ny; y++) {
          final u = x / nx, v = y / ny, uu = (x + 1) / nx, vv = (y + 1) / ny;
          yield CafeFace(
            [point(u, vv), point(uu, vv), point(uu, v), point(u, v)],
            const Color(0xffffffff),
            surface: plant.surface,
            unlit: true,
            doubleSided: true,
            textureCoordinates: [uv(u, vv), uv(uu, vv), uv(uu, v), uv(u, v)],
          );
        }
      }
    }
  }

  static const wall = Color(0xffddd2bd),
      oak = Color(0xffac835b),
      dark = Color(0xff4e392b);
  static const brass = Color(0xffb59964),
      sage = Color(0xff58634f),
      cream = Color(0xffeee4cf);
  CafeTarget? _target;
  static const mochaFloor = Color(0xff827163);
  static const halfWidth = 4.4, halfDepth = 5.0, ceiling = 2.95;
  static CafePoint desk(CafeSeat seat) => switch (seat) {
    CafeSeat.window => const CafePoint(-3.72, .77, 1.9),
    CafeSeat.shared => const CafePoint(.24, .77, .75),
    CafeSeat.quiet => const CafePoint(-2.25, .77, -4.02),
    CafeSeat.windowMiddle => const CafePoint(-3.72, .77, -.3),
    CafeSeat.windowRear => const CafePoint(-3.72, .77, -2.5),
    CafeSeat.garden => const CafePoint(3.28, .77, .58),
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
    CafeTarget.courtyard => const CafePoint(-4.18, 1.45, -3.8),
    CafeTarget.pond => const CafePoint(-1.25, .08, 1.0),
    CafeTarget.bench => const CafePoint(4.0, .65, -.7),
    CafeTarget.bell => const CafePoint(3.15, 1.62, 3.03),
    CafeTarget.tea => const CafePoint(3.22, .84, .93),
    CafeTarget.gardenDesk => desk(CafeSeat.garden),
    CafeTarget.cafeReturn => const CafePoint(3.8, 1.3, 3.16),
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
    CafeTarget.courtyard => const CafePoint(-4.08, 1.62, -3.8),
    CafeTarget.pond => const CafePoint(.3, 1.62, 1.0),
    CafeTarget.bench => const CafePoint(2.95, 1.62, -.7),
    CafeTarget.bell => const CafePoint(3.15, 1.62, 2.15),
    CafeTarget.tea || CafeTarget.gardenDesk => const CafePoint(2.1, 1.62, 1.6),
    CafeTarget.cafeReturn => const CafePoint(3.8, 1.62, 2.35),
  };
  static Rect tableBounds(CafeSeat seat) => switch (seat) {
    CafeSeat.window => const Rect.fromLTWH(-4.12, 1.22, .72, 1.36),
    CafeSeat.shared => const Rect.fromLTWH(-.575, -1.65, 1.15, 3),
    CafeSeat.quiet => const Rect.fromLTWH(-2.95, -4.42, 1.4, .8),
    CafeSeat.windowMiddle => const Rect.fromLTWH(-4.12, -.98, .72, 1.36),
    CafeSeat.windowRear => const Rect.fromLTWH(-4.12, -3.18, .72, 1.36),
    CafeSeat.garden => const Rect.fromLTWH(2.68, .08, .9, 1.0),
  };
  bool canStand(CafePoint p) =>
      p.isFinite &&
      p.x.abs() < (courtyard ? 4.4 : halfWidth - .25) &&
      p.z.abs() < (courtyard ? 2.8 : halfDepth - .25) &&
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
    CafeSurface? surface,
    CafeGrain grain = CafeGrain.y,
    List<CafePoint>? normals,
    List<Color>? colors,
  }) {
    // Small solids need local painter depths: a single long apron face would
    // otherwise paint across the tabletop or objects resting on it.
    final across = layer >= 2 && !unlit
        ? math.max(1, ((b - a).length / .28).ceil())
        : 1;
    final down = layer >= 2 && !unlit
        ? math.max(1, ((d - a).length / .28).ceil())
        : 1;
    CafePoint at(double u, double v) =>
        CafePoint.lerp(CafePoint.lerp(a, b, u), CafePoint.lerp(d, c, u), v);
    CafePoint normalAt(double u, double v) => CafePoint.lerp(
      CafePoint.lerp(normals![0], normals[1], u),
      CafePoint.lerp(normals[3], normals[2], u),
      v,
    ).normalized;
    for (var i = 0; i < across; i++) {
      for (var j = 0; j < down; j++) {
        final u = i / across,
            v = j / down,
            uu = (i + 1) / across,
            vv = (j + 1) / down;
        faces.add(
          CafeFace(
            [at(u, v), at(uu, v), at(uu, vv), at(u, vv)],
            color,
            wood: wood,
            unlit: unlit,
            layer: layer,
            target: _target,
            surface: surface,
            grain: grain,
            vertexNormals: normals == null
                ? null
                : [
                    normalAt(u, v),
                    normalAt(uu, v),
                    normalAt(uu, vv),
                    normalAt(u, vv),
                  ],
            vertexColors: colors,
          ),
        );
      }
    }
  }

  void box(
    double x,
    double y,
    double z,
    double w,
    double h,
    double d,
    Color color, {
    bool wood = false,
    CafeSurface? surface,
    CafeGrain? grain,
    bool topFace = true,
  }) {
    final axis =
        grain ??
        (h > w && h > d
            ? CafeGrain.y
            : w >= d
            ? CafeGrain.x
            : CafeGrain.z);
    final l = x - w / 2,
        r = x + w / 2,
        b = y - h / 2,
        t = y + h / 2,
        n = z - d / 2,
        f = z + d / 2;
    if (topFace) {
      quad(
        CafePoint(l, t, f),
        CafePoint(r, t, f),
        CafePoint(r, t, n),
        CafePoint(l, t, n),
        color,
        wood: wood,
        surface: surface,
        grain: axis,
      );
    }
    quad(
      CafePoint(l, b, n),
      CafePoint(r, b, n),
      CafePoint(r, b, f),
      CafePoint(l, b, f),
      color,
      wood: wood,
      surface: surface,
      grain: axis,
    );
    quad(
      CafePoint(l, b, f),
      CafePoint(r, b, f),
      CafePoint(r, t, f),
      CafePoint(l, t, f),
      color,
      wood: wood,
      surface: surface,
      grain: axis,
    );
    quad(
      CafePoint(r, b, n),
      CafePoint(l, b, n),
      CafePoint(l, t, n),
      CafePoint(r, t, n),
      color,
      wood: wood,
      surface: surface,
      grain: axis,
    );
    quad(
      CafePoint(r, b, f),
      CafePoint(r, b, n),
      CafePoint(r, t, n),
      CafePoint(r, t, f),
      color,
      wood: wood,
      surface: surface,
      grain: axis,
    );
    quad(
      CafePoint(l, b, n),
      CafePoint(l, b, f),
      CafePoint(l, t, f),
      CafePoint(l, t, n),
      color,
      wood: wood,
      surface: surface,
      grain: axis,
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
    bool topFace = true,
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
      final na = CafePoint(
        math.cos(a),
        (radius - rt) / height,
        math.sin(a),
      ).normalized;
      final nb = CafePoint(
        math.cos(b),
        (radius - rt) / height,
        math.sin(b),
      ).normalized;
      quad(p, s, r, q, color, unlit: unlit, normals: [na, na, nb, nb]);
      if (topFace) {
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
  }

  void shadow(
    double x,
    double z,
    double rx,
    double rz, {
    double strength = .12,
    double y = .012,
    int layer = 1,
  }) {
    final count = rx < .12 ? 10 : 20;
    final bands = rx < .12 ? 3 : 4;
    for (var ring = 0; ring < bands; ring++) {
      final inner = ring / bands, outer = (ring + 1) / bands;
      Color shade(double radius) =>
          Color.fromRGBO(43, 32, 22, strength * math.pow(1 - radius, 1.6));
      for (var i = 0; i < count; i++) {
        final a = i * 2 * math.pi / count, b = (i + 1) * 2 * math.pi / count;
        CafePoint at(double radius, double angle) => CafePoint(
          x + math.cos(angle) * rx * radius,
          y,
          z + math.sin(angle) * rz * radius,
        );
        quad(
          at(inner, a),
          at(outer, a),
          at(outer, b),
          at(inner, b),
          shade(inner),
          unlit: true,
          layer: layer,
          colors: [shade(inner), shade(outer), shade(outer), shade(inner)],
        );
      }
    }
  }

  /// Rounded solid timber with a real bevel, subdivided for local light pools.
  void _roundedSlab(
    double x,
    double z,
    double width,
    double depth, {
    double top = .7525,
    double thickness = .035,
    double radius = .065,
    CafeSurface surface = CafeSurface.oak,
    Color color = oak,
  }) {
    final axis = depth >= width ? CafeGrain.z : CafeGrain.x;
    List<CafePoint> ring(double inset, double y) {
      final w = width / 2 - inset, d = depth / 2 - inset, r = radius - inset;
      final points = <CafePoint>[];
      for (final corner in [
        (-w + r, d - r, math.pi),
        (w - r, d - r, math.pi / 2),
        (w - r, -d + r, 0.0),
        (-w + r, -d + r, -math.pi / 2),
      ]) {
        for (var i = 0; i < 5; i++) {
          final angle = corner.$3 - i * math.pi / 8;
          points.add(
            CafePoint(
              x + corner.$1 + math.cos(angle) * r,
              y,
              z + corner.$2 + math.sin(angle) * r,
            ),
          );
        }
      }
      return points;
    }

    final upper = ring(.005, top),
        side = ring(0, top - .005),
        bottom = ring(0, top - thickness);
    // Clip a fine regular grid to the rounded outline. Radial fans have long
    // triangles whose average depth can incorrectly cover a notebook or cup.
    final nx = (width / .05).ceil(), nz = (depth / .05).ceil();
    for (var ix = 0; ix < nx; ix++) {
      for (var iz = 0; iz < nz; iz++) {
        final l = x - width / 2 + ix * width / nx,
            r = x - width / 2 + (ix + 1) * width / nx,
            n = z - depth / 2 + iz * depth / nz,
            f = z - depth / 2 + (iz + 1) * depth / nz;
        var polygon = [
          CafePoint(l, top, f),
          CafePoint(r, top, f),
          CafePoint(r, top, n),
          CafePoint(l, top, n),
        ];
        for (var edge = 0; edge < upper.length && polygon.isNotEmpty; edge++) {
          final a = upper[edge], b = upper[(edge + 1) % upper.length];
          double side(CafePoint p) =>
              (b.x - a.x) * (p.z - a.z) - (b.z - a.z) * (p.x - a.x);
          final clipped = <CafePoint>[];
          for (var i = 0; i < polygon.length; i++) {
            final start = polygon[i],
                end = polygon[(i + 1) % polygon.length],
                ds = side(start),
                de = side(end);
            if (ds <= 1e-9) clipped.add(start);
            if ((ds <= 1e-9) != (de <= 1e-9)) {
              clipped.add(CafePoint.lerp(start, end, ds / (ds - de)));
            }
          }
          polygon = clipped;
        }
        if (polygon.length >= 3) {
          faces.add(
            CafeFace(
              polygon,
              color,
              surface: surface,
              grain: axis,
              target: _target,
            ),
          );
        }
      }
    }
    for (var i = 0; i < upper.length; i++) {
      final next = (i + 1) % upper.length;
      quad(
        upper[i],
        side[i],
        side[next],
        upper[next],
        color,
        surface: surface,
        grain: axis,
      );
      quad(
        side[i],
        bottom[i],
        bottom[next],
        side[next],
        color,
        surface: surface,
        grain: axis,
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

    box(
      x,
      .43,
      z,
      .47,
      .055,
      .45,
      const Color(0xffd8c095),
      surface: CafeSurface.cord,
    );
    for (final dx in [-.18, .18]) {
      for (final dz in [-.16, .16]) {
        part(dx, .21, dz, .035, .42, .035, dark);
        final foot = rot(dx, 0, dz);
        shadow(foot.x, foot.z, .065, .065, strength: .19);
      }
      part(dx, .59, .16, .035, .36, .035, dark);
    }
    // A sculpted round rail, not flat rectangular arc segments.
    CafePoint rotateNormal(CafePoint n) => CafePoint(
      n.x * math.cos(angle) - n.z * math.sin(angle),
      n.y,
      n.x * math.sin(angle) + n.z * math.cos(angle),
    );
    for (var i = 0; i < 18; i++) {
      final a = i * math.pi / 18, b = (i + 1) * math.pi / 18;
      for (var j = 0; j < 8; j++) {
        final u = j * math.pi / 4, v = (j + 1) * math.pi / 4;
        CafePoint normal(double t, double q) =>
            (CafePoint(math.cos(t), 0, math.sin(t)) * math.cos(q) +
                    const CafePoint(0, 1, 0) * math.sin(q))
                .normalized;
        CafePoint at(double t, double q) {
          final n = normal(t, q);
          return rot(
            math.cos(t) * .245 + n.x * .026,
            .77 + n.y * .026,
            math.sin(t) * .21 - .02 + n.z * .026,
          );
        }

        var points = [at(a, u), at(b, u), at(b, v), at(a, v)];
        var normals = [
          rotateNormal(normal(a, u)),
          rotateNormal(normal(b, u)),
          rotateNormal(normal(b, v)),
          rotateNormal(normal(a, v)),
        ];
        if ((points[1] - points[0])
                .cross(points[2] - points[0])
                .dot(normals[0]) <
            0) {
          points = points.reversed.toList();
          normals = normals.reversed.toList();
        }
        faces.add(
          CafeFace(
            points,
            dark,
            surface: CafeSurface.walnut,
            grain: math.cos(angle).abs() > .5 ? CafeGrain.x : CafeGrain.z,
            vertexNormals: normals,
            target: _target,
          ),
        );
      }
    }
    obstacles.add(
      Rect.fromCenter(center: Offset(x, z), width: .48, height: .45),
    );
    shadow(x, z, .32, .3, strength: .045);
  }

  void _book(double x, double y, double z, {double angle = 0}) {
    final firstFace = faces.length;
    shadow(x + .012, z + .015, .29, .20, y: y - .014, layer: 2, strength: .13);
    box(x, y, z, .43, .018, .30, sage, topFace: false);
    box(x, y + .013, z, .40, .016, .28, cream, topFace: false);
    // Expose only the cover border, not an opaque full face under the pages.
    // A full backing sorts in front of small page patches at low eye angles.
    for (final xx in [x - .2075, x + .2075]) {
      box(xx, y, z, .015, .018, .30, sage);
    }
    for (final zz in [z - .145, z + .145]) {
      box(x, y, zz, .40, .018, .01, sage);
    }
    for (final side in [-1, 1]) {
      final center = x + side * .104;
      box(
        center,
        y + .023,
        z,
        .19,
        .009,
        .276,
        const Color(0xfff5efdf),
        topFace: false,
      );
      faces.add(
        CafeFace(
          [
            CafePoint(center - .095, y + .0275, z + .138),
            CafePoint(center + .095, y + .0275, z + .138),
            CafePoint(center + .095, y + .0275, z - .138),
            CafePoint(center - .095, y + .0275, z - .138),
          ],
          const Color(0xfff5efdf),
          surface: CafeSurface.artwork,
          target: _target,
          textureCoordinates: const [
            Offset(0, 1),
            Offset(1, 1),
            Offset(1, 2 / 3),
            Offset(0, 2 / 3),
          ],
        ),
      );
    }
    box(x, y + .027, z, .007, .009, .28, const Color(0xffbfb29b));
    if (angle != 0) {
      final c = math.cos(angle), s = math.sin(angle);
      for (final face in faces.skip(firstFace)) {
        for (var i = 0; i < face.points.length; i++) {
          final p = face.points[i], dx = p.x - x, dz = p.z - z;
          face.points[i] = CafePoint(
            x + dx * c - dz * s,
            p.y,
            z + dx * s + dz * c,
          );
        }
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
    pendantLights.add(CafePoint(x, 2.175, z));
    cylinder(x, 2.65, z, .012, .56, dark, sides: 5);
    cylinder(x, 2.28, z, radius, .20, brass, topRadius: .08, sides: 24);
    cylinder(x, 2.407, z, .042, .055, brass, sides: 16);
    cylinder(x, 2.181, z, radius * 1.015, .018, brass, sides: 24);
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
    _roundedSlab(x, z, bounds.width, bounds.height);
    box(
      x,
      .682,
      z,
      bounds.width - .16,
      .055,
      bounds.height - .16,
      dark,
      wood: true,
      topFace: false,
    );
    for (final dx in [-bounds.width / 2 + .10, bounds.width / 2 - .10]) {
      for (final dz in [-bounds.height / 2 + .10, bounds.height / 2 - .10]) {
        box(x + dx, .34, z + dz, .055, .68, .055, dark, wood: true);
        shadow(x + dx, z + dz, .085, .085, strength: .20);
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
      final step = color == wall ? .24 : .65;
      final nx = ((b - a).length / step).ceil(),
          ny = ((d - a).length / step).ceil();
      for (var i = 0; i < nx; i++) {
        for (var j = 0; j < ny; j++) {
          CafePoint at(double u, double v) => CafePoint.lerp(
            CafePoint.lerp(a, b, u),
            CafePoint.lerp(d, c, u),
            v,
          );
          quad(
            at(i / nx, j / ny),
            at((i + 1) / nx, j / ny),
            at((i + 1) / nx, (j + 1) / ny),
            at(i / nx, (j + 1) / ny),
            color,
            surface: color == wall ? CafeSurface.plaster : null,
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
      const Color(0xff7d6b59),
      layer: -1,
    );
    for (var row = 0; row < 15; row++) {
      final left = -w + row * .6 + .001,
          right = math.min(w, -w + (row + 1) * .6 - .001);
      for (var col = 0; col < 12; col++) {
        final back = -d + col * .9 + .001,
            front = math.min(d, -d + (col + 1) * .9 - .001);
        if (front <= back || right <= left) continue;
        final u = random.nextDouble(), v = random.nextDouble();
        final tone = Color.lerp(
          mochaFloor,
          const Color(0xff8a796a),
          random.nextDouble() * .36,
        )!;
        faces.add(
          CafeFace(
            [
              CafePoint(left, 0, back),
              CafePoint(left, 0, front),
              CafePoint(right, 0, front),
              CafePoint(right, 0, back),
            ],
            tone,
            surface: CafeSurface.limestone,
            layer: 0,
            textureCoordinates: [
              Offset(u, v),
              Offset(u, v + (front - back) / 2.4),
              Offset(u + (right - left) / 2.4, v + (front - back) / 2.4),
              Offset(u + (right - left) / 2.4, v),
            ],
          ),
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
    // One continuous outdoor panorama, wooden reveals and reflected daylight.
    for (final z in [-3.35, -1.05, 1.25, 3.55]) {
      for (final dz in [-1.08, 1.08]) {
        box(-4.31, 1.72, z + dz, .12, 2.25, .07, dark, wood: true);
      }
      box(-4.30, .61, z, .12, .07, 2.20, dark, wood: true);
      box(-4.30, 2.83, z, .12, .07, 2.20, dark, wood: true);
      // The renderer samples one distant garden plane in room coordinates.
      for (var i = 0; i < 8; i++) {
        for (var j = 0; j < 8; j++) {
          final u = i / 8, v = j / 8, du = (i + 1) / 8, dv = (j + 1) / 8;
          CafePoint at(double u, double v) =>
              CafePoint(-4.235, 2.78 - v * 2.12, z - 1.02 + u * 2.04);
          final points = [at(u, dv), at(du, dv), at(du, v), at(u, v)];
          faces.add(
            CafeFace(
              points,
              const Color(0xffdce5cf),
              garden: true,
              unlit: true,
              layer: 1,
            ),
          );
        }
      }
      box(-4.20, 1.70, z, .12, 2.2, .04, dark, wood: true);
      box(-4.20, .63, z, .30, .055, 2.20, oak, wood: true);
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
      _book(-3.72, .773, z, angle: math.pi / 2);
      _cup(-3.8, .767, z - .40);
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
    _book(.24, .773, .75, angle: math.pi / 2);
    _book(-.23, .773, -.85, angle: -math.pi / 2);
    _pencil(.29, .806, .49);
    _cup(-.2, .767, .18);
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
    const alcove = Color(0xff8d856c);
    box(-2.25, .94, -4.81, 1.7, 1.82, .035, alcove);
    for (final x in [-3.16, -1.34]) {
      box(x, .94, -4.68, .12, 1.82, .32, dark, wood: true);
    }
    for (var i = 0; i < 24; i++) {
      final a = i * math.pi / 24, b = (i + 1) * math.pi / 24;
      CafePoint arch(double angle, double radius, double z) => CafePoint(
        -2.25 + math.cos(angle) * radius,
        1.85 + math.sin(angle) * radius,
        z,
      );
      faces.add(
        CafeFace([
          const CafePoint(-2.25, 1.85, -4.79),
          arch(a, .86, -4.79),
          arch(b, .86, -4.79),
        ], alcove),
      );
      quad(
        arch(a, .97, -4.52),
        arch(b, .97, -4.52),
        arch(b, .85, -4.52),
        arch(a, .85, -4.52),
        dark,
        wood: true,
        grain: CafeGrain.x,
      );
      quad(
        arch(a, .85, -4.52),
        arch(b, .85, -4.52),
        arch(b, .85, -4.80),
        arch(a, .85, -4.80),
        dark,
        wood: true,
        grain: CafeGrain.x,
      );
    }
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
    _roundedSlab(
      .95,
      -4.47,
      3.32,
      .91,
      top: 1.05,
      thickness: .07,
      radius: .045,
      surface: CafeSurface.limestone,
      color: const Color(0xfff5eee2),
    );
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
    // The garden entrance is on the same left facade as its windows.
    _target = CafeTarget.courtyard;
    for (final z in [-4.34, -3.26]) {
      box(-4.15, 1.33, z, .12, 2.66, .075, dark, wood: true);
    }
    box(-4.15, 2.66, -3.8, .12, .075, 1.16, dark, wood: true);
    faces.add(
      CafeFace(
        const [
          CafePoint(-4.19, 0, -4.3),
          CafePoint(-4.19, 0, -3.3),
          CafePoint(-4.19, 2.62, -3.3),
          CafePoint(-4.19, 2.62, -4.3),
        ],
        cream,
        garden: true,
        unlit: true,
        layer: 1,
        target: _target,
      ),
    );
    box(-4.08, 1.12, -3.4, .03, .26, .04, brass);
    box(-4.15, .015, -3.8, .25, .025, 1.06, brass);
    _target = null;
    _framedPrint(3.15, 1.91, -4.91, .84, 1.12, 0);
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
    _book(3.87, .947, 2.4, angle: math.pi / 2);
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
    _interiorDetails();
  }
}
