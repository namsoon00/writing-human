part of 'cafe_avatar.dart';

const _skin = Color(0xffedba8e), _hair = Color(0xff62432e);
const _knit = Color(0xffd8c4a3), _cream = Color(0xffeee3cc);
const _pants = Color(0xff79604c), _slipper = Color(0xffb6a28a);
const _zero = CafePoint(0, 0, 0);
CafePoint _p(double x, double y, double z) => CafePoint(x, y, -z);
final _cozyHead = _makeCozyHead();
final _cozyCoat = _makeCozyCoat();

extension _CozyAvatar on CafeAvatar {
  List<CafeFace> _cozyBuild() {
    final rig = skeleton;
    final drop = rig.drop;
    final bob = rig.bob;
    final mesh = _AvatarMesh((p) => origin + _rotate(p), _rotate);
    final coat = _AvatarMesh(
      (p) => origin + _rotate(rig.torsoPoint(p)),
      (n) => _rotate(rig.torsoNormal(n)),
    );
    final head = _AvatarMesh(
      (p) =>
          origin +
          _rotate(
            rig.torsoPoint(
              CafePoint(p.x * 1.0925, 1.067 + p.y * .9975, p.z * 1.045),
            ),
          ),
      (n) => _rotate(
        rig.torsoNormal(CafePoint(n.x / 1.0925, n.y / .9975, n.z / 1.045)),
      ),
    );
    _copyTemplate(coat, _cozyCoat);
    _copyTemplate(head, _cozyHead);
    mesh.ellipsoid(
      CafePoint(rig.sway, .454 + bob - drop, rig.lean),
      const CafePoint(.132, .063, .103),
      _pants,
      'trousers',
      slices: 14,
      rings: 5,
    );
    for (final s in [-1.0, 1.0]) {
      final leg = rig.legs[s < 0 ? 0 : 1];
      final gait = math.sin(phase + (s < 0 ? math.pi : 0)) * rig.moving;
      final hip = leg.hip, knee = leg.knee, ankle = leg.ankle;
      // Separate segments overlap in a rounded knee instead of twisting a
      // single wide tube through a sharp bend into the other leg.
      mesh.tube(
        [hip, CafePoint.lerp(hip, knee, .48), knee],
        [.061, .060, .047],
        _pants,
        'trousers',
        sides: 12,
        caps: false,
      );
      mesh.ellipsoid(
        knee,
        const CafePoint(.048, .047, .048),
        _pants,
        'knee',
        slices: 10,
        rings: 5,
      );
      mesh.tube(
        [knee, CafePoint.lerp(knee, ankle, .53), ankle],
        [.046, .044, .036],
        _pants,
        'trousers',
        sides: 12,
        caps: false,
      );
      final cuff = (knee - ankle).normalized;
      mesh.tube(
        [ankle + cuff * .012, ankle + cuff * .045],
        [.037, .038],
        const Color(0xff705742),
        'trousers.cuff',
        sides: 10,
      );
      final naked = barefoot || meditating;
      final cr = math.cos(leg.roll), sr = math.sin(leg.roll);
      final cp = math.cos(leg.pitch), sp = math.sin(leg.pitch);
      final cy = math.cos(leg.yaw), sy = math.sin(leg.yaw);
      CafePoint turn(CafePoint q) {
        final x = q.x * cr - q.y * sr, y = q.x * sr + q.y * cr;
        final yy = y * cp - q.z * sp, z = y * sp + q.z * cp;
        return CafePoint(x * cy - z * sy, yy, x * sy + z * cy);
      }

      final foot = _AvatarMesh(
        (q) => origin + _rotate(ankle + turn(q)),
        (q) => _rotate(turn(q)),
      );
      foot.tube(
        [const CafePoint(0, -.035, 0), const CafePoint(0, .035, 0)],
        [.034, .037],
        naked ? _skin : _cream,
        naked ? 'ankle' : 'sock',
        sides: 10,
      );
      if (naked) {
        foot.ellipsoid(
          const CafePoint(0, -.067, -.035),
          const CafePoint(.044, .026, .095),
          _skin,
          'foot',
          slices: 12,
          rings: 5,
        );
        for (var i = 0; i < 5; i++) {
          foot.ellipsoid(
            CafePoint((i - 2) * .016, -.065, -.112 + i * .004),
            CafePoint(.012 - i * .0007, .015, .022 - i * .0015),
            _skin,
            'foot.toe',
            slices: 6,
            rings: 4,
          );
        }
      } else {
        foot.ellipsoid(
          const CafePoint(0, -.091, -.025),
          const CafePoint(.068, .017, .106),
          const Color(0xffa49179),
          'shoe.sole',
          slices: 14,
          rings: 5,
        );
        foot.ellipsoid(
          const CafePoint(0, -.066, -.027),
          const CafePoint(.067, .041, .100),
          _slipper,
          'shoe',
          slices: 14,
          rings: 6,
        );
        foot.tube(
          [
            const CafePoint(-.056, -.077, -.075),
            const CafePoint(0, -.077, -.125),
            const CafePoint(.056, -.077, -.075),
          ],
          [.0016, .0016, .0016],
          _cream,
          'shoe.stitch',
          sides: 5,
        );
      }
      mesh.faces.addAll(foot.faces);
      if (ankle.y < .16) _footShadow(mesh, ankle);
      _cozyArm(mesh, s, gait, bob, drop);
    }
    return [...coat.faces, ...head.faces, ...mesh.faces];
  }

