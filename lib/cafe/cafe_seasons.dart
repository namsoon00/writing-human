part of 'cafe_world.dart';

/// Weather belongs to the yard, including when seen through the cafe bay.
extension CafeSeasons on CafeWorld {
  CafeWeather get weather =>
      space.atmosphere.weather ??
      (space.home.mood == 2 ? CafeWeather.rain : CafeWeather.clear);

  Iterable<CafeFace> weatherFaces(CafeCamera camera, double seconds) sync* {
    if (weather == CafeWeather.clear) return;
    final time = space.atmosphere.weatherMotion ? seconds : 0.0;
    if (!courtyard) {
      if (weather == CafeWeather.rain) yield* _rainWindowFaces(camera, time);
      return;
    }
    final random = math.Random(612);
    final region = walkBounds.deflate(.25);
    final count = switch (weather) {
      CafeWeather.rain => 240,
      CafeWeather.snow => 180,
      _ => 55,
    };
    for (var i = 0; i < count; i++) {
      var x = region.left + random.nextDouble() * region.width;
      var z = region.top + random.nextDouble() * region.height;
      final phase = random.nextDouble() * math.pi * 2;
      if (weather == CafeWeather.autumn && i < 18) {
        x = -3.4 + (i % 6) * 1.3;
        z = -.4 - (i ~/ 6) * 2.4;
      }
      // The roof keeps the veranda dry. World anchors never follow the camera.
      if (z > 1.9 && x.abs() < 4.7) continue;
      if ((Offset(x, z) - Offset(camera.position.x, camera.position.z))
              .distance >
          13) {
        continue;
      }
      final speed = weather == CafeWeather.rain
          ? 2.4
          : weather == CafeWeather.snow
          ? .30
          : .16;
      final y = .04 + (phase * .5 - time * speed) % 4.1;
      final p = CafePoint(
        x +
            (weather == CafeWeather.rain
                ? 0
                : .24 * math.sin(time * .55 + phase)),
        y,
        z,
      );
      if (weather == CafeWeather.rain) {
        final side = camera.right * .003;
        final end = p + const CafePoint(.018, .16, 0);
        yield CafeFace(
          [p - side, p + side, end + side, end - side],
          const Color(0x7898b0b8),
          unlit: true,
          doubleSided: true,
        );
      } else if (weather == CafeWeather.snow) {
        final r = .024 + (i % 4) * .006;
        yield CafeFace(
          [
            for (var n = 0; n < 6; n++)
              p +
                  camera.right * (math.cos(n * math.pi / 3) * r) +
                  camera.up * (math.sin(n * math.pi / 3) * r),
          ],
          const Color(0xe6fffaf1),
          unlit: true,
          doubleSided: true,
        );
      } else {
        yield _seasonLeaf(p, phase + time * .6, i);
      }
    }
    if (weather == CafeWeather.rain || weather == CafeWeather.snow) {
      final sky = weather == CafeWeather.snow
          ? const Color(0xffb9c7c9)
          : const Color(0xffc6ceca);
      for (final edge in const [
        (-27.0, -26.0, 14.0, -26.0),
        (14.0, -26.0, 14.0, 16.0),
        (14.0, 16.0, -27.0, 16.0),
        (-27.0, 16.0, -27.0, -26.0),
      ]) {
        yield CafeFace(
          [
            CafePoint(edge.$1, 1.1, edge.$2),
            CafePoint(edge.$3, 1.1, edge.$4),
            CafePoint(edge.$3, 24, edge.$4),
            CafePoint(edge.$1, 24, edge.$2),
          ],
          sky,
          doubleSided: true,
          unlit: true,
        );
      }
    }
    if (weather == CafeWeather.rain) {
      // A few pond ripples; no mirror or screen-wide blur pass.
      for (var i = 0; i < 5; i++) {
        final phase = (time * .55 + i * .21) % 1;
        final center =
            CafeLayout.pond +
            CafePoint(math.sin(i * 3.1) * .55, .004, math.cos(i * 2.3) * .4);
        for (var n = 0; n < 10; n++) {
          final a = n * math.pi / 5,
              b = (n + 1) * math.pi / 5,
              r = .03 + phase * .18;
          CafePoint at(double angle, double radius) =>
              center +
              CafePoint(math.cos(angle) * radius, 0, math.sin(angle) * radius);
          yield CafeFace(
            [at(a, r), at(b, r), at(b, r + .005), at(a, r + .005)],
            Color.fromRGBO(234, 232, 213, (1 - phase) * .32),
            doubleSided: true,
            unlit: true,
          );
        }
      }
    } else if (weather == CafeWeather.autumn) {
      for (var i = 0; i < 64; i++) {
        final z = region.top + (i / 63) * region.height;
        final x = i.isEven
            ? region.left + .4 + (i % 4) * .25
            : region.right - .4 - (i % 4) * .25;
        yield _seasonLeaf(CafePoint(x, .026, z), i * 2.4, i, ground: true);
      }
    } else if (weather == CafeWeather.snow) {
      // Light snow on the wall coping and outer banks leaves every path readable.
      for (var i = 0; i < 26; i++) {
        final x = region.left + i * region.width / 26;
        if (x + .8 > -7.25 && x < -4.75) continue;
        yield CafeFace(
          [
            CafePoint(x, 1.233, walkBounds.top - .32),
            CafePoint(x + .8, 1.233, walkBounds.top - .32),
            CafePoint(x + .8, 1.233, walkBounds.top - .08),
            CafePoint(x, 1.233, walkBounds.top - .08),
          ],
          const Color(0xffeeeadd),
          doubleSided: true,
        );
      }
      for (var side in [-1.0, 1.0]) {
        final x = side < 0 ? region.left : region.right - .28;
        for (var i = 0; i < 18; i++) {
          final z = region.top + i * region.height / 18;
          yield CafeFace(
            [
              CafePoint(x, .027, z),
              CafePoint(x + .28, .027, z),
              CafePoint(x + .25, .027, z + .8),
              CafePoint(x, .027, z + .95),
            ],
            const Color(0xffeeeadd),
            doubleSided: true,
          );
        }
      }
    }
  }

  CafeFace _seasonLeaf(
    CafePoint p,
    double angle,
    int i, {
    bool ground = false,
  }) {
    final across =
        CafePoint(
          math.cos(angle),
          ground ? 0 : .25 * math.sin(angle),
          math.sin(angle),
        ) *
        .045;
    final along = ground
        ? CafePoint(-math.sin(angle) * .085, 0, math.cos(angle) * .085)
        : CafePoint(-math.sin(angle) * .055, .045, math.cos(angle) * .055);
    return CafeFace(
      [p - along, p - across, p + along, p + across],
      const [Color(0xffbd8b4e), Color(0xffa7653d), Color(0xffd0a15a)][i % 3],
      doubleSided: true,
    );
  }
}
