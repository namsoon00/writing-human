part of 'cafe_world.dart';

enum CafeObjectKind { group, floor, prop, frame, light, garden }

class CafeObject {
  CafeObject(
    this.id,
    this.label,
    this.kind,
    this.pivot, {
    this.parent,
    this.support,
    this.footprint,
    this.type = CafeItemType.decoration,
    this.yaw = 0,
    this.seat,
    this.defaultState = true,
    this.defaultFinish = 0,
  });
  final String id, label;
  final CafeObjectKind kind;
  final CafeItemType type;
  final CafeSeat? seat;
  double yaw;
  final bool defaultState;
  final int defaultFinish;
  CafePoint pivot;
  String? parent;
  final Rect? support;
  Rect? footprint;
  int? defaultArtwork;
  Rect? frameBounds;
  List<Rect> ownedObstacles = [];
  List<List<CafePoint>> collisionPolygons = [];
}

extension CafePersonalObjects on CafeWorld {
  CafePoint _transform(CafePoint p, CafePoint pivot, CafePose pose) {
    final d = p - pivot, c = math.cos(pose.turn), s = math.sin(pose.turn);
    return CafePoint(
      pivot.x + d.x * c - d.z * s + pose.x,
      p.y + pose.y,
      pivot.z + d.x * s + d.z * c + pose.z,
    );
  }

  void _object(
    String id,
    String label,
    CafeObjectKind kind,
    CafePoint pivot,
    void Function() build, {
    Rect? support,
    Rect? footprint,
    CafeItemType? type,
    double yaw = 0,
    CafeSeat? seat,
    bool defaultState = true,
    int defaultFinish = 0,
  }) {
    final faceStart = faces.length,
        obstacleStart = obstacles.length,
        lampStart = pendantLights.length;
    final before = objects.keys.toSet(), parent = _buildingObject;
    _buildingObject = id;
    build();
    _buildingObject = parent;
    final pose = space.pose(id);
    CafePoint at(CafePoint p) => _transform(p, pivot, pose);
    CafePoint normal(CafePoint n) => CafePoint(
      n.x * math.cos(pose.turn) - n.z * math.sin(pose.turn),
      n.y,
      n.x * math.sin(pose.turn) + n.z * math.cos(pose.turn),
    );
    for (var i = faceStart; i < faces.length; i++) {
      final f = faces[i];
      faces[i] = CafeFace(
        f.points.map(at).toList(),
        f.color,
        wood: f.wood,
        unlit: f.unlit,
        garden: f.garden,
        sign: f.sign,
        doubleSided: f.doubleSided,
        layer: f.layer,
        textureCoordinates:
            f.textureCoordinates ??
            (!f.sign && !f.garden ? f.points.map(f.materialUv).toList() : null),
        target: f.target,
        signRow: f.signRow,
        surface: f.surface,
        grain: f.grain,
        vertexNormals: f.vertexNormals?.map(normal).toList(),
        vertexColors: f.vertexColors,
        materialTint: f.materialTint,
        objectId: f.objectId ?? id,
        artIndex: f.artIndex,
      );
    }
    Rect transformRect(Rect rect) {
      final points = [
        rect.topLeft,
        rect.topRight,
        rect.bottomLeft,
        rect.bottomRight,
      ].map((p) => at(CafePoint(p.dx, 0, p.dy))).toList();
      return Rect.fromLTRB(
        points.map((p) => p.x).reduce(math.min),
        points.map((p) => p.z).reduce(math.min),
        points.map((p) => p.x).reduce(math.max),
        points.map((p) => p.z).reduce(math.max),
      );
    }

    List<CafePoint> corners(Rect r) => [
      r.topLeft,
      r.topRight,
      r.bottomRight,
      r.bottomLeft,
    ].map((p) => at(CafePoint(p.dx, 0, p.dy))).toList();
    final polygons = [
      if (footprint != null) corners(footprint),
      for (final r in obstacles.skip(obstacleStart)) corners(r),
    ];
    Rect? bounds = footprint == null ? null : transformRect(footprint);
    final transformed = <Rect, Rect>{};
    for (var i = obstacleStart; i < obstacles.length; i++) {
      final rect = obstacles[i];
      final points = [
        rect.topLeft,
        rect.topRight,
        rect.bottomLeft,
        rect.bottomRight,
      ].map((p) => at(CafePoint(p.dx, 0, p.dy))).toList();
      final next = Rect.fromLTRB(
        points.map((p) => p.x).reduce(math.min),
        points.map((p) => p.z).reduce(math.min),
        points.map((p) => p.x).reduce(math.max),
        points.map((p) => p.z).reduce(math.max),
      );
      transformed[rect] = next;
      obstacles[i] = next;
      bounds = bounds?.expandToInclude(next) ?? next;
    }
    for (var i = lampStart; i < pendantLights.length; i++) {
      pendantLights[i] = at(pendantLights[i]);
    }
    for (final child in objects.values.where((o) => !before.contains(o.id))) {
      child.pivot = at(child.pivot);
      child.yaw += pose.turn;
      child.collisionPolygons = child.collisionPolygons
          .map((p) => p.map(at).toList())
          .toList();
      if (child.footprint != null) {
        child.footprint = transformRect(child.footprint!);
      }
      child.ownedObstacles = child.ownedObstacles
          .map((r) => transformed[r] ?? r)
          .toList();
    }
    if (support != null &&
        (bounds == null ||
            !support.inflate(.001).contains(bounds.topLeft) ||
            !support.inflate(.001).contains(bounds.bottomRight))) {
      layoutError = 'support';
    }
    objects[id] = CafeObject(
      id,
      label,
      kind,
      at(pivot),
      parent: parent,
      support: support,
      footprint: bounds,
      type: type ?? _itemType(id, kind),
      yaw: yaw + pose.turn,
      seat: seat,
      defaultState: defaultState,
      defaultFinish: defaultFinish,
    );
    objects[id]!.ownedObstacles = obstacles.skip(obstacleStart).toList();
    objects[id]!.collisionPolygons = polygons;
  }

