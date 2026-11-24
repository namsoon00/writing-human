import 'dart:math' as math;
import 'cafe_camera.dart';

enum CafeSound { rain, water, leaves, music }

/// Preferences only. Playing/muted state and animation progress are not saved.
class CafeAtmosphere {
  const CafeAtmosphere({
    this.flow = true,
    this.volume = .20,
    this.rain = .35,
    this.water = .15,
    this.leaves = 0,
    this.music = 0,
  });
  final bool flow;
  final double volume, rain, water, leaves, music;
  double get actionVolume => .20 * volume;
  double level(CafeSound sound) => switch (sound) {
    CafeSound.rain => rain,
    CafeSound.water => water,
    CafeSound.leaves => leaves,
    CafeSound.music => music,
  };
  CafeAtmosphere copy({
    bool? flow,
    double? volume,
    CafeSound? sound,
    double? level,
  }) => CafeAtmosphere(
    flow: flow ?? this.flow,
    volume: volume ?? this.volume,
    rain: sound == CafeSound.rain ? level! : rain,
    water: sound == CafeSound.water ? level! : water,
    leaves: sound == CafeSound.leaves ? level! : leaves,
    music: sound == CafeSound.music ? level! : music,
  );
  Map<String, dynamic> toJson() => {
    'flow': flow,
    'volume': volume,
    for (final sound in CafeSound.values) sound.name: level(sound),
  };
  factory CafeAtmosphere.read(dynamic value, {bool legacy = false}) {
    if (value is! Map<String, dynamic> || value['flow'] is! bool) {
      throw const FormatException('Invalid cafe atmosphere');
    }
    double number(String key) {
      final n = value[key];
      if (n is! num || !n.isFinite || n < 0 || n > 1) {
        throw const FormatException('Invalid cafe sound mix');
      }
      return n.toDouble();
    }

    return CafeAtmosphere(
      flow: value['flow'],
      volume: legacy ? .20 : number('volume'),
      rain: number('rain'),
      water: number('water'),
      leaves: number('leaves'),
      music: number('music'),
    );
  }
}

/// A slow twelve-minute light passage inside the user's chosen mood.
class CafeLightFrame {
  CafeLightFrame({
    required double seconds,
    required bool flow,
    required this.mood,
  }) : seconds = flow && seconds.isFinite ? math.max(0, seconds) : 0,
       assert(mood >= 0 && mood <= 2);
  final double seconds;
  final int mood;
  double get dusk => (1 - math.cos(seconds * math.pi * 2 / 720)) / 2;
  CafePoint get indoor =>
      CafePoint(1 - dusk * .18, 1 - dusk * .24, 1 - dusk * .29);
  CafePoint get outdoor =>
      CafePoint(1 - dusk * .32, 1 - dusk * .30, 1 - dusk * .18);
  double get lamps => 1 + dusk * (mood == 0 ? .18 : .08);

  // Small world-anchored leaf silhouettes on horizontal window surfaces.
  // The same pattern covers paper and timber; it is not a screen overlay.
  double shadow(CafePoint p, CafePoint normal, double breeze) {
    if (mood == 2 ||
        normal.y < .8 ||
        p.x > -1.8 ||
        p.x < -4.4 ||
        !(p.y < .025 || (p.y > .70 && p.y < .85))) {
      return 1;
    }
    final x = p.x + 3.65 - dusk * .35 - .055 * math.sin(breeze * .45);
    final z = (p.z + .04 * math.sin(breeze * .3)) % 1.15;
    var shade = 0.0;
    for (final leaf in const [
      (-.10, .16),
      (-.25, .55),
      (.12, .85),
      (.35, .38),
      (.58, .68),
      (.92, .91),
    ]) {
      final dx = x - leaf.$1, dz = z - leaf.$2;
      final a = (dx * .86 + dz * .5) / .24;
      final b = (-dx * .5 + dz * .86) / .11;
      shade = math.max(shade, (1 - (a * a + b * b)).clamp(0, 1));
    }
    return 1 - shade * (mood == 0 ? .30 : .09) * (1 - dusk * .6);
  }
}

class CafeSoundLevel {
  const CafeSoundLevel(this.volume, this.pan, this.cutoff);
  final double volume, pan, cutoff;
}

class CafeSoundFrame {
  const CafeSoundFrame(this.levels);
  final Map<CafeSound, CafeSoundLevel> levels;
  factory CafeSoundFrame.at({
    required CafeAtmosphere mix,
    required CafeCamera camera,
    required bool courtyard,
    required bool doorOpen,
  }) {
    // Convert both rooms into the cafe's continuous world coordinates.
    final p = courtyard
        ? CafePoint(
            camera.position.z - 7.4,
            camera.position.y,
            -camera.position.x,
          )
        : camera.position;
    final right = courtyard
        ? CafePoint(camera.right.z, 0, -camera.right.x)
        : camera.right;
    final door = (p - const CafePoint(-4.2, 1.3, -2.65)).length;
    final transmission = courtyard
        ? 1.0
        : doorOpen
        ? .20 + .60 / (1 + door * .65)
        : .08;
    final source = {
      CafeSound.rain: const CafePoint(-4.45, 1.3, .2),
      CafeSound.water: const CafePoint(-7.4, .2, 0),
      CafeSound.leaves: const CafePoint(-6.7, 2.2, -1.5),
      CafeSound.music: const CafePoint(2.8, 1.5, -3.7),
    };
    final values = <CafeSound, CafeSoundLevel>{};
    for (final sound in CafeSound.values) {
      final delta = source[sound]! - p;
      final outside = sound != CafeSound.music;
      final distance = math.sqrt(delta.x * delta.x + delta.z * delta.z);
      final spatial = sound == CafeSound.rain
          ? (courtyard ? .85 : .24 + .65 / (1 + (p.x + 4.4).abs() * .7))
          : outside
          ? transmission
          : courtyard
          ? (doorOpen ? .18 : .035)
          : 1.0;
      // Water and rustle recordings have higher signal levels than the rain.
      final trim = switch (sound) {
        CafeSound.rain => 1.0,
        CafeSound.water => .40,
        CafeSound.leaves || CafeSound.music => .50,
      };
      final gain =
          .48 *
          mix.volume *
          trim *
          mix.level(sound) *
          spatial /
          (1 + distance * .12);
      values[sound] = CafeSoundLevel(
        gain.clamp(0, .48),
        (delta.normalized.dot(right) * .72).clamp(-.72, .72),
        outside != courtyard ? (doorOpen ? 3600 : 1000) : 14000,
      );
    }
    return CafeSoundFrame(Map.unmodifiable(values));
  }
}
