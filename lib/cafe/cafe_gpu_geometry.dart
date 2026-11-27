part of 'cafe_renderer.dart';

/// Unprojected shared geometry for a depth-buffer renderer. Picking and movement
/// still use CafeWorld; writing and persisted room values are never changed.
class CafeGpuBatch {
  CafeGpuBatch(this.key, this.room, this.alpha, this.cutout);
  final String key;
  final int room;
  final bool alpha, cutout;
  final values = <double>[];
  late final Float32List data = Float32List.fromList(values);
}

class CafeGpuGeometry {
  CafeGpuGeometry(this.painter);
  final CafeRenderer painter;
  final images = <ui.Image>[];
  final objectIds = <String, int>{};
  List<CafeFace>? _avatarFaces;
  int? _avatarRoom;
  List<CafeGpuBatch> _avatarBatches = [];
  int id(String? value) => value == null
      ? 0
      : objectIds.putIfAbsent(value, () => objectIds.length + 1);
  ui.Image? texture(CafeFace face) => painter._texture(face);
  String imageId(ui.Image? image) {
    if (image == null) return 'none';
    var i = images.indexOf(image);
    if (i < 0) {
      i = images.length;
      images.add(image);
    }
    return 'i${identityHashCode(image)}';
  }

  CafePoint transform(CafePoint p, int room, {bool normal = false}) {
    if (room == 0) return p;
    if (painter.world.courtyard) {
      return CafePoint(-p.z, p.y, p.x + (normal ? 0 : 7.4));
    }
    return CafePoint(p.z - (normal ? 0 : 7.4), p.y, -p.x);
  }

  List<CafeGpuBatch> batches(
    Iterable<CafeFace> faces,
    int room, {
    bool moving = false,
    String namespace = '',
  }) {
    final groups = <String, CafeGpuBatch>{};
    for (final f in faces) {
      if (f.garden || f.points.length < 3) continue;
      final image = texture(f);
      if ((f.surface == CafeSurface.tree ||
              f.surface == CafeSurface.flowers ||
              f.surface == CafeSurface.blossom) &&
          image == null) {
        continue;
      }
      final cutout =
          f.surface == CafeSurface.tree ||
          f.surface == CafeSurface.flowers ||
          f.surface == CafeSurface.blossom;
      final alpha = f.color.a < .99 && !cutout;
      final key =
          '${imageId(image)}:$room:$alpha:$cutout${namespace.isEmpty ? '' : ':$namespace'}';
      final b = groups.putIfAbsent(
        key,
        () => CafeGpuBatch(key, room, alpha, cutout),
      );
      final textured = image != null;
      final base =
          f.vertexColors == null &&
              textured &&
              ![
                CafeSurface.plain,
                CafeSurface.plaster,
                CafeSurface.limestone,
                CafeSurface.water,
                CafeSurface.brass,
              ].contains(f.surface)
          ? f.materialTint
          : f.color;
      Offset uv(int i) {
        if (f.textureCoordinates != null) {
          final q = f.textureCoordinates![i];
          if (f.artIndex != null &&
              (painter.framedArt.length <= f.artIndex! ||
                  painter.framedArt[f.artIndex!] == null)) {
            return Offset(q.dx, (q.dy + f.artIndex!) / 3);
          }
          return q;
        }
        if (f.sign && f.points.length >= 4) {
          final a = f.points[0],
              u = f.points[1] - a,
              v = f.points[3] - a,
              d = f.points[i] - a;
          return Offset(
            d.dot(u) / u.dot(u),
            (f.signRow + 1 - d.dot(v) / v.dot(v)) / 5,
          );
        }
        return f.materialUv(f.points[i]);
      }

      for (var j = 1; j + 1 < f.points.length; j++) {
        for (final i in [0, j, j + 1]) {
          final p = transform(f.points[i], room),
              n = transform(
                f.vertexNormals?[i] ?? f.normal,
                room,
                normal: true,
              );
          final t = uv(i), c = f.vertexColors?[i] ?? base;
          b.values.addAll([
            p.x,
            p.y,
            p.z,
            n.x,
            n.y,
            n.z,
            t.dx,
            t.dy,
            c.r,
            c.g,
            c.b,
            c.a,
            f.unlit || f.vertexColors != null ? 1 : 0,
            moving ? 0 : id(f.objectId).toDouble(),
            f.layer.toDouble(),
            f.points[i].x,
          ]);
        }
      }
    }
    return groups.values.toList();
  }

  List<CafeGpuBatch> staticBatches() => [
    ...batches(painter.world.faces, 0),
    ...batches(painter.world.linkedWorld.faces, 1),
  ];
  CafeCamera cameraFor(CafeRenderer p) => identical(p.world, painter.world)
      ? p.camera
      : p.world.linkedCamera(p.camera);
  List<CafeGpuBatch> moving(CafeRenderer p) {
    final result = <CafeGpuBatch>[];
    final activeRoom = identical(p.world, painter.world) ? 0 : 1;
    if (!identical(_avatarFaces, p.avatar) || _avatarRoom != activeRoom) {
      _avatarFaces = p.avatar;
      _avatarRoom = activeRoom;
      _avatarBatches = batches(
        p.avatar,
        activeRoom,
        moving: true,
        namespace: 'avatar',
      );
    }
    result.addAll(_avatarBatches);
    for (final room in [0, 1]) {
      final world = room == 0 ? painter.world : painter.world.linkedWorld;
      final camera = identical(p.world, world)
          ? p.camera
          : p.world.linkedCamera(p.camera);
      final faces = <CafeFace>[
        ...world.plantFaces(camera),
        ...world.lightFaces(camera),
        ...world.weatherFaces(camera, p.time),
        ...world.animatedFaces(
          p.time,
          teaFilled: p.teaFilled && p.use?.id != 'garden.cup',
          bellAt: p.bellAt,
          teaAt: p.teaAt,
        ),
        if (room == activeRoom && p.use != null)
          ...world
              .presentedFaces(
                p.useCamera ?? p.camera,
                p.use,
                thirdPerson: p.useCamera != null,
              )
              .where((f) => f.objectId == p.use!.id),
      ];
      result.addAll(batches(faces, room, moving: true, namespace: 'effects'));
    }
    return result;
  }

  List<Map<String, Object>> rooms(CafeRenderer p) => [
    for (var room = 0; room < 2; room++) _room(p, room),
  ];
  Map<String, Object> _room(CafeRenderer p, int room) {
    final world = room == 0 ? painter.world : painter.world.linkedWorld;
    final t = world.courtyard ? p._lightFrame.outdoor : p._lightFrame.indoor;
    List<double> lamps(List<CafePoint> points, List<double> gains, int limit) =>
        [
          for (var i = 0; i < math.min(points.length, limit); i++) ...[
            transform(points[i], room).x,
            transform(points[i], room).y,
            transform(points[i], room).z,
            gains[i],
          ],
        ];
    return {
      'outside': world.courtyard,
      'mood': world.space.home.mood,
      'lamps': lamps(world.pendantLights, world.pendantGains, 32),
      'walls': lamps(world.wallLights, world.wallGains, 12),
      'tint': [t.x, t.y, t.z],
      'lampScale': p._lightFrame.lamps,
      'brightness': world.space.brightness,
      'warmth': world.space.warmth,
    };
  }
}
