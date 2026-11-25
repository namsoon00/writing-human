import 'dart:math' as math;
import 'dart:ui';

import 'cafe_camera.dart';
import 'cafe_world.dart';

/// The approved A outfit. All dimensions are metres; the mesh shares the room's
/// lighting and depth ordering. No character state is written into a record.
class CafeAvatar {
  CafeAvatar({
    required this.eye,
    required this.yaw,
    this.phase = 0,
    this.stride = 0,
    this.use,
    this.object,
  });
  static const id = 'avatar.a.male';
  final CafeCamera eye;
  final double yaw, phase, stride;
  final CafeUseFrame? use;
  final CafeObject? object;
  late final double seated = ((1.62 - eye.position.y) / .32).clamp(0, 1);
  late final CafePoint origin = CafePoint(eye.position.x, 0, eye.position.z);
  late final List<CafeFace> faces = _build();
  CafePoint _rotate(CafePoint p) => CafePoint(
    p.x * math.cos(yaw) - p.z * math.sin(yaw),
    p.y,
    p.x * math.sin(yaw) + p.z * math.cos(yaw),
  );
  CafePoint _local(CafePoint p) {
    final d = p - origin;
    return CafePoint(
      d.x * math.cos(yaw) + d.z * math.sin(yaw),
      d.y,
      -d.x * math.sin(yaw) + d.z * math.cos(yaw),
    );
  }

