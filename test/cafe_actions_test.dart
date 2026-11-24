import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_renderer.dart';
import 'package:writing_human/cafe/cafe_space.dart';
import 'package:writing_human/cafe/cafe_view_controller.dart';
import 'package:writing_human/cafe/cafe_world.dart';
import 'package:writing_human/cafe/cafe_visit.dart';
import 'package:writing_human/ui/cafe_scene.dart';
import 'package:writing_human/ui/cafe_screen.dart';

class _RejectStore extends MemoryCafeSpaceStore {
  bool reject = false;
  @override
  Future<void> save(CafeSpace value) async {
    if (reject) throw StateError('injected action save failure');
    await super.save(value);
  }
}

void main() {
  test(
    'v1 and v2 migrate without refilling an empty legacy cup; v3 is strict',
    () {
      for (final version in [1, 2]) {
        final old = const CafeSpace(cupFull: false).toJson()
          ..['version'] = version;
        old.remove('amounts');
        old.remove('uses');
        final read = CafeSpace.decode(jsonEncode(old));
        expect(read.amount('shared.cup'), 0);
        expect(read.amount('garden.cup'), 0);
        expect(read.withAmount('shared.cup', 1).amount('shared.cup'), 1);
      }
      expect(
        const CafeSpace(
          cupFull: false,
          states: {'shared.cup': true},
        ).amount('shared.cup'),
        3,
      );
      final original = const CafeSpace()
          .withAmount('shared.cup', 2)
          .withUse('plant.3.77_-3.9', true);
      expect(CafeSpace.decode(original.encode()).encode(), original.encode());
      expect(original.withState('shared.cup', false).amount('shared.cup'), 0);
      expect(original.withState('shared.cup', true).amount('shared.cup'), 3);
      expect(original.resetItem('shared.cup').amounts, isEmpty);
      for (final value in [-1, 4, 1.1, '2', null]) {
        final broken = original.toJson()..['amounts'] = {'shared.cup': value};
        expect(
          () => CafeSpace.decode(jsonEncode(broken)),
          throwsFormatException,
        );
      }
      final broken = original.toJson()..remove('uses');
      expect(() => CafeSpace.decode(jsonEncode(broken)), throwsFormatException);
    },
  );

  test(
    'hold locks walking; cancellation and disposal return items without changing saved data',
    () async {
      final c = CafeViewController();
      final original = c.space.encode();
      final pending = c.performUse('shared.cup', CafeUseKind.pickUp);
      c.advanceUse(.5);
      expect(c.walkTo(const CafePoint(1, 1.62, 2)), isFalse);
      c.cancelUse();
      expect(await pending, isFalse);
      expect(c.heldId, isNull);
      expect(c.useFrame, isNull);
      expect(c.space.encode(), original);
      final picked = c.performUse('shared.cup', CafeUseKind.pickUp);
      c.finishUse();
      expect(await picked, isTrue);
      expect(c.heldId, 'shared.cup');
      expect(c.freeStep(.1, 0, .1), isFalse);
      final sip = c.performUse('shared.cup', CafeUseKind.sip);
      c.dispose();
      expect(await sip, isFalse);
    },
  );

  test(
    'cup mesh moves rigidly, saucer stays, and lifted mesh is the picking surface',
    () {
      final world = CafeWorld();
      final pivot = world.objects['shared.cup']!.pivot;
      final camera = CafeCamera(
        position: pivot + const CafePoint(0, .65, .7),
        pitch: -.5,
      );
      final original = world.faces
          .where((f) => f.objectId == 'shared.cup')
          .toList();
      final presented = world
          .presentedFaces(
            camera,
            const CafeUseFrame('shared.cup', CafeUseKind.hold, held: true),
          )
          .where((f) => f.objectId == 'shared.cup')
          .toList();
      final saucer = original.where((f) => f.part == null).toList();
      expect(saucer, isNotEmpty);
      expect(
        presented.where((f) => f.part == null).toList(),
        orderedEquals(saucer),
      );
      final old = original.firstWhere((f) => f.part == 'vessel');
      final moved = presented.firstWhere((f) => f.part == 'vessel');
      expect(
        (old.points[0] - old.points[1]).length,
        closeTo((moved.points[0] - moved.points[1]).length, 1e-9),
      );
      expect((moved.center - old.center).length, greaterThan(.15));
      final center =
          camera.position +
          camera.forward * .48 +
          camera.right * .13 +
          camera.up * (-.05) +
          camera.up * .055;
      const size = Size(390, 844);
      final point = CafeRenderer.project(center, camera, size)!;
      expect(
        CafeRenderer.pick(
          point,
          camera,
          size,
          world,
          use: const CafeUseFrame('shared.cup', CafeUseKind.hold, held: true),
        )?.objectId,
        'shared.cup',
      );
      final sip = world
          .presentedFaces(
            camera,
            const CafeUseFrame(
              'shared.cup',
              CafeUseKind.sip,
              held: true,
              progress: .5,
            ),
          )
          .firstWhere((f) => f.objectId == 'shared.cup' && f.part == 'vessel');
      expect(
        (sip.center - camera.position).length,
        lessThan((moved.center - camera.position).length),
      );
      expect(
        world.faces.where((f) => f.objectId == 'shared.cup').toList(),
        orderedEquals(original),
      );
    },
  );

  test(
    'real page mesh folds around the spine and shelf volumes open without mutating the room',
    () {
      final world = CafeWorld();
      final length = world.faces.length;
      const camera = CafeCamera.entrance;
      final frames = [0.0, .25, .5, .75, 1.0]
          .map(
            (p) => world
                .presentedFaces(
                  camera,
                  CafeUseFrame('shared.book', CafeUseKind.close, progress: p),
                )
                .where((f) => f.objectId == 'shared.book')
                .toList(),
          )
          .toList();
      for (final frame in frames) {
        expect(frame, isNotEmpty);
        expect(frame.every((f) => f.points.every((p) => p.isFinite)), isTrue);
      }
      final base = world.objects['shared.book']!.pivot;
      expect(
        frames[2]
            .expand((f) => f.points)
            .map((p) => p.y)
            .reduce((a, b) => a > b ? a : b),
        greaterThan(base.y + .18),
      );
      final id = world.objects.values
          .firstWhere((o) => o.type == CafeItemType.volume)
          .id;
      final open = world
          .presentedFaces(
            camera,
            CafeUseFrame(id, CafeUseKind.open, held: true, progress: 1),
          )
          .where((f) => f.objectId == id)
          .toList();
      expect(open.any((f) => f.surface == CafeSurface.artwork), isTrue);
      expect(world.faces.length, length);
    },
  );

  test('looking from a selected chair preserves its exact seated position', () {
    final c = CafeViewController();
    addTearDown(c.dispose);
    expect(c.visitChair('shared.chair.right.1'), isTrue);
    c.updateCamera(c.destination!);
    c.finishTravel();
    final point = c.camera.position;
    c.look(.12, .02);
    expect(c.activeChairId, 'shared.chair.right.1');
    c.applySpace(c.space.withAmount('shared.cup', 2));
    expect((c.camera.position - point).length, lessThan(1e-9));
  });

  Future<CafeViewController> room(
    WidgetTester tester, {
    CafeSpaceStore? store,
    Future<bool> Function(CafeSeat, String?)? write,
    bool reduced = true,
  }) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: reduced);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      MaterialApp(
        home: CafeScreen(
          books: const [],
          currentWritingLabel: 'test',
          spaceStore: store,
          onWrite: write ?? (_, _) async => true,
          onLeave: () {},
          onRetry: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.widget<CafeScene>(find.byType(CafeScene)).controller;
  }

  Future<void> use(WidgetTester tester, String id) async {
    final scene = tester.widget<CafeScene>(find.byType(CafeScene));
    final c = scene.controller;
    if (c.heldId == null) {
      c.updateCamera(
        CafeCamera(
          position: c.world.objects[id]!.pivot + const CafePoint(0, .6, .7),
          pitch: -.5,
        ),
      );
    }
    await tester.pumpAndSettle();
    expect(scene.onItemActivated!(id), isTrue);
    await tester.pumpAndSettle();
  }

  Future<void> end(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'sip save failure retains visible draft and retry commits only that amount',
    (tester) async {
      final store = _RejectStore();
      final c = await room(tester, store: store);
      await use(tester, 'shared.cup');
      store.reject = true;
      c.look(.1, .03);
      final yaw = c.camera.yaw;
      await tester.tap(find.byKey(const ValueKey('cafe-use-sip')));
      await tester.pumpAndSettle();
      expect(c.camera.yaw, yaw);
      expect(c.space.amount('shared.cup'), 2);
      expect(store.value.amount('shared.cup'), 3);
      expect(find.byKey(const ValueKey('room-error')), findsOneWidget);
      store.reject = false;
      await tester.tap(find.text('다시 저장'));
      await tester.pumpAndSettle();
      expect(store.value.amount('shared.cup'), 2);
      await tester.tap(find.byKey(const ValueKey('cafe-use-put-down')));
      await tester.pumpAndSettle();
      expect(c.heldId, isNull);
      expect(c.space.poses, isEmpty);
      await end(tester);
    },
  );

  testWidgets(
    'backgrounding during sip cancels consumption and shows cup at its original support',
    (tester) async {
      final store = MemoryCafeSpaceStore();
      final c = await room(tester, store: store);
      await use(tester, 'shared.cup');
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: false);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('cafe-use-sip')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(c.using, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(c.heldId, isNull);
      expect(c.using, isFalse);
      expect(store.value.amount('shared.cup'), 3);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await end(tester);
    },
  );

  testWidgets(
    'plant care, lamp and vase actions persist separately; held pencil opens existing writer',
    (tester) async {
      final store = MemoryCafeSpaceStore();
      var writes = 0;
      final c = await room(
        tester,
        store: store,
        write: (_, _) async {
          writes++;
          return true;
        },
      );
      final plant = c.world.objects.values
          .firstWhere((o) => o.id.startsWith('plant.'))
          .id;
      await use(tester, plant);
      await tester.tap(find.byKey(const ValueKey('cafe-use-water')));
      await tester.pumpAndSettle();
      expect(store.value.uses[plant], isTrue);
      final lamp = c.world.objects.values
          .firstWhere((o) => o.type == CafeItemType.lamp)
          .id;
      await use(tester, lamp);
      expect(store.value.state(lamp), isFalse);
      await tester.tap(find.byKey(const ValueKey('cafe-use-brightness')));
      await tester.pumpAndSettle();
      expect(store.value.state(lamp), isTrue);
      expect(store.value.light(lamp), .5);
      await use(tester, 'shared.vase');
      expect(store.value.accent('shared.vase'), 1);
      c.visit(CafeTarget.shared);
      await tester.pumpAndSettle();
      expect(c.seat, CafeSeat.shared);
      final scene = tester.widget<CafeScene>(find.byType(CafeScene));
      scene.onItemActivated!('shared.pen');
      await tester.pumpAndSettle();
      expect(c.heldId, 'shared.pen');
      await tester.tap(find.byKey(const ValueKey('cafe-use-write')));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(c.heldId, isNull);
      expect(store.value.uses[plant], isTrue);
      await end(tester);
    },
  );
  testWidgets(
    'chair pulls, seats, stands and returns without moving its siblings',
    (tester) async {
      final store = MemoryCafeSpaceStore();
      final c = await room(tester, store: store);
      const id = 'shared.chair.right.0';
      final origin = c.world.objects[id]!.pivot;
      final sibling = c.world.objects['shared.chair.right.1']!.pivot;
      await use(tester, id);
      expect(c.activeChairId, id);
      expect(store.value.uses[id], isTrue);
      expect((c.world.objects[id]!.pivot - origin).length, closeTo(.06, 1e-8));
      tester.widget<CafeScene>(find.byType(CafeScene)).onItemActivated!(id);
      await tester.pumpAndSettle();
      expect(c.seat, isNull);
      await tester.tap(find.byKey(const ValueKey('cafe-use-push-chair')));
      await tester.pumpAndSettle();
      expect(store.value.uses[id], isFalse);
      expect((c.world.objects[id]!.pivot - origin).length, lessThan(1e-8));
      expect(
        (c.world.objects['shared.chair.right.1']!.pivot - sibling).length,
        lessThan(1e-8),
      );
      await end(tester);
    },
  );
}
