import 'dart:math' as math;
import 'dart:ui';
import 'cafe_camera.dart';
import 'cafe_world.dart';

class _CameraBlock {
  const _CameraBlock(this.bounds, this.height);
  final Rect bounds;
  final double height;
}

final _cameraBlocks = Expando<List<_CameraBlock>>();
List<_CameraBlock> _blocks(CafeWorld world) => _cameraBlocks[world] ??= [
  for (final rect in world.obstacles) _block(world, rect),
];
_CameraBlock _block(CafeWorld world, Rect rect) {
  final owners =
      world.objects.values
          .where((o) => o.ownedObstacles.contains(rect))
          .toList()
        ..sort(
          (a, b) => a.ownedObstacles.length.compareTo(b.ownedObstacles.length),
        );
  final owner = owners.isEmpty ? null : owners.first;
  var height = 0.0;
  for (final face in world.faces) {
    if (owner != null
        ? face.objectId != owner.id
        : face.layer != 2 ||
              face.center.y > 2.5 ||
              !rect
                  .inflate(.08)
                  .contains(Offset(face.center.x, face.center.z))) {
      continue;
    }
    for (final p in face.points) {
      height = math.max(height, p.y);
    }
  }
  return _CameraBlock(rect.inflate(.09), height > 0 ? height : 3.1);
}

/// Observer only: path finding and reach continue to use the actor's eye.
CafeCamera cafeChaseCamera(
  CafeCamera actor,
  CafeWorld world, {
  double hands = 0,
}) {
  final seated = ((1.62 - actor.position.y) / .44).clamp(0.0, 1.0);
  final shoulder = actor.right * (.18 + seated * .24 + hands * .15);
  final rawFocus = CafePoint(
    actor.position.x + shoulder.x,
    actor.position.y < 1 ? .64 : .98 + seated * .04,
    actor.position.z + shoulder.z,
  );
  var yaw = actor.yaw - hands * .55;
  var pitch = (actor.pitch * .45 - .16 - seated * .17).clamp(-.62, .10);
  final bounds = world.walkBounds.inflate(.11);
  final focus = CafePoint(
    rawFocus.x.clamp(bounds.left + .02, bounds.right - .02),
    rawFocus.y,
    rawFocus.z.clamp(bounds.top + .02, bounds.bottom - .02),
  );
  var direction = CafeCamera(position: focus, yaw: yaw, pitch: pitch).forward;
  final start = Offset(focus.x, focus.z);
  // A seated focus can be inside its chair/table bounds. Permit exiting that
  // support, then respect all other obstacles along the camera boom.
  final obstacles = _blocks(
    world,
  ).where((b) => !b.bounds.contains(start)).toList();
  double boom(CafePoint axis) {
    var distance = 0.0;
    for (var d = .05; d <= 2.25; d += .05) {
      final p = focus - axis * d;
      final point = Offset(p.x, p.z);
      if (!bounds.contains(point) ||
          obstacles.any(
            (b) => b.bounds.contains(point) && p.y < b.height + .08,
          )) {
        break;
      }
      distance = d;
    }
    return distance;
  }

  var distance = boom(direction);
  if (distance < .55) {
    // In a wall corner there isn't room even for a short boom. Slide around
    // the shoulder into free space, rather than placing the eye in the wall.
    var bestDistance = distance, bestYaw = yaw;
    for (final turn in [.45, -.45, .9, -.9, 1.4, -1.4, 2.0, -2.0, math.pi]) {
      final candidate = CafeCamera(
        position: focus,
        yaw: actor.yaw + turn,
        pitch: pitch,
      ).forward;
      final d = boom(candidate);
      if (d > bestDistance) {
        bestDistance = d;
        bestYaw = actor.yaw + turn;
      }
      if (d >= .8) break;
    }
    yaw = bestYaw;
    direction = CafeCamera(position: focus, yaw: yaw, pitch: pitch).forward;
    distance = boom(direction);
  }
  if (distance < .8 && pitch < -.12) {
    pitch = -.12;
    direction = CafeCamera(position: focus, yaw: yaw, pitch: pitch).forward;
    distance = boom(direction);
  }
  // Widen smoothly in tight spaces so the near wall doesn't fill the phone.
  return CafeCamera(
    position: focus - direction * distance,
    yaw: yaw,
    pitch: pitch,
    lens: math.min(1.0, math.max(.10, distance / 2.6)),
  );
}