  List<CafeFace> _build() {
    final m = _AvatarMesh((p) => origin + _rotate(p), _rotate);
    const skin = Color(0xffe2b794), hair = Color(0xff5b4233);
    const shirt = Color(0xffe8ddc9), seam = Color(0xffc8bca5);
    const pants = Color(0xff766051), shoe = Color(0xffa7815d);
    final down = seated * .33;
    final bob = (1 - seated) * stride * .009 * (1 - math.cos(phase * 2));
    CafePoint torso(double x, double y, double z) =>
        CafePoint(x, y - down + bob, z);
    m.loft(
      [
        (torso(0, .86, 0), .196, .125),
        (torso(0, .92, 0), .196, .125),
        (torso(0, 1.08, 0), .180, .115),
        (torso(0, 1.25, 0), .208, .127),
        (torso(0, 1.37, .006), .223, .112),
        (torso(0, 1.43, .006), .157, .080),
        (torso(0, 1.46, .005), .072, .060),
      ],
      shirt,
      'linen',
      sides: 16,
    );
    m.ellipsoid(
      torso(0, 1.475, 0),
      const CafePoint(.061, .09, .057),
      skin,
      'neck',
      slices: 10,
      rings: 5,
    );
    m.ellipsoid(
      torso(0, 1.624, -.008),
      const CafePoint(.111, .145, .104),
      skin,
      'face',
      slices: 16,
      rings: 10,
    );
    // Ears, small nose, eyelids, irises and a quiet neutral mouth.
    for (final side in [-1.0, 1.0]) {
      m.ellipsoid(
        torso(side * .110, 1.616, -.002),
        const CafePoint(.018, .029, .014),
        skin,
        'ear',
        slices: 8,
        rings: 5,
      );
      m.ellipsoid(
        torso(side * .111, 1.616, -.014),
        const CafePoint(.009, .017, .004),
        const Color(0xffba8b6e),
        'ear.fold',
        slices: 6,
        rings: 4,
      );
      m.ellipsoid(
        torso(side * .043, 1.642, -.101),
        const CafePoint(.022, .010, .005),
        const Color(0xffece0c9),
        'eyelid',
        slices: 8,
        rings: 4,
      );
      m.ellipsoid(
        torso(side * .043, 1.641, -.106),
        const CafePoint(.0065, .007, .003),
        hair,
        'iris',
        slices: 8,
        rings: 4,
      );
      m.tube(
        [
          torso(side * .023, 1.668, -.098),
          torso(side * .043, 1.673, -.099),
          torso(side * .065, 1.667, -.090),
        ],
        [.003, .004, .002],
        hair,
        'brow',
        sides: 5,
      );
    }
    m.ellipsoid(
      torso(0, 1.619, -.111),
      const CafePoint(.014, .027, .017),
      skin,
      'nose',
      slices: 8,
      rings: 6,
    );
    m.tube(
      [
        torso(-.022, 1.571, -.095),
        torso(0, 1.568, -.102),
        torso(.022, 1.571, -.095),
      ],
      [.0018, .0023, .0018],
      const Color(0xff9c6f59),
      'mouth',
      sides: 5,
    );
    // A continuous cap has a lower nape and higher hairline, then swept locks.
    m.hairCap(torso(0, 1.64, .002), hair);
    for (var i = 0; i < 7; i++) {
      final x = -.085 + i * .023;
      m.tube(
        [
          torso(x, 1.735 - x.abs() * .15, .035),
          torso(x + .008, 1.781 - x.abs() * .13, -.018),
          torso(x + .022, 1.744 - x.abs() * .16, -.080),
          torso(x + .027, 1.691 + i * .003, -.109),
        ],
        [.010, .017, .014, .002],
        i.isEven ? const Color(0xff70513b) : hair,
        'hair.lock',
        sides: 7,
      );
    }
    for (final side in [-1.0, 1.0]) {
      for (var i = 0; i < 3; i++) {
        m.tube(
          [
            torso(side * .084, 1.722, .022 + i * .023),
            torso(side * .116, 1.672, .008 + i * .021),
            torso(side * .108, 1.614, .023 + i * .019),
          ],
          [.016, .017, .002],
          i.isEven ? hair : const Color(0xff654936),
          'hair.lock',
          sides: 6,
        );
      }
    }
    m.loft(
      [(torso(0, 1.435, 0), .081, .071), (torso(0, 1.468, 0), .065, .058)],
      const Color(0xffe1d3ba),
      'linen.collar.band',
      sides: 16,
    );
    // Separate collar leaves, placket, pocket opening and the tucked pen.
    for (final s in [-1.0, 1.0]) {
      m.patch(
        [
          torso(s * .064, 1.46, -.065),
          torso(s * .106, 1.413, -.113),
          torso(s * .066, 1.349, -.144),
          torso(s * .012, 1.403, -.121),
        ],
        const Color(0xffeee4d1),
        'linen.collar',
      );
    }
    m.tube(
      [
        torso(0, 1.397, -.136),
        torso(0, 1.24, -.136),
        torso(0, 1.08, -.136),
        torso(0, .877, -.136),
      ],
      [.006, .006, .006, .006],
      seam,
      'linen.placket',
      sides: 5,
    );
    for (var i = 0; i < 5; i++) {
      m.ellipsoid(
        torso(0, 1.34 - i * .096, -.144),
        const CafePoint(.005, .005, .002),
        const Color(0xff9c8161),
        'button',
        slices: 6,
        rings: 4,
      );
    }
    m.patch(
      [
        torso(-.146, 1.265, -.104),
        torso(-.065, 1.272, -.128),
        torso(-.067, 1.174, -.126),
        torso(-.106, 1.16, -.118),
        torso(-.145, 1.175, -.105),
      ],
      const Color(0xffe0d4bd),
      'linen.pocket',
    );
    m.tube(
      [torso(-.147, 1.267, -.107), torso(-.066, 1.274, -.131)],
      [.002, .002],
      seam,
      'pocket.seam',
      sides: 5,
    );
    m.tube(
      [torso(-.091, 1.25, -.131), torso(-.094, 1.312, -.129)],
      [.004, .004],
      const Color(0xff69503a),
      'pocket.pen',
      sides: 6,
    );
    m.tube(
      [torso(-.101, 1.308, -.132), torso(-.101, 1.281, -.135)],
      [.0017, .0017],
      const Color(0xffb89a5f),
      'pen.clip',
      sides: 5,
    );
    m.tube(
      [
        torso(-.175, 1.365, .074),
        torso(0, 1.357, .126),
        torso(.175, 1.365, .074),
      ],
      [.002, .002, .002],
      seam,
      'linen.yoke',
      sides: 5,
    );
    m.tube(
      [torso(0, 1.35, .121), torso(.007, 1.21, .120), torso(.004, 1.08, .115)],
      [.003, .002, .001],
      const Color(0xffd4c7b0),
      'linen.pleat',
      sides: 5,
    );
    m.ellipsoid(
      CafePoint(0, .875 - seated * .37, .014),
      const CafePoint(.177, .10, .111),
      pants,
      'trousers',
      slices: 12,
      rings: 5,
    );
    for (final s in [-1.0, 1.0]) {
      final swing = math.sin(phase + (s < 0 ? math.pi : 0)) * stride;
      final hip = CafePoint(s * .092, .87 - seated * .37, .006);
      final cycle = ((phase / (2 * math.pi) + (s < 0 ? .5 : 0)) % 1);
      final swingTime = ((cycle - .6) / .4).clamp(0.0, 1.0);
      final eased = swingTime * swingTime * (3 - 2 * swingTime);
      final footZ = cycle < .6
          ? -.234 + .468 * cycle / .6
          : .234 - .468 * eased;
      final ankle = CafePoint(
        s * .103,
        .095 + math.sin(swingTime * math.pi) * .075 * stride * (1 - seated),
        footZ * stride * (1 - seated) - seated * .36,
      );
      final knee = _joint(hip, ankle, .405, .415, const CafePoint(0, 0, -1));
      m.tube(
        [
          hip,
          CafePoint.lerp(hip, knee, .44),
          knee,
          CafePoint.lerp(knee, ankle, .53),
          ankle + const CafePoint(0, .082, 0),
        ],
        [.093, .087, .068, .062, .060],
        pants,
        'trousers',
        sides: 12,
        flatten: .90,
      );
      m.tube(
        [
          ankle + const CafePoint(0, .082, 0),
          ankle + const CafePoint(0, .102, 0),
        ],
        [.061, .061],
        const Color(0xff685345),
        'trousers.cuff',
        sides: 12,
        flatten: .90,
      );
      m.tube(
        [
          ankle + const CafePoint(0, .015, 0),
          ankle + const CafePoint(0, .083, 0),
        ],
        [.040, .041],
        skin,
        'ankle',
        sides: 10,
      );
      if (ankle.y < .11) {
        for (var j = 0; j < 20; j++) {
          CafePoint edge(int k) => CafePoint(
            ankle.x + .10 * math.cos(k * math.pi / 10),
            .018,
            ankle.z - .035 + .17 * math.sin(k * math.pi / 10),
          );
          m.patch(
            [CafePoint(ankle.x, .018, ankle.z - .035), edge(j), edge(j + 1)],
            const Color(0x16000000),
            'contact.shadow',
            normals: List.filled(3, const CafePoint(0, 1, 0)),
          );
        }
      }
      // Rounded last, separate welt, light rubber sole and vamp seam.
      m.ellipsoid(
        CafePoint(ankle.x, .043 + ankle.y - .095, ankle.z - .036),
        const CafePoint(.071, .031, .143),
        const Color(0xffd6c9ae),
        'shoe.sole',
        slices: 12,
        rings: 5,
      );
      m.ellipsoid(
        CafePoint(ankle.x, .078 + ankle.y - .095, ankle.z - .039),
        const CafePoint(.067, .048, .131),
        shoe,
        'shoe',
        slices: 12,
        rings: 6,
      );
      m.tube(
        [
          CafePoint(ankle.x - .049, ankle.y + .002, ankle.z - .069),
          CafePoint(ankle.x, ankle.y + .023, ankle.z - .093),
          CafePoint(ankle.x + .049, ankle.y + .002, ankle.z - .069),
        ],
        [.0015, .0015, .0015],
        const Color(0xffd4b28b),
        'shoe.stitch',
        sides: 5,
      );
      final shoulder = torso(s * .166, 1.334, 0);
      var wrist = torso(s * .253, .92, -.015 + swing * .10);
      final frame = use, obj = object;
      if (frame != null && obj != null) {
        final p = frame.progress.clamp(0.0, 1.0);
        final lift = frame.kind == CafeUseKind.pickUp
            ? p
            : frame.kind == CafeUseKind.putDown
            ? 1 - p
            : frame.held
            ? 1.0
            : 0.0;
        final volume = obj.type == CafeItemType.volume;
        final opening = frame.kind == CafeUseKind.open
            ? p
            : frame.kind == CafeUseKind.close
            ? 1 - p
            : frame.open
            ? 1.0
            : 0.0;
        final bookGrip = .085 + opening * .14;
        if (s > 0 || volume) {
          final grip = cafeHeldPoint(eye, obj.type, frame, thirdPerson: true);
          final target = lift > 0
              ? CafePoint.lerp(
                  obj.pivot + const CafePoint(0, .07, 0),
                  grip +
                      eye.right * (volume ? s * bookGrip : .055) +
                      CafePoint(0, volume ? -.06 : .065, 0) -
                      (volume ? eye.forward * .04 : const CafePoint(0, 0, 0)),
                  lift,
                )
              : obj.pivot + const CafePoint(0, .07, 0);
          final reach = lift > 0 ? 1.0 : math.sin(p * math.pi);
          wrist = CafePoint.lerp(wrist, _local(target), reach);
        }
        if (s < 0 &&
            (frame.kind == CafeUseKind.refill ||
                frame.kind == CafeUseKind.water)) {
          final target = frame.kind == CafeUseKind.refill
              ? cafeHeldPoint(eye, obj.type, frame, thirdPerson: true) +
                    const CafePoint(0, .10, 0)
              : obj.pivot + const CafePoint(0, .32, 0);
          final handle =
              cafePourPoint(eye, target, p) -
              eye.right * .08 +
              const CafePoint(0, .10, 0);
          wrist = CafePoint.lerp(wrist, _local(handle), math.sin(p * math.pi));
        }
      } else if (seated > .1) {
        wrist = CafePoint.lerp(wrist, CafePoint(s * .17, .73, -.30), seated);
      }
      if ((wrist - shoulder).length > .515) {
        wrist = shoulder + (wrist - shoulder).normalized * .515;
      }
      final elbow = _joint(
        shoulder,
        wrist,
        .265,
        .255,
        CafePoint(s * .15, -.05, 1),
      );
      // Upper sleeve, visible folded cuff, lower forearm and shaped palm.
      final cuff = CafePoint.lerp(elbow, wrist, .24);
      m.tube(
        [shoulder, CafePoint.lerp(shoulder, elbow, .4), elbow, cuff],
        [.077, .074, .064, .058],
        shirt,
        'linen.sleeve',
        sides: 12,
      );
      m.tube(
        [CafePoint.lerp(elbow, cuff, .68), cuff],
        [.064, .064],
        const Color(0xffded0b8),
        'linen.cuff',
        sides: 12,
      );
      m.tube(
        [cuff, CafePoint.lerp(cuff, wrist, .65), wrist],
        [.049, .034, .028],
        skin,
        'forearm',
        sides: 10,
      );
      final direction = (wrist - elbow).normalized;
      final palm = wrist + direction * .035;
      m.ellipsoid(
        palm,
        const CafePoint(.034, .047, .022),
        skin,
        'hand',
        slices: 8,
        rings: 6,
      );
      for (var f = 0; f < 4; f++) {
        final start = palm + CafePoint((f - 1.5) * .015, -.025, -.004);
        final length = f == 0 || f == 3 ? .034 : .041;
        m.tube(
          [
            start,
            start + direction * (length * .6),
            start + direction * length + const CafePoint(0, 0, -.009),
          ],
          [.008, .007, .0045],
          skin,
          'finger',
          sides: 6,
        );
      }
      m.tube(
        [
          palm + CafePoint(-s * .026, .014, -.004),
          palm + CafePoint(-s * .047, -.006, -.013),
          palm + CafePoint(-s * .040, -.023, -.023),
        ],
        [.011, .009, .006],
        skin,
        'thumb',
        sides: 6,
      );
    }
    return m.faces;
  }
}

