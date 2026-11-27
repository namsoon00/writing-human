import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/audio/cafe_soundscape.dart';
import 'package:writing_human/cafe/cafe_atmosphere.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_space.dart';
import 'package:writing_human/cafe/cafe_world.dart';
import 'package:writing_human/ui/cafe_atmosphere_sheet.dart';

class Voice implements CafeAmbientVoice {
  final events = <String>[];
  final gains = <double>[];
  Completer<void>? gate;
  bool disposed = false;
  @override
  Future<void> play(String asset, {required bool loop}) async {
    events.add(asset);
    await gate?.future;
  }

  @override
  Future<void> volume(double value) async {
    gains.add(value);
  }

  @override
  Future<void> stop() async {
    events.add('stop');
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  test('New score follows actor distance and rain is nearer at the window', () {
    const mix = CafeAtmosphere(
      melody: CafeMelody.paper,
      environment: .6,
      weather: CafeWeather.rain,
    );
    CafeSoundFrame at(CafePoint p, [double yaw = 0]) => CafeSoundFrame.at(
      mix: mix,
      camera: CafeCamera(position: p, yaw: yaw),
      courtyard: false,
      doorOpen: true,
    );
    const near = CafePoint(1.78, 1.62, -4.0);
    expect(
      at(near).musicVolume,
      greaterThan(at(const CafePoint(-3.8, 1.62, 4)).musicVolume),
    );
    expect(at(near).musicVolume, at(near, 1.4).musicVolume);
    expect(
      at(const CafePoint(-4, 1.62, 0)).environment,
      greaterThan(at(const CafePoint(3.8, 1.62, 0)).environment),
    );
  });
  test(
    'Foot contacts need walking and stop does not leave a queued rustle',
    () async {
      final voices = <Voice>[];
      final audio = createCafeSoundscape(
        (e) => fail('$e'),
        voiceFactory: () {
          final v = Voice();
          voices.add(v);
          return v;
        },
      );
      audio.update(
        const CafeSoundFrame({}, weather: CafeWeather.autumn, environment: .1),
      );
      await audio.start();
      expect(voices, isEmpty);
      audio.update(
        const CafeSoundFrame(
          {},
          weather: CafeWeather.autumn,
          environment: .1,
          step: 2,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 140));
      expect(voices.single.events, contains('cafe-season-leaf.wav'));
      audio.update(
        const CafeSoundFrame(
          {},
          weather: CafeWeather.autumn,
          environment: .1,
          step: 4,
        ),
      );
      audio.update(
        const CafeSoundFrame({}, weather: CafeWeather.autumn, environment: .1),
      );
      await Future<void>.delayed(const Duration(milliseconds: 140));
      expect(voices.single.events.where((e) => e.endsWith('.wav')).length, 1);
      await audio.dispose();
    },
  );
  test(
    'New preferences round trip; old loud mixes stay opt-in and corrupt choices fail',
    () {
      final old =
          jsonDecode(const CafeSpace().encode()) as Map<String, dynamic>;
      old['version'] = 6;
      (old['atmosphere'] as Map).removeWhere(
        (key, value) => ![
          'flow',
          'volume',
          'rain',
          'water',
          'leaves',
          'music',
        ].contains(key),
      );
      (old['atmosphere'] as Map)['music'] = 1;
      final previous = CafeSpace.decode(jsonEncode(old));
      expect(previous.atmosphere.melody, CafeMelody.none);
      expect(previous.atmosphere.environment, 0);
      final selected = previous.copy(
        atmosphere: previous.atmosphere.copy(
          weather: CafeWeather.snow,
          melody: CafeMelody.dusk,
          environment: .4,
          musicVolume: .2,
          actions: .3,
          weatherMotion: false,
        ),
      );
      final next = CafeSpace.decode(selected.encode());
      expect(next.encode(), selected.encode());
      expect(next.atmosphere.weather, CafeWeather.snow);
      expect(next.atmosphere.weatherMotion, isFalse);
      final corrupt = jsonDecode(selected.encode()) as Map<String, dynamic>;
      (corrupt['atmosphere'] as Map)['weather'] = 'unknown';
      expect(
        () => CafeSpace.decode(jsonEncode(corrupt)),
        throwsFormatException,
      );
    },
  );
  test(
    'Every season uses bounded shared yard geometry; still mode stops weather only',
    () {
      for (final weather in CafeWeather.values) {
        final world = CafeWorld(
          courtyard: true,
          space: CafeSpace(atmosphere: CafeAtmosphere(weather: weather)),
        );
        const camera = CafeCamera(position: CafePoint(0, 1.62, 0));
        final a = world.weatherFaces(camera, 0).toList(),
            b = world.weatherFaces(camera, 2).toList();
        expect(a.length, lessThan(350));
        expect(a.every((f) => f.points.every((p) => p.isFinite)), isTrue);
        expect(world.linkedWorld.weather, weather);
        if (weather == CafeWeather.clear) {
          expect(a, isEmpty);
          continue;
        }
        expect(a, isNotEmpty);
        expect(
          (a.first.points.first - b.first.points.first).length,
          greaterThan(.001),
        );
        final still = CafeWorld(
          courtyard: true,
          space: CafeSpace(
            atmosphere: CafeAtmosphere(weather: weather, weatherMotion: false),
          ),
        );
        expect(
          still.weatherFaces(camera, 0).first.points.first.x,
          still.weatherFaces(camera, 25).first.points.first.x,
        );
        expect(
          still.weatherFaces(camera, 0).first.points.first.y,
          still.weatherFaces(camera, 25).first.points.first.y,
        );
      }
    },
  );
  test(
    'Stop during a pending load cannot leave a late score playing',
    () async {
      final voice = Voice()..gate = Completer<void>();
      final audio = createCafeSoundscape(
        (e) => fail('$e'),
        voiceFactory: () => voice,
      );
      audio.update(
        const CafeSoundFrame({}, melody: CafeMelody.paper, musicVolume: .1),
      );
      final start = audio.start();
      await Future<void>.delayed(Duration.zero);
      final stopped = audio.stop();
      voice.gate!.complete();
      await start;
      await stopped;
      expect(voice.events.last, 'stop');
      expect(voice.gains, isEmpty);
      await audio.dispose();
      expect(voice.disposed, isTrue);
    },
  );
  test(
    'Removed legacy loops never open; selected scores use new assets and bounded gains',
    () async {
      final voices = <Voice>[];
      final audio = createCafeSoundscape(
        (e) => fail('$e'),
        voiceFactory: () {
          final v = Voice();
          voices.add(v);
          return v;
        },
      );
      audio.update(
        CafeSoundFrame.at(
          mix: const CafeAtmosphere(
            volume: 1,
            rain: 1,
            water: 1,
            leaves: 1,
            music: 1,
          ),
          camera: CafeCamera.entrance,
          courtyard: false,
          doorOpen: true,
        ),
      );
      await audio.start();
      expect(voices, isEmpty);
      await audio.stop();
      audio.update(
        const CafeSoundFrame({}, melody: CafeMelody.paper, musicVolume: 1),
      );
      await audio.start();
      await Future<void>.delayed(const Duration(milliseconds: 230));
      expect(voices.single.events, contains('cafe-score-paper.m4a'));
      expect(voices.single.gains.every((v) => v >= 0 && v <= .2), isTrue);
      await audio.stop();
      await audio.dispose();
      expect(voices.every((v) => v.disposed), isTrue);
    },
  );
  testWidgets('Weather and melody selections save without starting playback', (
    tester,
  ) async {
    final playing = ValueNotifier(false);
    var saved = const CafeAtmosphere(), starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CafeAtmosphereSheet(
            value: saved,
            playing: playing,
            onSave: (next) async {
              saved = next;
              return true;
            },
            onPreview: (_) {},
            onToggle: () async {
              starts++;
              playing.value = !playing.value;
              return playing.value;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('cafe-weather-autumn')));
    await tester.pumpAndSettle();
    expect(saved.weather, CafeWeather.autumn);
    expect(starts, 0);
    final melody = find.byKey(const ValueKey('cafe-melody-paper'));
    await tester.ensureVisible(melody);
    await tester.tap(melody);
    await tester.pumpAndSettle();
    expect(saved.melody, CafeMelody.paper);
    expect(starts, 0);
    final listen = find.byKey(const ValueKey('cafe-mix-listen'));
    await tester.ensureVisible(listen);
    await tester.tap(listen);
    await tester.pumpAndSettle();
    expect(starts, 1);
    await tester.pumpWidget(const SizedBox());
    playing.dispose();
  });
}
