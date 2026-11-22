import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import 'cafe_camera.dart';
import 'cafe_visit.dart';
import 'cafe_world.dart';

class CafeViewController extends ChangeNotifier {
  CafeViewController({this.seat})
    : camera = seat == null ? CafeCamera.entrance : CafeCamera.seated(seat),
      inCourtyard = seat == CafeSeat.garden;
  final _cafe = CafeWorld();
  late final _courtyard = CafeWorld(courtyard: true);
  bool inCourtyard;
  bool resting = false, teaFilled = false;
  double effectTime = 0;
  double? bellAt, teaAt;
  void ring() {
    bellAt = effectTime;
    notifyListeners();
  }

  void pourTea() {
    teaFilled = true;
    teaAt = effectTime;
    notifyListeners();
  }

  CafeTarget? arrival;
  CafeWorld get world => inCourtyard ? _courtyard : _cafe;
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
    if (target.inCourtyard != inCourtyard) return false;
    arrival = target;
    final next = target.seat;
    final approach = CafeWorld.approach(target);
    final origin = resting
        ? CafeWorld.approach(CafeTarget.bench)
        : seat == null
        ? camera.position
        : CafeWorld.approach(CafeTarget.forSeat(seat!));
    final path = world.path(origin, approach);
    if (path.isEmpty) return false;
    resting = false;
    final gaze = CafeWorld.anchor(target);
    journey = [
      if (seat != null) _facing(origin, gaze),
      for (final p in path) _facing(p, gaze),
      if (next != null) CafeCamera.seated(next),
      if (target == CafeTarget.bench) CafeCamera.gardenRest,
      if (target == CafeTarget.pond) _facing(approach, gaze, pitch: -.55),
    ];
    seat = next;
    _begin();
    return true;
  }

  void sit(CafeSeat value) => visit(CafeTarget.forSeat(value));

  void stand() {
    final selected = seat;
    if (selected == null && !resting) return;
    final p = CafeWorld.approach(
      selected == null ? CafeTarget.bench : CafeTarget.forSeat(selected),
    );
    resting = false;
    arrival = null;
    seat = null;
    journey = [CafeCamera(position: p, yaw: camera.yaw, pitch: -.10)];
    _begin();
  }

  bool walkTo(CafePoint point) {
    final origin = resting
        ? CafeWorld.approach(CafeTarget.bench)
        : seat == null
        ? camera.position
        : CafeWorld.approach(CafeTarget.forSeat(seat!));
    final target = CafePoint(point.x, 1.62, point.z);
    final path = world.path(origin, target);
    if (path.isEmpty) return false;
    seat = null;
    resting = false;
    arrival = null;
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
    if (arrival == CafeTarget.courtyard) {
      inCourtyard = true;
      camera = CafeCamera.courtyardEntrance;
      seat = null;
    } else if (arrival == CafeTarget.cafeReturn) {
      inCourtyard = false;
      camera = CafeCamera(
        position: CafeWorld.approach(CafeTarget.courtyard),
        yaw: math.pi,
        pitch: -.1,
      );
      seat = null;
    }
    resting = arrival == CafeTarget.bench;
    arrival = null;
    travelling = false;
    destination = null;
    journey = [];
    notifyListeners();
  }

  void look(double dx, double dy) {
    if (!dx.isFinite || !dy.isFinite) return;
    destination = null;
    journey = [];
    arrival = null;
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
    if (resting || seat != null || !sideways.isFinite || !ahead.isFinite) {
      return;
    }
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
