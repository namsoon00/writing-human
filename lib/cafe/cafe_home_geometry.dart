part of 'cafe_world.dart';

extension CafeHomeGeometry on CafeWorld {
  /// A tent card has its own opaque paper face and retained UVs, not an overlay.
  void _sentenceCard(
    String id,
    double x,
    double y,
    double z,
    Rect support, {
    int row = 0,
  }) {
    _object(
      id,
      row == 1 ? '이번 주의 쪽지' : '오늘의 문장',
      CafeObjectKind.prop,
      CafePoint(x, y, z),
      () {
        const w = .26, h = .17;
        final points = [
          CafePoint(x + .035, y, z + w / 2),
          CafePoint(x + .035, y, z - w / 2),
          CafePoint(x - .025, y + h, z - w / 2),
          CafePoint(x - .025, y + h, z + w / 2),
        ];
        faces.add(
          CafeFace(
            points,
            CafeWorld.cream,
            part: 'ritual.print',
            surface: CafeSurface.artwork,
            textureCoordinates: [
              Offset(0, (row + 1) / 3),
              Offset(1, (row + 1) / 3),
              Offset(1, row / 3),
              Offset(0, row / 3),
            ],
          ),
        );
        final top = points.skip(2).toList();
        faces.add(
          CafeFace(
            [
              top[1],
              top[0],
              CafePoint(x - .085, y, z - w / 2),
              CafePoint(x - .085, y, z + w / 2),
            ],
            const Color(0xffe0d5bd),
            doubleSided: true,
          ),
        );
        _rod(points[0], points[1], .0012, CafeWorld.brass, sides: 6);
      },
      support: support,
      footprint: Rect.fromCenter(
        center: Offset(x - .025, z),
        width: .12,
        height: .26,
      ),
    );
  }

  void _deskLamp(String id, double x, double z, Rect support) {
    _object(
      id,
      '창가 스탠드',
      CafeObjectKind.prop,
      CafePoint(x, .77, z),
      () {
        final gain = space.light(id);
        final color = [
          CafeWorld.brass,
          CafeWorld.dark,
          CafeWorld.sage,
        ][space.finish(id)];
        _turned(x, z, [
          (.77, .055),
          (.778, .068),
          (.79, .06),
          (.797, .045),
        ], color);
        _rod(CafePoint(x, .79, z), CafePoint(x, 1.06, z), .006, color);
        _oval(
          CafePoint(x, 1.06, z),
          const CafePoint(.016, .016, .016),
          CafeWorld.brass,
        );
        _rod(CafePoint(x, 1.06, z), CafePoint(x + .10, 1.20, z), .006, color);
        final head = CafePoint(x + .115, 1.17, z);
        _turned(head.x, head.z, [
          (1.12, .085),
          (1.13, .087),
          (1.17, .058),
          (1.205, .026),
        ], color);
        cylinder(
          head.x,
          1.118,
          head.z,
          .072,
          .004,
          gain == 0 ? CafeWorld.cream : const Color(0xffffdeb1),
          unlit: gain > 0,
          sides: 20,
        );
        pendantLights.add(CafePoint(head.x, 1.105, head.z));
        pendantGains.add(gain * .48);
      },
      type: CafeItemType.lamp,
      support: support,
      footprint: Rect.fromCenter(center: Offset(x, z), width: .14, height: .14),
    );
  }

  /// All rain is in the same garden coordinates used through the windows.
  Iterable<CafeFace> weatherFaces(CafeCamera camera, double time) sync* {
    if (space.home.mood != 2) return;
    final random = math.Random(612);
    CafePoint room(CafePoint p) =>
        courtyard ? p : CafePoint(-p.z, p.y, p.x + 7.4);
    // Fine exterior streaks; walls and plants occlude them normally.
    if (courtyard) {
      for (var i = 0; i < 100; i++) {
        final region = walkBounds.deflate(.12);
        final cx = camera.position.x.clamp(
              region.left + 4.1,
              region.right - 4.1,
            ),
            cz = camera.position.z.clamp(region.top + 2.4, region.bottom - 2.4);
        final x = cx - 4.1 + random.nextDouble() * 8.2,
            z = cz - 2.4 + random.nextDouble() * 4.8;
        final y = (random.nextDouble() * 3.6 - time * 1.25) % 3.6;
        final a = room(CafePoint(x, y, z)),
            b = room(CafePoint(x + .014, y + .10, z));
        final side = camera.right * .0016;
        yield CafeFace(
          [a - side, a + side, b + side, b - side],
          const Color(0x6599b7c3),
          unlit: true,
          doubleSided: true,
        );
      }
    }
    if (courtyard) return;
    // Deterministic beads live on the outside face of existing window panes.
    for (var i = 0; i < 90; i++) {
      final z = -4.35 + random.nextDouble() * 8.8;
      if (z < -2.6) continue; // Keep the broad garden doorway entirely clear.
      final yy = .72 + random.nextDouble() * 2.0;
      final y = yy - ((time * .016 + i * .07) % 1) * .05;
      final p = CafePoint(-4.215, y, z), r = .003 + random.nextDouble() * .003;
      yield CafeFace(
        [
          p + CafePoint(0, -r * 1.9, 0),
          p + CafePoint(0, 0, r),
          p + CafePoint(0, r * 1.5, 0),
          p + CafePoint(0, 0, -r),
        ],
        const Color(0x7395b0b9),
        unlit: true,
        doubleSided: true,
      );
    }
  }
}
