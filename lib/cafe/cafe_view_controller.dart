import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import 'cafe_camera.dart';
import 'cafe_visit.dart';
import 'cafe_world.dart';
import 'cafe_walk.dart';

class CafeViewController extends ChangeNotifier {
  CafeViewController({this.seat})
    : camera = seat == null ? CafeCamera.entrance : CafeCamera.seated(seat),
      inCourtyard = seat == CafeSeat.garden {
    bodyYaw = camera.yaw;
    gait.reset(CafePoint(camera.position.x, 0, camera.position.z), bodyYaw);
  }
  bool thirdPerson = false;
  double viewBlend = 0, bodyYaw = 0, walkSpeed = 0;
  int viewRequest = 0;
  double _followDistance = 2.15;
  void configureViewport(double width) {
    final distance = width < 600 ? 2.65 : 2.15;
    if (_followDistance != distance) {
      _followDistance = distance;
      _rear = null;
      _display = null;
    }
  }

  final gait = CafeGait();
  CafeCamera? _rear, _display;
  CafeSeat? _pendingSeat;
  CafeTarget? _departure;
  void togglePerspective() {
    thirdPerson = !thirdPerson;
    viewRequest++;
    notifyListeners();
  }

  void setViewBlend(double value, {bool notify = true}) {
    if (!value.isFinite) return;
    _display = null;
    viewBlend = value.clamp(0.0, 1.0);
    if (notify) notifyListeners();
  }

  bool get showAvatar =>
      viewBlend > .75 &&
      ((displayCamera.position - camera.position).length > .55);
  CafeCamera get displayCamera => _display ??= _displayCamera();
  CafeCamera _displayCamera() {
    if (viewBlend <= 0) return camera;
    final focus = CafePoint(
      camera.position.x,
      camera.position.y - .25,
      camera.position.z,
    );
    final desired =
        camera.position -
        cafeForward(camera.yaw) * _followDistance +
        cafeRight(camera.yaw) * .18 +
        const CafePoint(0, .18, 0);
    // Pull in immediately when blocked; outward following is smoothed in advanceCamera.
    final safe = world.clipCamera(focus, _rear?.position ?? desired);
    final delta = focus - safe;
    final rear = CafeCamera(
      position: safe,
      yaw: math.atan2(delta.x, -delta.z),
      pitch: math.atan2(
        delta.y,
        math.sqrt(delta.x * delta.x + delta.z * delta.z),
      ),
    );
    final mixed = CafeCamera.interpolate(camera, rear, viewBlend);
    return CafeCamera(
      position: world.clipCamera(camera.position, mixed.position),
      yaw: mixed.yaw,
      pitch: mixed.pitch,
    );
  }

  void _follow(double dt, {bool snap = false}) {
    final focus = CafePoint(
      camera.position.x,
      camera.position.y - .25,
      camera.position.z,
    );
    final desired =
        camera.position -
        cafeForward(camera.yaw) * _followDistance +
        cafeRight(camera.yaw) * .18 +
        const CafePoint(0, .18, 0);
    final safe = world.clipCamera(focus, desired);
    final p = snap || _rear == null
        ? safe
        : CafePoint.lerp(_rear!.position, safe, 1 - math.exp(-9 * dt));
    _rear = CafeCamera(position: world.clipCamera(focus, p));
  }

  void advanceCamera(
    CafeCamera value, {
    required double dt,
    required bool walking,
  }) {
    if (!value.isFinite || !dt.isFinite || dt <= 0) return;
    _display = null;
    final delta = value.position - camera.position;
    final ground = CafePoint(delta.x, 0, delta.z);
    camera = value;
    if (walking && ground.length > 1e-6) {
      final heading = math.atan2(ground.x, -ground.z);
      bodyYaw = cafeTurn(bodyYaw, heading, 1 - math.exp(-14 * dt));
      gait.move(CafePoint(value.position.x, 0, value.position.z), bodyYaw);
      walkSpeed = dt > 0 ? ground.length / dt : 0;
    } else {
      walkSpeed = 0;
    }
    if (thirdPerson || viewBlend > 0) _follow(dt);
    notifyListeners();
  }

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

  CafePoint get _origin {
    if (resting) return CafeWorld.approach(CafeTarget.bench);
    if (seat != null) return CafeWorld.approach(CafeTarget.forSeat(seat!));
    if (!world.canStand(camera.position) && _departure != null) {
      return CafeWorld.approach(_departure!);
    }
    return camera.position;
  }

