part of 'cafe_world.dart';

enum CafeItemType {
  group,
  table,
  chair,
  cup,
  notebook,
  pencil,
  vase,
  plant,
  volume,
  lamp,
  frame,
  cloth,
  stack,
  fixture,
  decoration;

  String get category => switch (this) {
    group || table || chair => '가구',
    lamp => '조명',
    volume => '책',
    plant => '식물',
    frame => '그림',
    _ => '소품',
  };
}

CafeItemType _itemType(String id, CafeObjectKind kind) {
  if (kind == CafeObjectKind.group) return CafeItemType.group;
  if (kind == CafeObjectKind.frame) return CafeItemType.frame;
  if (id.startsWith('plant.') ||
      id.startsWith('garden.tree') ||
      id.startsWith('garden.flowers')) {
    return CafeItemType.plant;
  }
  if (id.startsWith('lamp.')) return CafeItemType.lamp;
  if (id.contains('.chair')) return CafeItemType.chair;
  if (id.endsWith('.table')) return CafeItemType.table;
  if (id.contains('.cup')) return CafeItemType.cup;
  if (id.contains('.book')) return CafeItemType.notebook;
  if (id.contains('.pen')) return CafeItemType.pencil;
  if (id.contains('.vase')) return CafeItemType.vase;
  return CafeItemType.decoration;
}

extension _IndividualCafeItems on CafeWorld {
  void _noteItem(
    String id,
    String label,
    double x,
    double y,
    double z, {
    double angle = 0,
    required Rect support,
  }) {
    final w = math.cos(angle).abs() * .43 + math.sin(angle).abs() * .30;
    final d = math.sin(angle).abs() * .43 + math.cos(angle).abs() * .30;
    _object(
      id,
      label,
      CafeObjectKind.prop,
      CafePoint(x, y, z),
      () {
        if (space.state(
          id,
          fallback: id == 'shared.book' ? space.bookOpen : true,
        )) {
          _book(x, y, z, angle: angle);
        } else {
          final start = faces.length;
          final cover = [
            CafeWorld.sage,
            const Color(0xffaa806b),
            const Color(0xff8d9683),
          ][space.finish(id)];
          box(x, y + .011, z, .43, .029, .30, cover, topFace: false);
          box(x, y + .015, z, .406, .019, .28, CafeWorld.cream, topFace: false);
          _roundedSlab(
            x,
            z,
            .43,
            .30,
            top: y + .034,
            thickness: .005,
            radius: .015,
            surface: null,
            color: cover,
          );
          _rotateItemFaces(start, CafePoint(x, y, z), angle);
        }
      },
      support: support,
      footprint: Rect.fromCenter(center: Offset(x, z), width: w, height: d),
    );
  }

  void _cupItem(
    String id,
    String label,
    double x,
    double y,
    double z, {
    required Rect support,
    double radius = .052,
    bool filled = true,
  }) {
    _object(
      id,
      label,
      CafeObjectKind.prop,
      CafePoint(x, y, z),
      () => _cup(x, y, z, radius: radius, filled: filled),
      support: support,
      defaultState: filled,
      footprint: Rect.fromCenter(
        center: Offset(x, z),
        width: radius * 3.1,
        height: radius * 2.85,
      ),
    );
  }

  void _pencilItem(
    String id,
    String label,
    double x,
    double y,
    double z, {
    required Rect support,
    double angle = 0,
  }) {
    _object(
      id,
      label,
      CafeObjectKind.prop,
      CafePoint(x, y, z),
      () {
        final start = faces.length;
        _pencil(x, y, z);
        _rotateItemFaces(start, CafePoint(x, y, z), angle);
      },
      support: support,
      footprint: Rect.fromCenter(
        center: Offset(x, z),
        width: math.cos(angle).abs() * .28 + math.sin(angle).abs() * .02,
        height: math.sin(angle).abs() * .28 + math.cos(angle).abs() * .02,
      ),
    );
  }