  String? _group(CafeTarget target) => switch (target) {
    CafeTarget.shared => 'shared',
    CafeTarget.window => 'desk.window',
    CafeTarget.windowMiddle => 'desk.windowMiddle',
    CafeTarget.windowRear => 'desk.windowRear',
    CafeTarget.quiet => 'quiet',
    _ => null,
  };
  CafePoint _targetPoint(CafePoint p, CafeTarget t) {
    final id = _group(t);
    if (id == null) return p;
    final pivot = switch (id) {
      'shared' => const CafePoint(0, 0, 0),
      'quiet' => const CafePoint(-1.70, 0, -4.02),
      _ => CafePoint(-3.4, 0, CafeWorld.desk(t.seat!).z),
    };
    return _transform(p, pivot, space.pose(id));
  }

  String? _tableId(CafeTarget t) =>
      (t == CafeTarget.gardenDesk || t == CafeTarget.tea)
      ? 'garden.table'
      : _group(t) == null
      ? null
      : '${_group(t)}.table';
  CafePoint _tablePoint(CafePoint p, CafeTarget t) {
    final id = _tableId(t);
    if (id == null) return _targetPoint(p, t);
    final bounds = CafeWorld.tableBounds(t.seat ?? CafeSeat.garden);
    return _targetPoint(
      _transform(
        p,
        CafePoint(bounds.center.dx, 0, bounds.center.dy),
        space.pose(id),
      ),
      t,
    );
  }

  CafePoint targetAnchor(CafeTarget t) => _tablePoint(CafeWorld.anchor(t), t);
  CafePoint targetApproach(CafeTarget t) {
    final p = _tablePoint(CafeWorld.approach(t), t);
    if (canStand(p)) return p;
    // Use a nearby clear point after an individual chair is moved.
    for (final radius in [.25, .45, .65]) {
      for (var i = 0; i < 16; i++) {
        final candidate =
            p +
            CafePoint(
              math.cos(i * math.pi / 8) * radius,
              0,
              math.sin(i * math.pi / 8) * radius,
            );
        if (canStand(candidate)) return candidate;
      }
    }
    return p;
  }