  void _cozyArm(
    _AvatarMesh mesh,
    double s,
    double gait,
    double bob,
    double drop,
  ) {
    final shoulder =
        skeleton.torsoPoint(CafePoint(s * .163, .815, 0)) -
        CafePoint(0, .02 * skeleton.fold, 0);
    var wrist = skeleton.torsoPoint(
      CafePoint(s * .195, .490, -.012 - gait * .028),
    );
    final frame = use, obj = object;
    var reach = 0.0, grip = false;
    var gripAmount = 0.0;
    CafePoint? cupDirection, cupNormal;
    if (frame != null && obj != null) {
      final progress = frame.progress.clamp(0.0, 1.0);
      final lift = cafePropLift(frame);
      final volume = obj.type == CafeItemType.volume;
      final cup = obj.type == CafeItemType.cup;
      final opening = frame.kind == CafeUseKind.open
          ? progress
          : frame.kind == CafeUseKind.close
          ? 1 - progress
          : frame.open
          ? 1.0
          : 0.0;
      if (s > 0 || volume || cup) {
        final held = cafeHeldPoint(eye, obj.type, frame, thirdPerson: true);
        CafePoint target;
        if (cup) {
          final offset = cafeHeldVector(
            eye,
            obj.type,
            frame,
            CafePoint(s * .071, .041, .031),
            thirdPerson: true,
          );
          target = held + offset;
          CafePoint axis(CafePoint p) => _local(
            origin + cafeHeldVector(eye, obj.type, frame, p, thirdPerson: true),
          ).normalized;
          cupDirection = axis(const CafePoint(0, 0, -1));
          cupNormal = axis(CafePoint(-s, 0, 0));
        } else {
          target =
              held +
              eye.right * (volume ? s * (.085 + opening * .14) : .055) +
              CafePoint(0, volume ? -.06 : .055, 0) -
              (volume ? eye.forward * .04 : _zero);
        }
        var onTable =
            obj.pivot +
            (cup ? eye.right * (s * .071) : _zero) +
            CafePoint(0, obj.type == CafeItemType.chair ? .72 : .045, 0);
        if (frame.kind == CafeUseKind.pull || frame.kind == CafeUseKind.push) {
          onTable +=
              CafePoint(-math.sin(obj.yaw), 0, math.cos(obj.yaw)) *
              (.06 *
                  cafeContactProgress(frame) *
                  (frame.kind == CafeUseKind.push ? -1 : 1));
        }
        reach = cafeHandReach(frame);
        wrist = CafePoint.lerp(
          wrist,
          _local(CafePoint.lerp(onTable, target, lift)),
          reach,
        );
        gripAmount = cafeGrip(frame);
        grip =
            gripAmount > .01 &&
            (frame.held ||
                frame.kind == CafeUseKind.pickUp ||
                frame.kind == CafeUseKind.putDown);
      }
      if (s < 0 &&
          (frame.kind == CafeUseKind.refill ||
              frame.kind == CafeUseKind.water)) {
        final target = frame.kind == CafeUseKind.refill
            ? cafeHeldPoint(eye, obj.type, frame, thirdPerson: true) +
                  const CafePoint(0, .10, 0)
            : obj.pivot + const CafePoint(0, .32, 0);
        final handle =
            cafePourPoint(eye, target, progress) -
            eye.right * .08 +
            const CafePoint(0, .10, 0);
        wrist = CafePoint.lerp(
          wrist,
          _local(handle),
          math.sin(progress * math.pi),
        );
      }
    } else if (meditating) {
      final knee = skeleton.legs[s < 0 ? 0 : 1].knee;
      wrist = CafePoint.lerp(
        wrist,
        knee + CafePoint(-s * .025, .08, .01),
        skeleton.fold,
      );
    } else if (seated > 0) {
      wrist = CafePoint.lerp(wrist, CafePoint(s * .145, .785, -.23), seated);
    }
    if ((wrist - shoulder).length > .35) {
      wrist = shoulder + (wrist - shoulder).normalized * .35;
    }
    final elbow = _joint(
      shoulder,
      wrist,
      .19,
      .165,
      CafePoint(s * .12, -.35, .045),
    );
    mesh.ellipsoid(
      shoulder + CafePoint(-s * .006, 0, 0),
      const CafePoint(.059, .059, .059),
      _knit,
      'knit.shoulder',
      slices: 10,
      rings: 5,
    );
    mesh.tube(
      [
        shoulder,
        CafePoint.lerp(shoulder, elbow, .55),
        elbow,
        CafePoint.lerp(elbow, wrist, .60),
        wrist,
      ],
      [.056, .061, .054, .048, .042],
      _knit,
      'knit.sleeve',
      sides: 12,
    );
    final towardElbow = (elbow - wrist).normalized;
    mesh.tube(
      [wrist, wrist + towardElbow * .035],
      [.044, .045],
      const Color(0xffcdb894),
      'knit.cuff',
      sides: 12,
    );
    var direction = (wrist - elbow).normalized;
    var normal =
        (CafePoint(-s, 0, -.10) -
                direction * CafePoint(-s, 0, -.10).dot(direction))
            .normalized;
    var across = direction.cross(normal).normalized;
    if (grip && cupDirection != null) {
      direction = CafePoint.lerp(
        direction,
        cupDirection,
        gripAmount,
      ).normalized;
      normal = CafePoint.lerp(normal, cupNormal!, gripAmount).normalized;
      across = direction.cross(normal).normalized;
      normal = across.cross(direction).normalized;
    } else if (grip && obj != null && frame != null) {
      final toward =
          _local(cafeHeldPoint(eye, obj.type, frame, thirdPerson: true)) -
          wrist;
      final projected = toward - direction * toward.dot(direction);
      if (projected.length > .005) {
        normal = CafePoint.lerp(
          normal,
          projected.normalized,
          gripAmount,
        ).normalized;
        across = direction.cross(normal).normalized;
      }
    }
    if (!grip && (skeleton.fold > .01 || (frame == null && seated > .01))) {
      final folding = skeleton.fold > .01;
      final weight = folding ? skeleton.fold : CafeBody.ease(seated);
      direction = CafePoint.lerp(
        direction,
        (folding ? CafePoint(s * .23, -.35, -.90) : const CafePoint(0, 0, -1))
            .normalized,
        weight,
      ).normalized;
      final down =
          (const CafePoint(0, -1, 0) -
                  direction * const CafePoint(0, -1, 0).dot(direction))
              .normalized;
      normal = CafePoint.lerp(normal, down, weight).normalized;
      across = direction.cross(normal).normalized;
      normal = across.cross(direction).normalized;
    }
    _cozyHand(mesh, wrist, across, direction, normal, s, gripAmount);
  }
}