/// Two-bone IK; unreachable targets are clamped instead of stretching limbs.
CafePoint _joint(
  CafePoint a,
  CafePoint b,
  double upper,
  double lower,
  CafePoint bend,
) {
  final axis = (b - a).normalized;
  final d = (b - a).length.clamp(.025, upper + lower - .001);
  final along = (upper * upper - lower * lower + d * d) / (2 * d);
  final perpendicular = (bend - axis * bend.dot(axis)).normalized;
  return a +
      axis * along +
      perpendicular * math.sqrt(math.max(0, upper * upper - along * along));
}

class _AvatarMesh {
  _AvatarMesh(this.at, this.normal);
  final CafePoint Function(CafePoint) at, normal;
  final faces = <CafeFace>[];
  void patch(
    List<CafePoint> points,
    Color color,
    String part, {
    List<CafePoint>? normals,
  }) {
    final outward =
        normals ?? List.filled(points.length, const CafePoint(0, 0, -1));
    if ((points[1] - points[0]).cross(points[2] - points[0]).dot(outward[0]) <
        0) {
      points = points.reversed.toList();
      normals = outward.reversed.toList();
    } else {
      normals = outward;
    }
    if ((points[1] - points[0]).cross(points[2] - points[0]).length < 1e-10) {
      return;
    }
    faces.add(
      CafeFace(
        points.map(at).toList(),
        color,
        objectId: CafeAvatar.id,
        part: part,
        vertexNormals: normals.map((n) => normal(n).normalized).toList(),
        textureCoordinates: points
            .map((p) => Offset(p.x * 5 + p.z * 2, p.y * 5))
            .toList(),
      ),
    );
  }