  CafePoint targetDesk(CafeSeat s) {
    if (s == CafeSeat.garden) {
      return objects['garden.book']?.pivot ?? CafeWorld.desk(s);
    }
    final id = _group(CafeTarget.forSeat(s));
    return objects['$id.book']?.pivot ??
        _tablePoint(CafeWorld.desk(s), CafeTarget.forSeat(s));
  }

  CafeCamera seatedCamera(CafeSeat s, {String? chairId}) {
    final chair = objects[chairId];
    if (chair?.type == CafeItemType.chair) {
      return CafeCamera(
        position: chair!.pivot + const CafePoint(0, 1.18, 0),
        yaw: chair.yaw,
        pitch: -.50,
      );
    }
    final base = CafeCamera.seated(s), t = CafeTarget.forSeat(s);
    final id = _group(t);
    final defaultChair = id == 'shared' ? null : objects['$id.chair'];
    if (defaultChair != null) return seatedCamera(s, chairId: defaultChair.id);
    return CafeCamera(
      position: _targetPoint(base.position, t),
      yaw: base.yaw + space.pose(id ?? '').turn,
      pitch: base.pitch,
    );
  }

  CafePoint chairApproach(String id) {
    final chair = objects[id]!;
    final back = CafePoint(-math.sin(chair.yaw), 0, math.cos(chair.yaw));
    final right = CafePoint(math.cos(chair.yaw), 0, math.sin(chair.yaw));
    for (final delta in [back * .65, right * .65, right * -.65, back * .85]) {
      final p = chair.pivot + const CafePoint(0, 1.62, 0) + delta;
      if (canStand(p)) return p;
    }
    return targetApproach(CafeTarget.forSeat(chair.seat!));
  }

  bool _itemChanged(String id) {
    String? next = id;
    while (next != null) {
      final p = space.pose(next);
      if (p.x != 0 || p.z != 0 || p.turn != 0) return true;
      next = objects[next]?.parent;
    }
    return false;
  }

  bool _itemsOverlap(CafeObject a, CafeObject b, {double gap = 0}) {
    bool overlap(List<CafePoint> p, List<CafePoint> q) {
      for (final points in [p, q]) {
        for (var i = 0; i < points.length; i++) {
          final edge = points[(i + 1) % points.length] - points[i];
          final axis = CafePoint(-edge.z, 0, edge.x).normalized;
          final pp = p.map((v) => v.dot(axis)), qq = q.map((v) => v.dot(axis));
          if (pp.reduce(math.max) + gap <= qq.reduce(math.min) ||
              qq.reduce(math.max) + gap <= pp.reduce(math.min)) {
            return false;
          }
        }
      }
      return true;
    }

    return a.collisionPolygons.any(
      (p) => b.collisionPolygons.any((q) => overlap(p, q)),
    );
  }

