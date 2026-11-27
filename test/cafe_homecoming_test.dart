import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_renderer.dart';
import 'package:writing_human/cafe/cafe_home.dart';
import 'package:writing_human/cafe/cafe_space.dart';
import 'package:writing_human/cafe/cafe_view_controller.dart';
import 'package:writing_human/cafe/cafe_visit.dart';
import 'package:writing_human/cafe/cafe_world.dart';
import 'package:writing_human/ui/cafe_scene.dart';
import 'package:writing_human/ui/cafe_screen.dart';

class _FailHome extends MemoryCafeSpaceStore {
  bool reject = false;
  @override
  Future<void> save(CafeSpace value) async {
    if (reject) throw StateError('injected');
    await super.save(value);
  }
}

void main() {
  test(
    'v1-v3 retain their lighting and objects; v4 validates private home preferences',
    () {
      for (final version in [1, 2, 3]) {
        final json =
            const CafeSpace(brightness: .9).withAmount('shared.cup', 1).toJson()
              ..['version'] = version
              ..remove('home');
        final room = CafeSpace.decode(jsonEncode(json));
        expect(room.home.mood, 0);
        expect(room.amount('shared.cup'), 1);
        expect(room.brightness, .9);
      }
      const home = CafeHome(
        mood: 2,
        topic: 1,
        seat: 'windowMiddle',
        chair: 'desk.windowMiddle.chair',
        pinned: '오늘은 여기까지.',
      );
      final room = CafeSpace.decode(const CafeSpace(home: home).encode());
      expect(room.home.toJson(), home.toJson());
      expect(room.resetItem('ritual.memory').home.pinned, isNull);
      for (final data in [
        home.toJson()..['mood'] = 3,
        home.toJson()..['seat'] = 'outside',
        home.toJson()..['pinned'] = 'x' * 321,
        home.toJson()..['topic'] = '1',
      ]) {
        final json = const CafeSpace().toJson()..['home'] = data;
        expect(() => CafeSpace.decode(jsonEncode(json)), throwsFormatException);
      }
      final json = const CafeSpace().toJson()..remove('home');
      expect(() => CafeSpace.decode(jsonEncode(json)), throwsFormatException);
    },
  );
  test(
    'physical paper, stand lights, rain and memory stay in the shared room without blocking layout',
    () {
      final day = CafeWorld(),
          rain = CafeWorld(space: const CafeSpace(home: CafeHome(mood: 2)));
      expect(day.validateLayout(), isNull);
      expect(day.linkedWorld.validateLayout(), isNull);
      expect(
        day.objects['ritual.windowMiddle.today']!.parent,
        'desk.windowMiddle.table',
      );
      expect(day.objects['lamp.desk.windowMiddle']!.type, CafeItemType.lamp);
      expect(
        day.faces.any(
          (f) => f.objectId == 'ritual.memory' && f.part == 'ritual.print',
        ),
        isTrue,
      );
      expect(day.weatherFaces(CafeCamera.entrance, 1), isEmpty);
      final a = rain.weatherFaces(CafeCamera.entrance, 0).toList(),
          b = rain.weatherFaces(CafeCamera.entrance, 1).toList();
      expect(a, isNotEmpty);
      expect(a.every((f) => f.points.every((p) => p.x < -4.2)), isTrue);
      expect(
        (a.first.points.first - b.first.points.first).length,
        greaterThan(0),
      );
      expect(
        rain.linkedWorld.weatherFaces(CafeCamera.gardenRest, 0).length,
        inInclusiveRange(50, 350),
      );
    },
  );
  test(
    'editorial choices are deterministic by local calendar date and never require attendance',
    () {
      final date = DateTime(2026, 11, 24);
      for (var topic = 0; topic < 3; topic++) {
        expect(
          CafeEditorial.today(date, topic).topic,
          CafeEditorial.topics[topic],
        );
        expect(
          CafeEditorial.today(date, topic).id,
          CafeEditorial.today(DateTime(2026, 11, 24, 23, 59), topic).id,
        );
      }
      expect(
        CafeEditorial.letter(date),
        CafeEditorial.letter(date.add(const Duration(days: 28))),
      );
      expect(
        CafeEditorial.today(date.add(const Duration(days: 200)), 0).text,
        isNotEmpty,
      );
    },
  );
  test(
    'travel completion resolves cancellation and reduced-motion arrival',
    () async {
      final c = CafeViewController();
      addTearDown(c.dispose);
      c.visit(CafeTarget.windowMiddle);
      final canceled = c.travelFinished;
      c.look(.01, 0);
      expect(await canceled, isFalse);
      c.visit(CafeTarget.windowMiddle);
      final done = c.travelFinished;
      c.updateCamera(c.destination!);
      c.finishTravel();
      expect(await done, isTrue);
    },
  );

  Future<CafeViewController> setup(
    WidgetTester tester, {
    MemoryCafeSpaceStore? store,
    String text = '내가 남긴 한 문장.',
    Future<bool> Function(CafeSeat, String?, CafeSentence)? onTranscribe,
  }) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      MaterialApp(
        home: CafeScreen(
          books: const [],
          currentWritingLabel: '지금 쓰던 글',
          lastSentence: text,
          moment: DateTime(2026, 11, 24),
          spaceStore: store,
          onWrite: (_, _) async => true,
          onTranscribe: onTranscribe,
          onLeave: () {},
          onRetry: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.widget<CafeScene>(find.byType(CafeScene)).controller;
  }

  Future<void> guide(WidgetTester tester, String page) async {
    await tester.tap(find.byTooltip('공간 안내'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('cafe-ritual-$page')));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a quiet arrival reaches a rainy window without creating writing and remembers a real chair',
    (tester) async {
      final store = MemoryCafeSpaceStore();
      var writes = 0;
      final c = await setup(
        tester,
        store: store,
        onTranscribe: (_, _, _) async {
          writes++;
          return true;
        },
      );
      await tester.tap(find.byKey(const ValueKey('cafe-homecoming')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cafe-return-home')));
      await tester.pumpAndSettle();
      expect(c.seat, CafeSeat.window);
      expect(store.value.home.mood, 2);
      expect(writes, 0);
      await guide(tester, 'arrival');
      await tester.tap(find.byKey(const ValueKey('cafe-remember-seat')));
      await tester.pumpAndSettle();
      expect(store.value.home.seat, 'window');
      expect(store.value.home.chair, 'desk.window.chair');
      await close(tester);
      final reopened = await setup(tester, store: store);
      await tester.tap(find.byKey(const ValueKey('cafe-homecoming')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cafe-return-home')));
      await tester.pumpAndSettle();
      expect(reopened.seat, CafeSeat.window);
      expect(reopened.activeChairId, 'desk.window.chair');
      await close(tester);
    },
  );
  testWidgets(
    'a failed pin remains a visible draft, retries and never changes the manuscript',
    (tester) async {
      final store = _FailHome();
      final c = await setup(tester, store: store);
      await guide(tester, 'memory');
      store.reject = true;
      await tester.tap(find.byKey(const ValueKey('cafe-pin-sentence')));
      await tester.pumpAndSettle();
      expect(c.space.home.pinned, '내가 남긴 한 문장.');
      expect(store.value.home.pinned, isNull);
      expect(find.text('다시 저장'), findsWidgets);
      store.reject = false;
      await tester.tap(find.byKey(const ValueKey('cafe-ritual-retry')));
      await tester.pumpAndSettle();
      expect(store.value.home.pinned, '내가 남긴 한 문장.');
      await tester.tap(find.byKey(const ValueKey('cafe-unpin-sentence')));
      await tester.pumpAndSettle();
      expect(store.value.home.pinned, isNull);
      await close(tester);
    },
  );
  testWidgets(
    'today card changes topic and passes the exact text after sitting',
    (tester) async {
      CafeSentence? selected;
      CafeSeat? seat;
      await setup(
        tester,
        onTranscribe: (s, _, line) async {
          selected = line;
          seat = s;
          return true;
        },
      );
      await guide(tester, 'today');
      await tester.tap(find.widgetWithText(ChoiceChip, '다시 시작하는 날'));
      await tester.pumpAndSettle();
      final expected = CafeEditorial.today(DateTime(2026, 11, 24), 1);
      expect(find.text(expected.text), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cafe-transcribe-sentence')));
      await tester.pumpAndSettle();
      expect(selected!.text, expected.text);
      expect(seat, CafeSeat.window);
      await close(tester);
    },
  );
  testWidgets(
    'weekly letter reads without generating a manuscript or changing the room',
    (tester) async {
      final store = MemoryCafeSpaceStore();
      await setup(tester, store: store);
      final before = store.value.encode();
      await guide(tester, 'letter');
      expect(find.byKey(const ValueKey('cafe-weekly-letter')), findsOneWidget);
      expect(store.value.encode(), before);
      await close(tester);
    },
  );
  testWidgets(
    'card atlas replacements keep current images alive and dispose old images after painting',
    (tester) async {
      final c = await setup(tester);
      CafeRenderer painter() =>
          tester
                  .widget<CustomPaint>(
                    find.byWidgetPredicate(
                      (w) => w is CustomPaint && w.painter is CafeRenderer,
                    ),
                  )
                  .painter
              as CafeRenderer;
      Future<void> waitForAtlas(Object? previous) async {
        for (
          var i = 0;
          i < 60 &&
              (painter().letterAtlas == null ||
                  painter().letterAtlas == previous);
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)),
          );
          await tester.pump();
        }
        expect(painter().letterAtlas, isNotNull);
      }

      await waitForAtlas(null);
      for (var i = 0; i < 3; i++) {
        final old = painter().letterAtlas!;
        c.applySpace(
          c.space.copy(
            home: c.space.home.copy(topic: (i + 1) % 3, pinned: '내 문장 $i'),
          ),
        );
        await tester.pump();
        await waitForAtlas(old);
        await tester.pump();
        expect(old.debugDisposed, isTrue);
        expect(painter().letterAtlas!.debugDisposed, isFalse);
        c.look(.01, 0);
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      await close(tester);
    },
  );
}
