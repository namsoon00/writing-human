part of 'cafe_world.dart';

enum CafeObjectKind { floor, prop, frame, light }

class CafeObject {
  CafeObject(
    this.id,
    this.label,
    this.kind,
    this.pivot, {
    this.parent,
    this.support,
    this.footprint,
  });
  final String id, label;
  final CafeObjectKind kind;
  CafePoint pivot;
  String? parent;
  final Rect? support;
  Rect? footprint;
  int? defaultArtwork;
  Rect? frameBounds;
  List<Rect> ownedObstacles = [];
}

extension CafePersonalObjects on CafeWorld {
  Offset _woodCoordinates(CafeFace face, CafePoint p) {
    final n = face.normal;
    switch (face.grain) {
      case CafeGrain.x:
        if (n.x.abs() > .8) return Offset(p.z / .6, -p.y / .6);
        return Offset((n.y.abs() > .6 ? p.z : p.y) / .62, -p.x / 2.4);
      case CafeGrain.y:
        if (n.y.abs() > .8) return Offset(p.x / .6, -p.z / .6);
        return Offset((n.x.abs() > .6 ? p.z : p.x) / .62, -p.y / 2.4);
      case CafeGrain.z:
        if (n.z.abs() > .8) return Offset(p.x / .6, -p.y / .6);
        return Offset((n.y.abs() > .6 ? p.x : p.y) / .62, -p.z / 2.4);
    }
  }

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
            ((f.surface == CafeSurface.oak || f.surface == CafeSurface.walnut)
                ? f.points.map((p) => _woodCoordinates(f, p)).toList()
                : null),
        target: f.target,
        signRow: f.signRow,
        surface: f.surface,
        grain: f.grain,
        vertexNormals: f.vertexNormals?.map(normal).toList(),
        vertexColors: f.vertexColors,
        objectId: f.objectId ?? id,
        artIndex: f.artIndex,
      );
    }
    Rect? footprint;
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
      obstacles[i] = next;
      footprint = footprint?.expandToInclude(next) ?? next;
    }
    for (var i = lampStart; i < pendantLights.length; i++) {
      pendantLights[i] = at(pendantLights[i]);
    }
    for (final child in objects.values.where((o) => !before.contains(o.id))) {
      child.pivot = at(child.pivot);
    }
    if (support != null &&
        !support.contains(Offset(pivot.x + pose.x, pivot.z + pose.z))) {
      layoutError = 'support';
    }
    objects[id] = CafeObject(
      id,
      label,
      kind,
      at(pivot),
      parent: parent,
      support: support,
      footprint: footprint,
    );
    objects[id]!.ownedObstacles = obstacles.skip(obstacleStart).toList();
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

  CafePoint targetAnchor(CafeTarget t) => _targetPoint(CafeWorld.anchor(t), t);
  CafePoint targetApproach(CafeTarget t) =>
      _targetPoint(CafeWorld.approach(t), t);
  CafePoint targetDesk(CafeSeat s) {
    var p = CafeWorld.desk(s);
    if (s == CafeSeat.shared) {
      final pose = space.pose('shared.book');
      p = p + CafePoint(pose.x, pose.y, pose.z);
    }
    return _targetPoint(p, CafeTarget.forSeat(s));
  }

  CafeCamera seatedCamera(CafeSeat s) {
    final base = CafeCamera.seated(s), t = CafeTarget.forSeat(s);
    return CafeCamera(
      position: _targetPoint(base.position, t),
      yaw: base.yaw + space.pose(_group(t) ?? '').turn,
      pitch: base.pitch,
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
      (o) => o.kind == CafeObjectKind.floor,
    )) {
      final pose = space.pose(obj.id), b = obj.footprint;
      if (b == null || (pose.x == 0 && pose.z == 0 && pose.turn == 0)) continue;
      if (b.left < -4.12 ||
          b.right > 4.12 ||
          b.top < -4.72 ||
          b.bottom > 4.72) {
        return 'boundary';
      }
      if (b.overlaps(const Rect.fromLTWH(-4.35, -4.5, 1.8, 1.85))) {
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
        if (b.inflate(.025).overlaps(other.footprint!)) return 'overlap';
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
      final angle = -space.pose(parent).turn;
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