  String? validateLayout() {
    if (layoutError != null) return layoutError;
    for (final obj in objects.values) {
      final pose = space.pose(obj.id);
      if (obj.kind != CafeObjectKind.frame && pose.y.abs() > .0001) {
        return 'support';
      }
      if (obj.kind == CafeObjectKind.frame &&
          (pose.z.abs() > .0001 ||
              pose.turn.abs() > .0001 ||
              obj.pivot.x.abs() > 3.8 ||
              obj.pivot.y < 1.2 ||
              obj.pivot.y > 2.2)) {
        return 'wall';
      }
      if (obj.kind == CafeObjectKind.light &&
          (pose.x != 0 || pose.z != 0 || pose.turn != 0)) {
        return 'fixed';
      }
      if (obj.frameBounds != null) {
        for (final other in objects.values.where(
          (v) =>
              v.id != obj.id &&
              v.frameBounds != null &&
              (v.pivot.z - obj.pivot.z).abs() < .12,
        )) {
          if (obj.frameBounds!.inflate(.02).overlaps(other.frameBounds!)) {
            return 'overlap';
          }
        }
      }
    }
    for (final obj in objects.values.where(
      (o) => o.kind == CafeObjectKind.prop && _itemChanged(o.id),
    )) {
      if (obj.type == CafeItemType.cloth || obj.footprint == null) continue;
      for (final other in objects.values.where(
        (o) =>
            o.id != obj.id &&
            o.parent == obj.parent &&
            o.kind == CafeObjectKind.prop &&
            o.type != CafeItemType.cloth &&
            o.footprint != null &&
            (o.pivot.y - obj.pivot.y).abs() < .08,
      )) {
        if (_itemsOverlap(obj, other, gap: -.005)) return 'overlap';
      }
    }
    for (final obj in objects.values.where(
      (o) => o.kind == CafeObjectKind.floor,
    )) {
      final b = obj.footprint;
      if (b == null || !_itemChanged(obj.id)) continue;
      if (b.left < -4.12 ||
          b.right > 4.12 ||
          b.top < -4.72 ||
          b.bottom > 4.72) {
        return 'boundary';
      }
      if (b.overlaps(const Rect.fromLTWH(-4.35, -4.5, 1.8, 1.85))) {
        return 'door';
      }
      if (b.overlaps(const Rect.fromLTWH(-1.30, 3.70, 2.60, 1.30))) {
        return 'door';
      }
      final owned = objects.values
          .where((o) => o.kind == CafeObjectKind.floor)
          .expand((o) => o.ownedObstacles)
          .toSet();
      for (final obstacle in obstacles.where((r) => !owned.contains(r))) {
        if (b.inflate(.02).overlaps(obstacle)) return 'overlap';
      }
      for (final other in objects.values.where(
        (o) =>
            o.kind == CafeObjectKind.floor &&
            o.id != obj.id &&
            o.footprint != null,
      )) {
        if (_itemsOverlap(obj, other, gap: .025)) return 'overlap';
      }
    }
    for (final item in objects.values.where(
      (o) => o.kind == CafeObjectKind.garden && _itemChanged(o.id),
    )) {
      final p = item.pivot;
      if (p.x.abs() > 4.05 || p.z < -2.7 || p.z > 2.55) return 'boundary';
      if (item.type == CafeItemType.plant) {
        // Keep plants on the banks, away from pond, bench and returning door.
        if (math.pow((p.x + 1.25) / 1.24, 2) + math.pow((p.z - 1) / 1.56, 2) <
                1 ||
            (p.x > 2.5 && p.z > -.9) ||
            (p.x > .8 && p.z > -.3)) {
          return 'support';
        }
      }
      if (item.type == CafeItemType.table &&
          (p.x < 2.85 || p.x > 3.18 || p.z < .3 || p.z > .9)) {
        return 'support';
      }
    }
    if (!canStand(CafeCamera.entrance.position) && !courtyard) {
      return 'entrance';
    }
    final start = courtyard
        ? CafeCamera.courtyardEntrance.position
        : CafeCamera.entrance.position;
    for (final t in targets) {
      if (path(start, targetApproach(t)).isEmpty) return 'path';
    }
    return null;
  }

  CafeSpace placed(String id, CafePoint point) {
    final object = objects[id]!, current = space.pose(id);
    var delta = point - object.pivot;
    final parent = object.parent;
    if (parent != null) {
      var angle = 0.0;
      String? ancestor = parent;
      while (ancestor != null) {
        angle -= space.pose(ancestor).turn;
        ancestor = objects[ancestor]?.parent;
      }
      delta = CafePoint(
        delta.x * math.cos(angle) - delta.z * math.sin(angle),
        delta.y,
        delta.x * math.sin(angle) + delta.z * math.cos(angle),
      );
    }
    final wall = object.kind == CafeObjectKind.frame;
    return space.copy(
      poses: {
        ...space.poses,
        id: current.copy(
          x: current.x + delta.x,
          y: wall ? current.y + delta.y : current.y,
          z: wall ? current.z : current.z + delta.z,
        ),
      },
    );
  }
}