void _cozyHand(
  _AvatarMesh mesh,
  CafePoint wrist,
  CafePoint across,
  CafePoint direction,
  CafePoint normal,
  double s,
  double grip,
) {
  CafePoint p(double x, double y, double z) =>
      wrist + across * x + direction * y + normal * z;
  mesh.ellipsoid(
    p(0, .025, 0),
    const CafePoint(.029, .032, .019),
    _skin,
    'hand',
    slices: 10,
    rings: 6,
    axes: [across, direction, normal],
  );
  mesh.ellipsoid(
    p(s * .016, .018, .005),
    const CafePoint(.015, .022, .014),
    _skin,
    'hand.web',
    slices: 8,
    rings: 4,
    axes: [across, direction, normal],
  );
  for (var i = 0; i < 4; i++) {
    final length = [.031, .041, .044, .039][i];
    var tip = p(s * (i - 1.5) * .013, .047 - (i == 0 ? .005 : 0), .001);
    final points = <CafePoint>[tip];
    final relaxed = [.12 + i * .025, .34 + i * .025, .23];
    final curls = [
      for (var j = 0; j < 3; j++)
        relaxed[j] + ([.40, .66, .43][j] - relaxed[j]) * grip,
    ];
    var angle = 0.0;
    for (var j = 0; j < 3; j++) {
      angle += curls[j];
      tip +=
          (direction * math.cos(angle) + normal * math.sin(angle)) *
          (length * [.45, .32, .23][j]);
      points.add(tip);
    }
    mesh.tube(points, [.0072, .0068, .0058, .0028], _skin, 'finger', sides: 6);
  }
  final thumb = p(s * .025, .018, .005);
  final axis =
      (across * (s * (.42 + .18 * grip)) +
              direction * (.86 - .10 * grip) +
              normal * (.19 + .06 * grip))
          .normalized;
  mesh.tube(
    [
      thumb,
      thumb + axis * .020,
      thumb + axis * .034 + normal * (.007 - .003 * grip),
    ],
    [.010, .008, .0038],
    _skin,
    'thumb',
    sides: 7,
  );
}

