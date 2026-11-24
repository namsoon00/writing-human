part of 'cafe_world.dart';

/// Temporary first-person gestures. These never enter the saved room payload.
enum CafeUseKind {
  hold,
  pickUp,
  putDown,
  sip,
  refill,
  open,
  close,
  touch,
  write,
  water,
  pull,
  push,
}

class CafeUseFrame {
  const CafeUseFrame(
    this.id,
    this.kind, {
    this.progress = 0,
    this.held = false,
    this.open = false,
  });
  final String id;
  final CafeUseKind kind;
  final double progress;
  final bool held, open;
}

CafePoint _useRotate(CafePoint p, double yaw, double pitch, [double roll = 0]) {
  final x = p.x * math.cos(roll) - p.y * math.sin(roll);
  final y = p.x * math.sin(roll) + p.y * math.cos(roll);
  final yy = y * math.cos(pitch) - p.z * math.sin(pitch);
  final z = y * math.sin(pitch) + p.z * math.cos(pitch);
  return CafePoint(
    x * math.cos(yaw) - z * math.sin(yaw),
    yy,
    x * math.sin(yaw) + z * math.cos(yaw),
  );
}

CafeFace _useFace(
  CafeFace f,
  CafePoint Function(CafePoint) at,
  CafePoint Function(CafePoint) normal, {
  String? id,
  int? layer,
}) => CafeFace(
  f.points.map(at).toList(),
  f.color,
  wood: f.wood,
  unlit: f.unlit,
  garden: f.garden,
  sign: f.sign,
  doubleSided: f.doubleSided,
  layer: layer ?? f.layer,
  textureCoordinates:
      f.textureCoordinates ?? f.points.map(f.materialUv).toList(),
  target: f.target,
  signRow: f.signRow,
  surface: f.surface,
  grain: f.grain,
  vertexNormals: f.vertexNormals?.map(normal).toList(),
  vertexColors: f.vertexColors,
  materialTint: f.materialTint,
  objectId: id ?? f.objectId,
  artIndex: f.artIndex,
  part: f.part,
);

extension CafeUseGeometry on CafeWorld {
  /// Picking consumes this exact list too, including the lifted cup and handle.
  Iterable<CafeFace> presentedFaces(
    CafeCamera camera,
    CafeUseFrame? use,
  ) sync* {
    final obj = objects[use?.id];
    if (use == null || obj == null) {
      yield* faces;
      return;
    }
    final p = use.progress.clamp(0.0, 1.0);
    final wave = math.sin(p * math.pi);
    final lift = use.kind == CafeUseKind.pickUp
        ? p
        : use.kind == CafeUseKind.putDown
        ? 1 - p
        : use.held
        ? 1.0
        : 0.0;
    final cup = obj.type == CafeItemType.cup;
    final volume = obj.type == CafeItemType.volume;
    final pen = obj.type == CafeItemType.pencil;
    final sip = use.kind == CafeUseKind.sip ? wave : 0.0;
    final held =
        camera.position +
        camera.forward *
            (cup
                ? .48 - sip * .17
                : pen
                ? .43
                : .64) +
        camera.right *
            (cup
                ? .13 - sip * .1
                : pen
                ? .13
                : 0) +
        camera.up *
            (cup
                ? -.05 + sip * .11
                : volume
                ? -.30
                : -.07);
    final yaw = camera.yaw - (volume ? math.pi / 2 : 0);
    final pitch = volume ? 0.0 : camera.pitch + (pen ? .9 : .32 + sip * .72);
    final roll = pen ? 1.9 : 0.0;
    final rotation = (yaw - obj.yaw + math.pi) % (2 * math.pi) - math.pi;
    CafePoint n(CafePoint d) =>
        _useRotate(d, rotation * lift, pitch * lift, roll * lift);
    CafePoint at(CafePoint q) {
      final d = q - obj.pivot;
      var target = CafePoint.lerp(obj.pivot, held, lift);
      if (use.kind == CafeUseKind.pull || use.kind == CafeUseKind.push) {
        target +=
            _useRotate(const CafePoint(0, 0, .06), obj.yaw, 0) *
            (p * (use.kind == CafeUseKind.push ? -1 : 1));
      }
      if (use.kind == CafeUseKind.touch) {
        target += const CafePoint(0, .012, 0) * wave;
      }
      if (use.kind == CafeUseKind.write) {
        target += camera.right * (math.sin(p * math.pi * 10) * .012 * wave);
      }
      return target + n(d);
    }

    final foldingNote =
        obj.type == CafeItemType.notebook &&
        (use.kind == CafeUseKind.open || use.kind == CafeUseKind.close);
    final openedVolume =
        volume &&
        use.held &&
        (use.open ||
            use.kind == CafeUseKind.open ||
            use.kind == CafeUseKind.close);
    for (final f in faces) {
      if (f.objectId != use.id || (cup && f.part == null)) {
        yield f;
        continue;
      }
      if (foldingNote && f.color.a < .99) {
        yield f;
        continue;
      }
      if (openedVolume || foldingNote) continue;
      // Contact shadows belong on their support, never in mid-air.
      if (f.color.a < .99 && lift > 0) continue;
      yield _useFace(f, at, n, layer: lift > .001 ? 5 : null);
    }
    if (foldingNote) {
      final openness = use.kind == CafeUseKind.open ? p : 1 - p;
      for (final f in _foldBook(_useBook(use.id), openness)) {
        yield _useFace(
          f,
          (q) => obj.pivot + _useRotate(q, obj.yaw, 0),
          (n) => _useRotate(n, obj.yaw, 0),
          id: use.id,
        );
      }
    }
    if (openedVolume) {
      final open = use.kind == CafeUseKind.open
          ? p
          : use.kind == CafeUseKind.close
          ? 1 - p
          : 1.0;
      final book = _useBook(use.id);
      final anchor = camera.position + camera.forward * .66 + camera.up * -.14;
      CafePoint rotate(CafePoint q) =>
          _useRotate(q, camera.yaw, camera.pitch + 1.12);
      for (final f in _foldBook(book, open)) {
        yield _useFace(
          f,
          (q) => anchor + rotate(q),
          rotate,
          id: use.id,
          layer: 5,
        );
      }
    }
    if (use.kind == CafeUseKind.refill || use.kind == CafeUseKind.water) {
      final destination = use.kind == CafeUseKind.refill
          ? held + const CafePoint(0, .10, 0)
          : obj.pivot + const CafePoint(0, .32, 0);
      yield* _pourFaces(
        camera,
        destination,
        p,
        foreground: use.kind == CafeUseKind.refill,
      );
    }
  }