  void ellipsoid(
    CafePoint center,
    CafePoint radii,
    Color color,
    String part, {
    int slices = 10,
    int rings = 6,
  }) {
    CafePoint n(int i, int j) {
      final v = math.pi * (i + .001) / (rings + .002),
          u = 2 * math.pi * j / slices;
      return CafePoint(
        math.sin(v) * math.cos(u),
        math.cos(v),
        math.sin(v) * math.sin(u),
      );
    }

    CafePoint p(CafePoint q) =>
        center + CafePoint(q.x * radii.x, q.y * radii.y, q.z * radii.z);
    for (var i = 0; i < rings; i++) {
      for (var j = 0; j < slices; j++) {
        final ns = [n(i, j), n(i + 1, j), n(i + 1, j + 1), n(i, j + 1)];
        patch(
          ns.map(p).toList(),
          color,
          part,
          normals: ns
              .map(
                (q) => CafePoint(
                  q.x / radii.x,
                  q.y / radii.y,
                  q.z / radii.z,
                ).normalized,
              )
              .toList(),
        );
      }
    }
  }

  void loft(
    List<(CafePoint, double, double)> rings,
    Color color,
    String part, {
    int sides = 12,
  }) {
    for (var i = 0; i < rings.length - 1; i++) {
      CafePoint p(int k, int j) {
        final (c, rx, rz) = rings[k];
        final t = j * 2 * math.pi / sides;
        return c + CafePoint(rx * math.cos(t), 0, rz * math.sin(t));
      }

      CafePoint n(int k, int j) {
        final t = j * 2 * math.pi / sides;
        final previous = math.max(0, k - 1),
            next = math.min(rings.length - 1, k + 1);
        final tangent = CafePoint(
          -rings[k].$2 * math.sin(t),
          0,
          rings[k].$3 * math.cos(t),
        );
        final axial = p(next, j) - p(previous, j);
        return axial.cross(tangent).normalized;
      }

      for (var j = 0; j < sides; j++) {
        patch(
          [p(i, j), p(i + 1, j), p(i + 1, j + 1), p(i, j + 1)],
          color,
          part,
          normals: [n(i, j), n(i + 1, j), n(i + 1, j + 1), n(i, j + 1)],
        );
      }
    }
  }