void _footShadow(_AvatarMesh mesh, CafePoint ankle) {
  for (var j = 0; j < 16; j++) {
    CafePoint edge(int k) => CafePoint(
      ankle.x + .082 * math.cos(k * math.pi / 8),
      .003,
      ankle.z - .025 + .13 * math.sin(k * math.pi / 8),
    );
    mesh.patch(
      [CafePoint(ankle.x, .003, ankle.z - .025), edge(j), edge(j + 1)],
      const Color(0x16000000),
      'contact.shadow',
      normals: List.filled(3, const CafePoint(0, 1, 0)),
    );
  }
}

void _copyTemplate(_AvatarMesh into, List<CafeFace> source) {
  for (final f in source) {
    into.patch(f.points, f.color, f.part!, normals: f.vertexNormals);
  }
}

List<CafeFace> _makeCozyCoat() {
  final m = _AvatarMesh((p) => p, (n) => n);
  const rows = 8, columns = 20;
  CafePoint at(int j, int i) {
    final t = j / rows, y = .45 + t * .43;
    final rx = .163 + .025 * math.sin(t * math.pi) - .014 * math.pow(t, 5),
        rz = .112 + .017 * math.sin(t * math.pi),
        gap = .045 + math.max(0, t - .52) * 1.85;
    final a = gap + (2 * math.pi - gap * 2) * i / columns;
    return _p(math.sin(a) * rx, y, math.cos(a) * rz);
  }

  for (var j = 0; j < rows; j++) {
    for (var i = 0; i < columns; i++) {
      final ps = [at(j, i), at(j + 1, i), at(j + 1, i + 1), at(j, i + 1)];
      m.patch(
        ps,
        _knit,
        'knit.body',
        normals: ps.map((p) => CafePoint(p.x, 0, p.z).normalized).toList(),
      );
    }
  }
  m.ellipsoid(
    _p(0, .79, .005),
    const CafePoint(.113, .104, .101),
    _cream,
    'shirt',
    slices: 14,
    rings: 6,
  );
  m.ellipsoid(
    _p(0, .455, -.006),
    const CafePoint(.168, .025, .116),
    _knit,
    'knit.hem',
    slices: 20,
    rings: 4,
  );
  m.ellipsoid(
    _p(0, .888, 0),
    const CafePoint(.062, .068, .061),
    _skin,
    'neck',
    slices: 12,
    rings: 5,
  );
  for (final s in [-1.0, 1.0]) {
    m.tube(
      [
        _p(s * .107, .875, .068),
        _p(s * .09, .827, .105),
        _p(s * .047, .737, .126),
        _p(s * .012, .686, .132),
        _p(s * .012, .473, .119),
      ],
      [.016, .016, .015, .014, .014],
      _knit,
      'knit.collar',
      sides: 7,
    );
    m.ellipsoid(
      _p(s * .089, .535, .113),
      const CafePoint(.048, .054, .014),
      const Color(0xffd3bd9b),
      'knit.pocket',
      slices: 12,
      rings: 5,
    );
    m.tube(
      [
        _p(s * .133, .577, .114),
        _p(s * .09, .582, .135),
        _p(s * .046, .577, .124),
      ],
      [.004, .004, .004],
      _cream,
      'knit.pocket.edge',
      sides: 5,
    );
    for (var i = 0; i < 6; i++) {
      final x = s * (.025 + i * .017);
      m.tube(
        [_p(x, .438, .106), _p(x, .470, .112)],
        [.0015, .0015],
        const Color(0xffe1d0b2),
        'knit.rib',
        sides: 4,
      );
    }
  }
  for (final y in [.665, .578, .491]) {
    m.ellipsoid(
      _p(.018, y, .146),
      const CafePoint(.013, .013, .0055),
      const Color(0xff755038),
      'knit.button',
      slices: 10,
      rings: 4,
    );
    for (final x in [-.004, .004]) {
      m.ellipsoid(
        _p(.018 + x, y, .1515),
        const CafePoint(.0016, .002, .001),
        const Color(0xff493222),
        'button.hole',
        slices: 5,
        rings: 3,
      );
    }
  }
  return m.faces;
}