  void _vaseItem(
    String id,
    String label,
    double x,
    double bottom,
    double z, {
    required Rect support,
  }) {
    _object(
      id,
      label,
      CafeObjectKind.prop,
      CafePoint(x, bottom, z),
      () {
        final color = [
          const Color(0xffc4b390),
          const Color(0xffa37962),
          CafeWorld.sage,
        ][space.finish(id)];
        _turned(x, z, [
          (bottom + .004, .034),
          (bottom + .025, .052),
          (bottom + .09, .062),
          (bottom + .145, .047),
          (bottom + .18, .029),
          (bottom + .19, .030),
        ], color);
        cylinder(
          x,
          bottom + .181,
          z,
          .022,
          .002,
          const Color(0xff84775f),
          sides: 24,
        );
        if (space.state(id)) {
          for (var i = 0; i < 3; i++) {
            final top = CafePoint(
              x + (i - 1) * .04,
              bottom + .34 + i * .025,
              z,
            );
            _rod(
              CafePoint(x, bottom + .18, z),
              top,
              .0025,
              CafeWorld.sage,
              sides: 6,
            );
            for (var j = 0; j < 3; j++) {
              final p = CafePoint.lerp(
                CafePoint(x, bottom + .18, z),
                top,
                .4 + j * .18,
              );
              final direction = (j + i).isEven ? 1.0 : -1.0;
              final tip = p + CafePoint(direction * .055, .035, .012);
              for (final side in [-1.0, 1.0]) {
                for (var k = 0; k < 4; k++) {
                  final a = k / 4, b = (k + 1) / 4;
                  CafePoint edge(double t) =>
                      CafePoint.lerp(p, tip, t) +
                      CafePoint(
                        0,
                        .008 * math.sin(t * math.pi),
                        side * .016 * math.sin(t * math.pi),
                      );
                  faces.add(
                    CafeFace(
                      [
                        CafePoint.lerp(p, tip, a),
                        edge(a),
                        edge(b),
                        CafePoint.lerp(p, tip, b),
                      ],
                      [
                        CafeWorld.sage,
                        const Color(0xffaa7c62),
                        const Color(0xffd7d2b0),
                      ][space.accent(id)],
                      doubleSided: true,
                      target: _target,
                    ),
                  );
                }
              }
            }
          }
        }
      },
      support: support,
      footprint: Rect.fromCenter(center: Offset(x, z), width: .13, height: .13),
    );
  }

  void _chairItem(
    String id,
    String label,
    double x,
    double z, {
    double angle = 0,
    bool padded = false,
    required CafeSeat seat,
  }) {
    _object(
      id,
      label,
      CafeObjectKind.floor,
      CafePoint(x, 0, z),
      () => _chair(
        x,
        z,
        angle: angle,
        padded: space.state(id, fallback: padded),
      ),
      yaw: angle,
      seat: seat,
      defaultState: padded,
    );
  }

  void _tableItem(
    String id,
    String label,
    CafeSeat seat,
    void Function(Rect) props,
  ) {
    final bounds = CafeWorld.tableBounds(seat);
    _object(
      id,
      label,
      CafeObjectKind.floor,
      CafePoint(bounds.center.dx, 0, bounds.center.dy),
      () {
        _writingSurface(bounds, target: CafeTarget.forSeat(seat));
        _target = CafeTarget.forSeat(seat);
        props(bounds.deflate(.015));
        _target = null;
      },
    );
  }

  void _rotateItemFaces(int start, CafePoint center, double angle) {
    if (angle == 0) return;
    final c = math.cos(angle), s = math.sin(angle);
    CafePoint rotate(CafePoint p) =>
        CafePoint(p.x * c - p.z * s, p.y, p.x * s + p.z * c);
    for (final f in faces.skip(start)) {
      for (var i = 0; i < f.points.length; i++) {
        f.points[i] = center + rotate(f.points[i] - center);
        if (f.vertexNormals != null) {
          f.vertexNormals![i] = rotate(f.vertexNormals![i]);
        }
      }
    }
  }
}