  bool visit(CafeTarget target) {
    if (target.inCourtyard != inCourtyard) return false;
    final next = target.seat;
    final approach = CafeWorld.approach(target);
    final origin = _origin;
    final path = world.path(origin, approach);
    if (path.isEmpty) return false;
    _departure = resting
        ? CafeTarget.bench
        : seat == null
        ? _departure
        : CafeTarget.forSeat(seat!);
    arrival = target;
    resting = false;
    final gaze = CafeWorld.anchor(target);
    journey = [
      if (seat != null) _facing(origin, gaze),
      for (final p in path) _facing(p, gaze),
      if (next != null) CafeCamera.seated(next),
      if (target == CafeTarget.bench) CafeCamera.gardenRest,
      if (target == CafeTarget.pond) _facing(approach, gaze, pitch: -.55),
    ];
    _pendingSeat = next;
    seat = null;
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
    _departure = selected == null
        ? CafeTarget.bench
        : CafeTarget.forSeat(selected);
    resting = false;
    arrival = null;
    _pendingSeat = null;
    seat = null;
    journey = [CafeCamera(position: p, yaw: camera.yaw, pitch: -.10)];
    _begin();
  }

  bool walkTo(CafePoint point) {
    final origin = _origin;
    final target = CafePoint(point.x, 1.62, point.z);
    final path = world.path(origin, target);
    if (path.isEmpty) return false;
    _departure = resting
        ? CafeTarget.bench
        : seat == null
        ? _departure
        : CafeTarget.forSeat(seat!);
    seat = null;
    _pendingSeat = null;
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
    gait.reset(CafePoint(camera.position.x, 0, camera.position.z), bodyYaw);
    destination = journey.last;
    travelling = true;
    request++;
    notifyListeners();
  }

  void finishTravel() {
    seat = _pendingSeat;
    _pendingSeat = null;
    walkSpeed = 0;
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
    if (seat != null ||
        arrival == CafeTarget.bench ||
        arrival == CafeTarget.courtyard ||
        arrival == CafeTarget.cafeReturn) {
      bodyYaw = camera.yaw;
    }
    gait.reset(CafePoint(camera.position.x, 0, camera.position.z), bodyYaw);
    _rear = null;
    _display = null;
    _departure = null;
    resting = arrival == CafeTarget.bench;
    arrival = null;
    travelling = false;
    destination = null;
    journey = [];
    notifyListeners();
  }

  void look(double dx, double dy) {
    if (!dx.isFinite || !dy.isFinite) return;
    if (travelling && !world.canStand(camera.position) && _departure != null) {
      camera = CafeCamera(
        position: CafeWorld.approach(_departure!),
        yaw: camera.yaw,
        pitch: camera.pitch,
      );
    }
    if (travelling) seat = null;
    walkSpeed = 0;
    _pendingSeat = null;
    _departure = null;
    destination = null;
    journey = [];
    arrival = null;
    travelling = false;
    request++;
    camera = camera.look(dx, dy);
    _rear = null;
    _display = null;
    notifyListeners();
  }

  void updateCamera(CafeCamera value) {
    if (!value.isFinite) return;
    camera = value;
    bodyYaw = value.yaw;
    _rear = null;
    _display = null;
    notifyListeners();
  }

  void stopWalking() {
    walkSpeed = 0;
    notifyListeners();
  }

  bool freeStep(
    double sideways,
    double ahead,
    double dt, {
    bool animate = true,
  }) {
    if (seat != null ||
        resting ||
        !sideways.isFinite ||
        !ahead.isFinite ||
        !dt.isFinite ||
        dt <= 0) {
      return false;
    }
    final next = camera.moved(sideways, ahead);
    if (!world.clearSegment(camera.position, next.position)) {
      stopWalking();
      return false;
    }
    advanceCamera(next, dt: dt, walking: animate);
    return true;
  }

  void step(double sideways, double ahead) {
    if (resting || seat != null || !sideways.isFinite || !ahead.isFinite) {
      return;
    }
    if (travelling) look(0, 0);
    final next = camera.moved(sideways, ahead);
    if (!world.clearSegment(camera.position, next.position)) return;
    destination = null;
    travelling = false;
    journey = [];
    arrival = null;
    _pendingSeat = null;
    request++;
    advanceCamera(next, dt: .2, walking: true);
    walkSpeed = 0;
  }
}
