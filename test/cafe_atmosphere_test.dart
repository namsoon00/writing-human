import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:writing_human/audio/cafe_soundscape.dart';
import 'package:writing_human/cafe/cafe_atmosphere.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_home.dart';
import 'package:writing_human/cafe/cafe_renderer.dart';
import 'package:writing_human/cafe/cafe_space.dart';
import 'package:writing_human/cafe/cafe_view_controller.dart';
import 'package:writing_human/cafe/cafe_visit.dart';
import 'package:writing_human/cafe/cafe_world.dart';
import 'package:writing_human/ui/cafe_scene.dart';
import 'package:writing_human/ui/cafe_screen.dart';

class _Audio implements CafeSoundOutput {
  int starts = 0, stops = 0;
  bool disposed = false;
  bool reject = false;
  Completer<void>? gate;
  final frames = <CafeSoundFrame>[];
  @override
  Future<void> start() async {
    starts++;
    if (reject) throw StateError('injected audio failure');
    await gate?.future;
  }

  @override
  void update(CafeSoundFrame frame) => frames.add(frame);
  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class _Store extends MemoryCafeSpaceStore {
  bool reject = false;
  @override
  Future<void> save(CafeSpace value) async {
    if (reject) throw StateError('injected');
    await super.save(value);
  }
}

void main() {
  test('Master volume scales all layers and actions, including old mixes', () {
    const mix = CafeAtmosphere(rain: .55, water: .40, leaves: .30, music: .18);
    CafeSoundFrame frame(CafeAtmosphere value) => CafeSoundFrame.at(
      mix: value,
      camera: const CafeCamera(position: CafePoint(0, 1.62, 0)),
      courtyard: true,
      doorOpen: true,
    );
    final full = frame(mix.copy(volume: 1));
    final quiet = frame(mix);
    final silent = frame(mix.copy(volume: 0));
    for (final sound in CafeSound.values) {
      expect(
        quiet.levels[sound]!.volume,
        closeTo(full.levels[sound]!.volume * .20, 1e-10),
      );
      expect(silent.levels[sound]!.volume, 0);
    }
    expect(mix.copy(volume: 0).actionVolume, 0);
    expect(mix.actionVolume, closeTo(.04, 1e-10));
    const defaults = CafeAtmosphere();
    expect(defaults.rain, 0);
    expect(defaults.water, 0);
    expect(defaults.leaves, 0);
    expect(defaults.music, 0);
    // Worst-case sum of gains, even with every source next to the listener.
    expect(
      .48 * defaults.volume * (defaults.rain + .4 * defaults.water),
      lessThan(.04),
    );
  });

  testWidgets(
    'Removed ambient assets cannot replay even with an old maximum mix',
    (tester) async {
      await tester.runAsync(() async {
        final action = await rootBundle.load('assets/audio/cafe-touch.wav');
        expect(action.lengthInBytes, greaterThan(44));
        for (final name in ['rain', 'water', 'leaves', 'music']) {
          await expectLater(
            () => rootBundle.load('assets/audio/cafe-$name.wav'),
            throwsA(isA<FlutterError>()),
          );
        }
        final errors = <Object>[];
        final output = createCafeSoundscape(errors.add);
        final frame = CafeSoundFrame.at(
          mix: const CafeAtmosphere(
            volume: 1,
            rain: 1,
            water: 1,
            leaves: 1,
            music: 1,
          ),
          camera: const CafeCamera(position: CafePoint(-7.4, 1.62, 0)),
          courtyard: true,
          doorOpen: true,
        );
        for (var visit = 0; visit < 2; visit++) {
          output.update(frame);
          await output.start();
          await output.stop();
        }
        await output.dispose();
        expect(errors, isEmpty);
      });
    },
  );

  testWidgets('Leaf shadows remain visible and move under a bright desk lamp', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final world = CafeWorld();
      world.faces.clear();
      world.linkedWorld.faces.clear();
      world.pendantLights.add(const CafePoint(-3.75, 1.1, .16));
      world.pendantGains.add(2);
      world.faces.add(
        CafeFace(const [
          CafePoint(-3.77, .75, .18),
          CafePoint(-3.73, .75, .18),
          CafePoint(-3.73, .75, .14),
          CafePoint(-3.77, .75, .14),
        ], Colors.white),
      );
      const camera = CafeCamera(
        position: CafePoint(-3.75, 1.6, .16),
        pitch: -math.pi / 2,
      );
      final red = <int>[];
      for (final time in [0.0, math.pi / .9]) {
        final recorder = ui.PictureRecorder();
        CafeRenderer(
          world: world,
          camera: camera,
          time: time,
          allowPortal: false,
        ).paint(ui.Canvas(recorder), const Size(240, 400));
        final picture = recorder.endRecording();
        final image = await picture.toImage(240, 400);
        try {
          final pixels = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          red.add(pixels[(200 * 240 + 120) * 4]);
        } finally {
          image.dispose();
          picture.dispose();
        }
      }
      expect(red.first, lessThan(235));
      expect((red.first - red.last).abs(), greaterThan(4));
    });
  });

  test(
    'v1-v4 preserve private room settings; v5 migrates quietly; v6 strictly validates the mix',
    () {
      const old = CafeSpace(
        home: CafeHome(mood: 1, pinned: '남겨 둔 문장'),
        amounts: {'shared.cup': 1},
        poses: {'shared.pen': CafePose(x: .02)},
      );
      for (final version in [1, 2, 3, 4]) {
        final json = old.toJson()
          ..['version'] = version
          ..remove('atmosphere');
        final migrated = CafeSpace.decode(jsonEncode(json));
        expect(migrated.amount('shared.cup'), 1);
        expect(migrated.pose('shared.pen').x, .02);
        expect(migrated.atmosphere.music, 0);
        expect(migrated.atmosphere.volume, .20);
        if (version == 4) expect(migrated.home.pinned, old.home.pinned);
      }
      const mix = CafeAtmosphere(
        flow: false,
        rain: 0,
        water: .9,
        leaves: .1,
        music: .3,
      );
      expect(
        CafeSpace.decode(
          old.copy(atmosphere: mix).encode(),
        ).atmosphere.toJson(),
        mix.toJson(),
      );
      final legacy = old.copy(atmosphere: mix).toJson()..['version'] = 5;
      (legacy['atmosphere'] as Map).remove('volume');
      final restored = CafeSpace.decode(jsonEncode(legacy));
      expect(restored.atmosphere.volume, .20);
      expect(restored.atmosphere.water, .9);
      expect(restored.atmosphere.music, .3);
      expect(restored.home.pinned, old.home.pinned);
      expect(restored.pose('shared.pen').x, .02);
      for (final bad in [
        mix.toJson()..remove('water'),
        mix.toJson()..remove('volume'),
        mix.toJson()..['volume'] = -0.1,
        mix.toJson()..['volume'] = 1.1,
        mix.toJson()..['music'] = 1.1,
        mix.toJson()..['rain'] = '0.5',
        mix.toJson()..['flow'] = 1,
      ]) {
        expect(
          () =>
              CafeSpace.decode(jsonEncode(old.toJson()..['atmosphere'] = bad)),
          throwsFormatException,
        );
      }
      expect(
        () => CafeSpace.decode(jsonEncode(old.toJson()..remove('atmosphere'))),
        throwsFormatException,
      );
      expect(
        () => CafeAtmosphere.read(mix.toJson()..['water'] = double.nan),
        throwsFormatException,
      );
    },
  );

  test(
    'Distance, door and listener direction alter the same continuous sound field',
    () {
      CafeSoundFrame at(
        CafeCamera camera, {
        bool garden = false,
        bool open = true,
      }) => CafeSoundFrame.at(
        mix: const CafeAtmosphere(rain: .35, water: .15),
        camera: camera,
        courtyard: garden,
        doorOpen: open,
      );
      const window = CafeCamera(position: CafePoint(-3, 1.18, .1), yaw: 0);
      final near = at(window),
          far = at(const CafeCamera(position: CafePoint(3, 1.62, .1)));
      expect(
        near.levels[CafeSound.rain]!.volume,
        greaterThan(far.levels[CafeSound.rain]!.volume),
      );
      expect(
        at(window, open: false).levels[CafeSound.water]!.volume,
        lessThan(near.levels[CafeSound.water]!.volume),
      );
      final turned = at(CafeCamera(position: window.position, yaw: math.pi));
      expect(
        turned.levels[CafeSound.rain]!.pan,
        closeTo(-near.levels[CafeSound.rain]!.pan, 1e-9),
      );
      // The two coordinate systems map to exactly the same listener location.
      const gardenCamera = CafeCamera(position: CafePoint(1, 1.62, 0), yaw: .3);
      final transformed = CafeCamera(
        position: const CafePoint(-7.4, 1.62, -1),
        yaw: .3 - math.pi / 2,
      );
      final a = at(gardenCamera, garden: true);
      final delta = a.levels[CafeSound.water]!;
      expect(delta.volume, greaterThan(near.levels[CafeSound.water]!.volume));
      expect(delta.pan.isFinite, isTrue);
      final sameListener = at(transformed);
      for (final sound in CafeSound.values) {
        expect(
          a.levels[sound]!.pan,
          closeTo(sameListener.levels[sound]!.pan, 1e-9),
        );
      }
      final silent = CafeSoundFrame.at(
        mix: const CafeAtmosphere(rain: 0, water: 0, leaves: 0, music: 0),
        camera: window,
        courtyard: false,
        doorOpen: true,
      );
      expect(
        silent.levels.values.every((l) => l.volume == 0 && l.pan.abs() <= .72),
        isTrue,
      );
    },
  );

  test(
    'Light passage stays readable, returns smoothly and preserves the chosen mood',
    () {
      final start = CafeLightFrame(seconds: 0, flow: true, mood: 0);
      final dusk = CafeLightFrame(seconds: 360, flow: true, mood: 0);
      final cycle = CafeLightFrame(seconds: 720, flow: true, mood: 0);
      expect(start.indoor.x, 1);
      expect(cycle.indoor.x, closeTo(1, 1e-10));
      expect(dusk.indoor.z, greaterThan(.65));
      expect(dusk.lamps, greaterThan(start.lamps));
      expect(CafeLightFrame(seconds: 360, flow: false, mood: 0).indoor.x, 1);
      expect(
        dusk.shadow(const CafePoint(0, .75, 0), const CafePoint(0, 1, 0), 5),
        1,
      );
      expect(
        CafeLightFrame(
          seconds: 20,
          flow: true,
          mood: 2,
        ).shadow(const CafePoint(-3.75, .75, .16), const CafePoint(0, 1, 0), 5),
        1,
      );
      expect(
        start.shadow(
          const CafePoint(-3.75, .75, .16),
          const CafePoint(0, 1, 0),
          0,
        ),
        lessThan(1),
      );
    },
  );

  Future<CafeViewController> open(
    WidgetTester tester,
    _Audio audio,
    _Store store,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: CafeScreen(
          books: const [],
          currentWritingLabel: '지금 펼친 쪽',
          soundscape: audio,
          spaceStore: store,
          onWrite: (_, _) async => true,
          onLeave: () {},
          onRetry: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.widget<CafeScene>(find.byType(CafeScene)).controller;
  }

  Future<void> mixer(WidgetTester tester) async {
    await tester.tap(find.byTooltip('공간 안내'));
    await tester.pumpAndSettle();
    final entry = find.byKey(const ValueKey('cafe-ritual-ambience'));
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
  }

  Future<void> end(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Sound stays opt-in, continues across the door and stops on background/close',
    (tester) async {
      final audio = _Audio(), store = _Store();
      final c = await open(tester, audio, store);
      expect(audio.starts, 0);
      await tester.tap(find.byTooltip('소리 켜기'));
      await tester.pumpAndSettle();
      expect(audio.starts, 1);
      expect(audio.frames, isNotEmpty);
      c.visit(CafeTarget.courtyard);
      await tester.pumpAndSettle();
      expect(c.inCourtyard, isTrue);
      expect(audio.starts, 1);
      expect(audio.stops, 0);
      expect(find.byTooltip('소리 끄기'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(audio.stops, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(audio.starts, 1);
      expect(find.byTooltip('소리 켜기'), findsOneWidget);
      await end(tester);
      expect(audio.disposed, isTrue);
    },
  );

  testWidgets(
    'Master volume previews silently and survives a failed save retry',
    (tester) async {
      final audio = _Audio(), store = _Store();
      await open(tester, audio, store);
      await mixer(tester);
      final finder = find.byKey(const ValueKey('cafe-master-volume'));
      await tester.ensureVisible(finder);
      final slider = tester.widget<Slider>(finder);
      slider.onChanged!(.07);
      await tester.pump();
      expect(audio.starts, 0);
      store.reject = true;
      slider.onChangeEnd!(.07);
      await tester.pumpAndSettle();
      expect(store.value.atmosphere.volume, .20);
      expect(tester.widget<Slider>(finder).value, .07);
      store.reject = false;
      await tester.tap(find.byKey(const ValueKey('cafe-atmosphere-retry')));
      await tester.pumpAndSettle();
      expect(store.value.atmosphere.volume, .07);
      expect(audio.starts, 0);
      await end(tester);
    },
  );

  testWidgets(
    'Mix save failure keeps the draft, retries and never silently enables audio',
    (tester) async {
      final audio = _Audio(), store = _Store();
      await open(tester, audio, store);
      await mixer(tester);
      store.reject = true;
      final flow = find.byKey(const ValueKey('cafe-light-flow'));
      await tester.tap(flow);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('cafe-atmosphere-retry')),
        findsOneWidget,
      );
      expect(store.value.atmosphere.flow, isTrue);
      expect(audio.starts, 0);
      store.reject = false;
      await tester.tap(find.byKey(const ValueKey('cafe-atmosphere-retry')));
      await tester.pumpAndSettle();
      expect(store.value.atmosphere.flow, isFalse);
      expect(find.byKey(const ValueKey('cafe-mix-water')), findsNothing);
      expect(find.byKey(const ValueKey('cafe-mix-rain')), findsNothing);
      expect(find.text('고요한 공간'), findsOneWidget);
      expect(audio.starts, 0);
      await end(tester);
    },
  );

  testWidgets(
    'Pending activation cannot turn sound back on after app backgrounding',
    (tester) async {
      final audio = _Audio()..gate = Completer<void>();
      await open(tester, audio, _Store());
      await tester.tap(find.byTooltip('소리 켜기'));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      audio.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byTooltip('소리 켜기'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(audio.starts, 1);
      await end(tester);
    },
  );

  testWidgets(
    'Audio failure is visible in the mixer and a later tap can retry',
    (tester) async {
      final audio = _Audio()..reject = true;
      await open(tester, audio, _Store());
      await mixer(tester);
      final listen = find.byKey(const ValueKey('cafe-mix-listen'));
      await tester.ensureVisible(listen);
      await tester.tap(listen);
      await tester.pumpAndSettle();
      expect(find.text('소리를 재생하지 못했어요. 다시 켜 주세요.'), findsOneWidget);
      expect(find.text('동작음 켜기'), findsOneWidget);
      audio.reject = false;
      await tester.tap(listen);
      await tester.pumpAndSettle();
      expect(find.text('동작음 끄기'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('동작음 켜기'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await end(tester);
    },
  );

  testWidgets(
    'Light clock pauses offscreen/background and honors reduced motion',
    (tester) async {
      final c = CafeViewController();
      final visible = ValueNotifier(true);
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (_, value, _) => TickerMode(
              enabled: value,
              child: CafeScene(controller: c),
            ),
          ),
        ),
      );
      CafeRenderer painter() =>
          tester
                  .widgetList<CustomPaint>(find.byType(CustomPaint))
                  .firstWhere((w) => w.painter is CafeRenderer)
                  .painter!
              as CafeRenderer;
      await tester.pump(const Duration(seconds: 8));
      expect(painter().lightTime, 8);
      visible.value = false;
      await tester.pump();
      await tester.pump(const Duration(seconds: 8));
      expect(painter().lightTime, 8);
      visible.value = true;
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      await tester.pump(const Duration(seconds: 8));
      expect(painter().lightTime, 8);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      await tester.pump();
      await tester.pump(const Duration(seconds: 8));
      expect(painter().lightTime, 8);
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await end(tester);
      visible.dispose();
      c.dispose();
    },
  );
}
