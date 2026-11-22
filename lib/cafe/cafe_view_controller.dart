import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import 'cafe_camera.dart';
import 'cafe_visit.dart';
import 'cafe_world.dart';

class CafeViewController extends ChangeNotifier {
  CafeViewController({this.seat})
    : camera = seat == null ? CafeCamera.entrance : CafeCamera.seated(seat);
  final world = CafeWorld();
  CafeSeat? seat;
  CafeCamera camera;
  CafeCamera? destination;
  List<CafeCamera> journey = [];
  int request = 0;
  bool travelling = false;

  CafeCamera _facing(CafePoint p, CafePoint target, {double pitch = -.10}) =>
      CafeCamera(
        position: p,
        yaw: math.atan2(target.x - p.x, p.z - target.z),
        pitch: pitch,
      );

  bool visit(CafeTarget target) {
    final next = target.seat;
    final approach = CafeWorld.approach(target);
    final origin = seat == null
        ? camera.position
        : CafeWorld.approach(CafeTarget.forSeat(seat!));
    final path = world.path(origin, approach);
    if (path.isEmpty) return false;
    final gaze = CafeWorld.anchor(target);
    journey = [
      if (seat != null) _facing(origin, gaze),
      for (final p in path) _facing(p, gaze),
      if (next != null) CafeCamera.seated(next),
    ];
    seat = next;
    _begin();
    return true;
  }

  void sit(CafeSeat value) => visit(CafeTarget.forSeat(value));

  void stand() {
    final selected = seat;
    if (selected == null) return;
    final p = CafeWorld.approach(CafeTarget.forSeat(selected));
    seat = null;
    journey = [CafeCamera(position: p, yaw: camera.yaw, pitch: -.10)];
    _begin();
  }

  bool walkTo(CafePoint point) {
    final origin = seat == null
        ? camera.position
        : CafeWorld.approach(CafeTarget.forSeat(seat!));
    final target = CafePoint(point.x, 1.62, point.z);
    final path = world.path(origin, target);
    if (path.isEmpty) return false;
    seat = null;
    journey = [
      if ((origin - camera.position).length > .1)
        CafeCamera(position: origin, yaw: camera.yaw, pitch: -.10),
      for (final p in path)
        CafeCamera(
          position: p,
          yaw: camera.yaw,
          pitch: camera.pitch.clamp(-.22, .12),
        ),
    ];
    _begin();
    return true;
  }

  void _begin() {
    destination = journey.last;
    travelling = true;
    request++;
    notifyListeners();
  }

  void finishTravel() {
    travelling = false;
    destination = null;
    journey = [];
    notifyListeners();
  }

  void look(double dx, double dy) {
    if (!dx.isFinite || !dy.isFinite) return;
    destination = null;
    journey = [];
    travelling = false;
    request++;
    camera = camera.look(dx, dy);
    notifyListeners();
  }

  void updateCamera(CafeCamera value) {
    if (!value.isFinite) return;
    camera = value;
    notifyListeners();
  }

  void step(double sideways, double ahead) {
    if (seat != null || !sideways.isFinite || !ahead.isFinite) return;
    final next = camera.moved(sideways, ahead);
    if (!world.clearSegment(camera.position, next.position)) return;
    destination = null;
    travelling = false;
    journey = [];
    request++;
    camera = next;
    notifyListeners();
  }
}