List<CafeFace> _makeCozyHead() {
  final m = _AvatarMesh((p) => p, (n) => n);
  m.ellipsoid(
    _zero,
    const CafePoint(.205, .213, .183),
    _skin,
    'face',
    slices: 24,
    rings: 14,
  );
  for (final s in [-1.0, 1.0]) {
    m.ellipsoid(
      _p(s * .20, -.015, 0),
      const CafePoint(.043, .056, .030),
      _skin,
      'ear',
      slices: 10,
      rings: 6,
    );
    m.ellipsoid(
      _p(s * .219, -.014, .018),
      const CafePoint(.018, .031, .012),
      const Color(0xffe4a67d),
      'ear.fold',
      slices: 8,
      rings: 5,
    );
    m.ellipsoid(
      _p(s * .066, .021, .174),
      const CafePoint(.0115, .016, .007),
      const Color(0xff33261f),
      'iris',
      slices: 10,
      rings: 6,
    );
    m.ellipsoid(
      _p(s * .066 - .003, .026, .180),
      const CafePoint(.0025, .003, .0015),
      _cream,
      'eye.glint',
      slices: 6,
      rings: 4,
    );
    m.tube(
      [
        _p(s * .041, .073, .162),
        _p(s * .065, .086, .160),
        _p(s * .091, .075, .149),
      ],
      [.003, .005, .002],
      _hair,
      'brow',
      sides: 6,
    );
  }
  m.ellipsoid(
    _p(0, -.008, .185),
    const CafePoint(.021, .018, .023),
    _skin,
    'nose',
    slices: 12,
    rings: 7,
  );
  m.tube(
    [
      _p(-.041, -.060, .177),
      _p(-.024, -.071, .187),
      _p(0, -.074, .190),
      _p(.024, -.069, .187),
      _p(.041, -.058, .177),
    ],
    [.0013, .0023, .0027, .0023, .0013],
    const Color(0xff875134),
    'mouth',
    sides: 6,
  );
  _cozyHair(m);
  return m.faces;
}