  List<CafeFace> _useBook(String id) {
    return _useBooks.putIfAbsent(id, () {
      final start = faces.length, oldId = _buildingObject;
      final target = _target;
      _buildingObject = id;
      _target = null;
      _book(0, 0, 0);
      final result = faces
          .sublist(start)
          .where((f) => f.color.a >= .99)
          .toList();
      faces.removeRange(start, faces.length);
      _buildingObject = oldId;
      _target = target;
      return result;
    });
  }

  /// The left leaf rotates about the spine; cut crossing polygons at the hinge.
  static Iterable<CafeFace> _foldBook(
    List<CafeFace> source,
    double open,
  ) sync* {
    final angle = -math.pi * (1 - open);
    for (final f in source) {
      if (f.color.a < .99) {
        yield f;
        continue;
      }
      for (final left in [false, true]) {
        final points = <CafePoint>[], uv = <Offset>[];
        final originalUv =
            f.textureCoordinates ?? f.points.map(f.materialUv).toList();
        for (var i = 0; i < f.points.length; i++) {
          final a = f.points[i], b = f.points[(i + 1) % f.points.length];
          final au = originalUv[i], bu = originalUv[(i + 1) % f.points.length];
          final inside = left ? a.x < 0 : a.x >= 0;
          final next = left ? b.x < 0 : b.x >= 0;
          if (inside) {
            points.add(a);
            uv.add(au);
          }
          if (inside != next) {
            final t = -a.x / (b.x - a.x);
            points.add(CafePoint.lerp(a, b, t));
            uv.add(Offset.lerp(au, bu, t)!);
          }
        }
        for (var i = points.length - 1; i >= 0 && points.length > 1; i--) {
          if ((points[i] - points[(i + 1) % points.length]).length < 1e-10) {
            points.removeAt(i);
            uv.removeAt(i);
          }
        }
        if (points.length < 3) continue;
        if ((points[1] - points[0]).cross(points[2] - points[0]).length <
            1e-12) {
          continue;
        }
        CafePoint rotate(CafePoint q) {
          if (!left) return q;
          final y = q.y - .024;
          return CafePoint(
            q.x * math.cos(angle) - y * math.sin(angle),
            .024 + q.x * math.sin(angle) + y * math.cos(angle),
            q.z,
          );
        }

        yield CafeFace(
          points.map(rotate).toList(),
          f.color,
          surface: f.surface,
          textureCoordinates: uv,
          objectId: f.objectId,
          target: f.target,
          sign: f.sign,
          signRow: f.signRow,
          artIndex: f.artIndex,
          unlit: f.unlit,
          wood: f.wood,
          garden: f.garden,
          grain: f.grain,
          part: f.part,
          materialTint: f.materialTint,
          doubleSided: f.doubleSided,
          layer: f.layer,
        );
      }
    }
  }

  Iterable<CafeFace> _pourFaces(
    CafeCamera camera,
    CafePoint target,
    double p, {
    bool foreground = false,
  }) {
    final wave = math.sin(p * math.pi), start = faces.length;
    final position =
        target +
        camera.right * (-.16) +
        const CafePoint(0, .23, 0) +
        camera.up * ((1 - wave) * .28);
    _turned(position.x, position.z, [
      (position.y, .04),
      (position.y + .03, .07),
      (position.y + .15, .05),
      (position.y + .18, .035),
    ], CafeWorld.cream);
    final spout = position + camera.right * .13 + const CafePoint(0, .08, 0);
    _rod(position + const CafePoint(0, .09, 0), spout, .016, CafeWorld.cream);
    _rod(
      position - camera.right * .05 + const CafePoint(0, .14, 0),
      position - camera.right * .09 + const CafePoint(0, .06, 0),
      .008,
      CafeWorld.brass,
    );
    if (p > .18 && p < .82) {
      _rod(spout, target, .0035, const Color(0xffb8c8c4), sides: 6);
    }
    final result = faces.sublist(start);
    faces.removeRange(start, faces.length);
    return foreground
        ? result.map((f) => _useFace(f, (q) => q, (n) => n, layer: 5))
        : result;
  }
}