  void tube(
    List<CafePoint> centers,
    List<double> radii,
    Color color,
    String part, {
    int sides = 8,
    double flatten = 1,
  }) {
    final axes = <(CafePoint, CafePoint)>[];
    for (var i = 0; i < centers.length; i++) {
      final direction =
          (centers[math.min(i + 1, centers.length - 1)] -
                  centers[math.max(0, i - 1)])
              .normalized;
      // Parallel transport keeps adjacent rings aligned through an elbow.
      // Switching reference axes per ring twists the sleeve into spikes.
      final reference = axes.isEmpty
          ? (direction.y.abs() > .85
                ? const CafePoint(1, 0, 0)
                : const CafePoint(0, 1, 0))
          : axes.last.$1;
      final u = axes.isEmpty
          ? direction.cross(reference).normalized
          : (reference - direction * reference.dot(direction)).normalized;
      axes.add((u, direction.cross(u).normalized));
    }
    CafePoint n(int i, int j) {
      final t = j * 2 * math.pi / sides;
      return axes[i].$1 * math.cos(t) + axes[i].$2 * (math.sin(t) * flatten);
    }

    for (var i = 0; i < centers.length - 1; i++) {
      for (var j = 0; j < sides; j++) {
        final ns = [n(i, j), n(i + 1, j), n(i + 1, j + 1), n(i, j + 1)];
        patch(
          [
            centers[i] + ns[0] * radii[i],
            centers[i + 1] + ns[1] * radii[i + 1],
            centers[i + 1] + ns[2] * radii[i + 1],
            centers[i] + ns[3] * radii[i],
          ],
          color,
          part,
          normals: ns,
        );
      }
    }
    for (final end in [0, centers.length - 1]) {
      final ns = end == 0
          ? (centers[0] - centers[1]).normalized
          : (centers.last - centers[centers.length - 2]).normalized;
      for (var j = 0; j < sides; j++) {
        patch(
          [
            centers[end],
            centers[end] + n(end, j) * radii[end],
            centers[end] + n(end, j + 1) * radii[end],
          ],
          color,
          part,
          normals: List.filled(3, ns),
        );
      }
    }
  }

  void hairCap(CafePoint center, Color color) {
    const slices = 20, rings = 6;
    CafePoint p(int i, int j) {
      final u = j * math.pi * 2 / slices;
      final back = (math.sin(u) + 1) / 2;
      final v = (.001 + i / rings * (1.20 + back * .95));
      return center +
          CafePoint(
            .116 * math.sin(v) * math.cos(u),
            .137 * math.cos(v),
            .110 * math.sin(v) * math.sin(u),
          );
    }

    for (var i = 0; i < rings; i++) {
      for (var j = 0; j < slices; j++) {
        final ps = [p(i, j), p(i + 1, j), p(i + 1, j + 1), p(i, j + 1)];
        patch(
          ps,
          color,
          'hair',
          normals: ps.map((q) => (q - center).normalized).toList(),
        );
      }
    }
  }
}
