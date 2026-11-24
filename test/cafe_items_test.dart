import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_renderer.dart';
import 'package:writing_human/cafe/cafe_space.dart';
import 'package:writing_human/cafe/cafe_view_controller.dart';
import 'package:writing_human/cafe/cafe_visit.dart';
import 'package:writing_human/cafe/cafe_world.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Legacy v1 layouts retain poses and defaults; v2 item states are independent',
    () {
      final old = const CafeSpace(
        poses: {'shared': CafePose(x: .12, turn: .08)},
        cushion: 2,
        mug: 1,
        pot: 2,
        bookOpen: false,
        cupFull: false,
      ).toJson()..['version'] = 1;
      for (final key in ['finishes', 'accents', 'states', 'lights']) {
        old.remove(key);
      }
      final migrated = CafeSpace.decode(jsonEncode(old));
      final controller = CafeViewController(space: migrated);
      addTearDown(controller.dispose);
      expect(controller.applySpace(migrated), isNull);
      expect(migrated.pose('shared').x, .12);
      expect(migrated.bookOpen, isFalse);
      final next = migrated
          .withFinish('shared.cup', 2)
          .withFinish('desk.window.cup', 0)
          .withState('quiet.book', false)
          .withAccent('shared.chair.right.1', 1)
          .withLight('lamp.0.0_0.68', .5);
      final reopened = CafeSpace.decode(next.encode());
      expect(reopened.finish('shared.cup'), 2);
      expect(reopened.finish('desk.window.cup'), 0);
      expect(reopened.state('quiet.book'), isFalse);
      expect(reopened.states.containsKey('desk.window.book'), isFalse);
      final reset = reopened.resetItem('shared.cup');
      expect(reset.finishes.containsKey('shared.cup'), isFalse);
      expect(reset.cupFull, isTrue);
      expect(reset.finish('desk.window.cup'), 0);
      expect(reset.state('quiet.book'), isFalse);
      final broken = {...old}..remove('poses');
      expect(() => CafeSpace.decode(jsonEncode(broken)), throwsFormatException);
      for (final entry in [
        {
          'finishes': {'shared.cup': 9},
        },
        {
          'states': {'shared.cup': 1},
        },
        {
          'lights': {'lamp.0.0_0.68': 0},
        },
      ]) {
        expect(
          () => CafeSpace.decode(jsonEncode({...next.toJson(), ...entry})),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'Tables carry their own props; chair edits preserve sibling positions and seated view',
    () {
      final c = CafeViewController();
      addTearDown(c.dispose);
      final oldCup = c.world.objects['shared.cup']!.pivot;
      final oldChair = c.world.objects['shared.chair.right.1']!.pivot;
      expect(
        c.applySpace(
          c.space.copy(poses: const {'shared.table': CafePose(z: .15)}),
        ),
        isNull,
      );
      expect(
        c.world.objects['shared.cup']!.pivot.z,
        closeTo(oldCup.z + .15, 1e-8),
      );
      expect(c.world.targetDesk(CafeSeat.shared).z, closeTo(.90, 1e-8));
      expect(
        (c.world.objects['shared.chair.right.1']!.pivot - oldChair).length,
        0,
      );
      expect(
        c.applySpace(
          c.space.copy(
            poses: {
              ...c.space.poses,
              'shared.chair.right.1': const CafePose(x: .12, turn: -.12),
            },
          ),
        ),
        isNull,
      );
      expect(c.visitChair('shared.chair.right.1'), isTrue);
      c.updateCamera(c.destination!);
      c.finishTravel();
      final chair = c.world.objects['shared.chair.right.1']!;
      expect(c.activeChairId, chair.id);
      expect(c.camera.position.x, closeTo(chair.pivot.x, 1e-8));
      expect(c.camera.yaw, closeTo(chair.yaw, 1e-8));
      c.stand();
      expect(c.world.canStand(c.destination!.position), isTrue);
      expect(c.activeChairId, isNull);
      final saved = c.space.encode();
      expect(
        c.applySpace(
          c.space.copy(
            poses: {
              ...c.space.poses,
              'shared.chair.right.1': const CafePose(x: -.65),
            },
          ),
        ),
        isNotNull,
      );
      expect(c.space.encode(), saved);
    },
  );

  test('Support checks include object edges, overlaps and parent rotation', () {
    final c = CafeViewController();
    addTearDown(c.dispose);
    expect(
      c.applySpace(
        c.space.copy(poses: const {'shared.cup': CafePose(x: -.27)}),
      ),
      isNull,
    );
    final saved = c.space.encode();
    expect(
      c.applySpace(
        c.space.copy(poses: const {'shared.cup': CafePose(x: -.30)}),
      ),
      isNotNull,
    );
    expect(c.space.encode(), saved);
    expect(
      c.applySpace(
        c.space.copy(poses: const {'shared.cup': CafePose(x: .44, z: .57)}),
      ),
      isNotNull,
    );
    expect(
      c.applySpace(
        const CafeSpace(
          poses: {'shared': CafePose(x: .2, z: .1, turn: math.pi / 12)},
        ),
      ),
      isNull,
    );
    final old = c.world.objects['shared.cup']!.pivot;
    final point = old + const CafePoint(.025, 0, -.025);
    expect(c.applySpace(c.world.placed('shared.cup', point)), isNull);
    expect(
      (c.world.objects['shared.cup']!.pivot - point).length,
      lessThan(1e-8),
    );
  });

  test(
    'Primary garden plants have persistent volumetric meshes and safe placement',
    () {
      final world = CafeWorld(courtyard: true);
      expect(world.validateLayout(), isNull);
      final trees = world.objects.values
          .where((o) => o.id.startsWith('garden.tree.'))
          .toList();
      expect(trees.length, 2);
      for (final item in trees) {
        final vertices = world.faces
            .where((f) => f.objectId == item.id)
            .expand((f) => f.points)
            .toList();
        expect(vertices.length, greaterThan(1000));
        expect(
          vertices.map((p) => p.x).reduce(math.max) -
              vertices.map((p) => p.x).reduce(math.min),
          greaterThan(.6),
        );
        expect(
          vertices.map((p) => p.z).reduce(math.max) -
              vertices.map((p) => p.z).reduce(math.min),
          greaterThan(.6),
        );
      }
      final treeId = trees.first.id;
      final originalColors = world.faces
          .where((f) => f.objectId == treeId)
          .map((f) => f.color)
          .toSet();
      for (final finish in [1, 2]) {
        final changed = CafeWorld(
          courtyard: true,
          space: const CafeSpace().withFinish(treeId, finish),
        );
        final changedColors = changed.faces
            .where((f) => f.objectId == treeId)
            .map((f) => f.color)
            .toSet();
        expect(
          changedColors,
          isNot(unorderedEquals(originalColors)),
          reason:
              'Leaf presets must change the palette, not shuffle the same colors.',
        );
      }
      final pink = world.objects.values.firstWhere(
        (o) => o.id.startsWith('garden.flowers.') && o.defaultFinish == 1,
      );
      final ivory = CafeWorld(
        courtyard: true,
        space: const CafeSpace().withFinish(pink.id, 0),
      );
      expect(
        ivory.faces
            .where((f) => f.objectId == pink.id)
            .map((f) => f.color)
            .toList(),
        isNot(
          orderedEquals(
            world.faces
                .where((f) => f.objectId == pink.id)
                .map((f) => f.color)
                .toList(),
          ),
        ),
      );
      final valid = CafeWorld(
        courtyard: true,
        space: const CafeSpace(
          poses: {'garden.tree.18': CafePose(x: .1, z: -.1)},
        ),
      );
      expect(valid.validateLayout(), isNull);
      final invalid = CafeWorld(
        courtyard: true,
        space: const CafeSpace(
          poses: {'garden.tree.18': CafePose(x: 1.5, z: 1.5)},
        ),
      );
      expect(invalid.validateLayout(), isNotNull);
    },
  );

  test(
    'Shelf books, counter tools, lamps and props are picked by their own ID',
    () {
      final world = CafeWorld();
      expect(
        world.objects.values.where((o) => o.type == CafeItemType.volume).length,
        34,
      );
      expect(world.objects['counter.machine.cup.0']!.parent, 'counter.machine');
      expect(world.objects['shared.stack']!.defaultFinish, 1);
      expect(world.objects['shelf.stack.-2.25_0']!.defaultFinish, 1);
      final ivoryStack = CafeWorld(
        space: const CafeSpace().withFinish('shared.stack', 0),
      );
      final topCover = ivoryStack.faces
          .where(
            (f) =>
                f.objectId == 'shared.stack' &&
                f.normal.y > .99 &&
                f.center.y > .81 &&
                f.center.y < .82,
          )
          .toList();
      expect(topCover, isNotEmpty);
      expect(topCover.every((f) => f.color == CafeWorld.cream), isTrue);

      expect(
        world.faces
            .where((f) => f.objectId == 'shelf.stack.-2.25_0')
            .every((f) => f.target == CafeTarget.recommendations),
        isTrue,
      );
      expect(
        world.faces
            .where((f) => f.objectId == 'shelf.stack.0.3_0')
            .every((f) => f.target == CafeTarget.bookshelf),
        isTrue,
      );
      for (final id in [
        'shelf.stack.-2.25_0',
        'shelf.stack.0.3_0',
        'counter.machine',
        'counter.grinder',
        'counter.carafe',
        'counter.linen',
        'shared.runner',
        'quiet.chair',
      ]) {
        expect(world.faces.any((f) => f.objectId == id), isTrue, reason: id);
      }
      final p = world.objects['shared.cup']!.pivot;
      final camera = CafeCamera(
        position: p + const CafePoint(0, .55, .20),
        pitch: -1.20,
      );
      expect(
        CafeRenderer.pick(
          const Offset(200, 200),
          camera,
          const Size(400, 400),
          world,
        )?.objectId,
        'shared.cup',
      );
      final id = world.objects.values
          .firstWhere((o) => o.type == CafeItemType.lamp)
          .id;
      final on = CafeWorld(),
          off = CafeWorld(space: const CafeSpace().withState(id, false));
      expect(off.pendantGains.where((g) => g == 0).length, 1);
      expect(on.pendantGains.skip(1), off.pendantGains.skip(1));
      expect(
        off.lightFaces(CafeCamera.entrance).length,
        lessThan(on.lightFaces(CafeCamera.entrance).length),
      );
    },
  );
}