void _cozyHair(_AvatarMesh m) {
  const slices = 28, rings = 9;
  CafePoint cap(int j, int i) {
    final p = i / slices * math.pi * 2,
        a = math.atan2(math.sin(p), math.cos(p));
    final limit =
        1.01 +
        .59 * (1 - math.cos(p)) +
        .075 * math.exp(-math.pow((a + .8) / .4, 2)) -
        .05 * math.exp(-math.pow((a - .25) / .18, 2)) +
        .007 * math.sin(p * 7 + 1);
    final t = (j + .001) / (rings + .001) * limit;
    return _p(
      .211 * math.sin(t) * math.sin(p),
      .005 + .225 * math.cos(t),
      .191 * math.sin(t) * math.cos(p),
    );
  }

  CafePoint normal(CafePoint q) => CafePoint(
    q.x / (.211 * .211),
    (q.y - .005) / (.225 * .225),
    q.z / (.191 * .191),
  ).normalized;
  for (var j = 0; j < rings; j++) {
    for (var i = 0; i < slices; i++) {
      final ps = [cap(j, i), cap(j + 1, i), cap(j + 1, i + 1), cap(j, i + 1)];
      m.patch(ps, _hair, 'hair', normals: ps.map(normal).toList());
    }
  }
  CafePoint surface(CafePoint q, double lift) {
    final u = CafePoint(q.x / .211, (q.y - .005) / .225, q.z / .191).normalized;
    final point = CafePoint(u.x * .211, .005 + u.y * .225, u.z * .191);
    return point + normal(point) * lift;
  }

  void sweep(List<CafePoint> curve, double width, double height) {
    CafePoint center(double t) => _catmull(curve, t);
    CafePoint at(double t, double u) {
      final q = center(t), n = normal(surface(q, 0));
      final tangent =
          (center(math.min(1, t + .005)) - center(math.max(0, t - .005)))
              .normalized;
      final side = tangent.cross(n).normalized;
      final w =
          .002 + width * math.pow(math.sin(math.pi * t), .65) * (1 - .25 * t);
      final rise =
          .001 +
          height *
              (.15 + .85 * math.sqrt(math.sin(math.pi * t))) *
              math.pow(math.cos(u * math.pi / 2), 2);
      return surface(q + side * (u * w), rise);
    }

    for (var i = 0; i < 10; i++) {
      for (var j = 0; j < 5; j++) {
        final ps = [
          at(i / 10, j / 2.5 - 1),
          at((i + 1) / 10, j / 2.5 - 1),
          at((i + 1) / 10, (j + 1) / 2.5 - 1),
          at(i / 10, (j + 1) / 2.5 - 1),
        ];
        m.patch(
          ps,
          Color.lerp(_hair, const Color(0xff6c4a32), .24)!,
          'hair.sweep',
          normals: ps.map(normal).toList(),
        );
      }
    }
  }

  final paths = <List<CafePoint>>[
    [
      _p(.052, .214, .055),
      _p(-.005, .232, .09),
      _p(-.10, .150, .17),
      _p(-.175, .056, .124),
    ],
    [
      _p(.055, .222, .002),
      _p(-.04, .229, .037),
      _p(-.17, .13, .09),
      _p(-.205, .006, .017),
    ],
    [
      _p(.046, .216, -.072),
      _p(-.07, .215, -.07),
      _p(-.18, .08, -.10),
      _p(-.18, -.07, -.10),
    ],
    [
      _p(.036, .208, -.110),
      _p(.005, .19, -.135),
      _p(-.08, .04, -.18),
      _p(-.08, -.11, -.16),
    ],
    [
      _p(.077, .211, .054),
      _p(.12, .183, .087),
      _p(.177, .12, .102),
      _p(.201, .020, .057),
    ],
    [
      _p(.081, .217, -.006),
      _p(.17, .16, -.025),
      _p(.21, .05, -.05),
      _p(.195, -.06, -.06),
    ],
    [
      _p(.066, .213, -.072),
      _p(.15, .15, -.105),
      _p(.18, .03, -.12),
      _p(.14, -.105, -.126),
    ],
    [
      _p(.048, .210, .075),
      _p(-.005, .184, .135),
      _p(-.07, .136, .171),
      _p(-.125, .078, .150),
    ],
    [
      _p(.06, .205, .09),
      _p(.015, .186, .138),
      _p(-.025, .152, .174),
      _p(-.068, .111, .171),
    ],
  ];
  for (var i = 0; i < paths.length; i++) {
    sweep(
      paths[i],
      [.043, .041, .040, .035, .035, .035, .034, .033, .028][i],
      [.012, .010, .008, .007, .009, .008, .007, .014, .010][i],
    );
  }
}

CafePoint _catmull(List<CafePoint> points, double t) {
  final u = t * (points.length - 1),
      i = u.floor().clamp(0, points.length - 2),
      f = u - i;
  CafePoint at(int j) => points[j.clamp(0, points.length - 1)];
  final a = at(i - 1), b = at(i), c = at(i + 1), d = at(i + 2);
  return (b * 2 +
          (c - a) * f +
          (a * 2 - b * 5 + c * 4 - d) * (f * f) +
          (b * 3 - a - c * 3 + d) * (f * f * f)) *
      .5;
}
