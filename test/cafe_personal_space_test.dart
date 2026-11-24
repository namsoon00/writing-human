import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:writing_human/cafe/cafe_camera.dart';
import 'package:writing_human/cafe/cafe_visit.dart';
import 'package:writing_human/cafe/cafe_space.dart';
import 'package:writing_human/cafe/cafe_world.dart';
import 'package:writing_human/cafe/cafe_view_controller.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/data/sqlite_store.dart';
import 'package:writing_human/ui/cafe_screen.dart';
import 'package:writing_human/ui/cafe_scene.dart';

class FailingRoomStore extends MemoryCafeSpaceStore {
  bool reject = false;
  int saves = 0;
  @override
  Future<void> save(CafeSpace v) async {
    saves++;
    if (reject) throw StateError('injected storage failure');
    await super.save(v);
  }
}

void main() {
  test(
    'Furniture transforms carry props, approach and seat together; invalid changes keep the old room',
    () {
      final c = CafeViewController();
      addTearDown(c.dispose);
      expect(c.world.validateLayout(), isNull);
      expect(c.world.linkedWorld.validateLayout(), isNull);
      final previousCup = c.world.objects['shared.cup']!.pivot;
      final next = c.space.copy(
        poses: const {
          'shared': CafePose(x: .20, z: .10, turn: math.pi / 12),
          'shared.cup': CafePose(x: .05, z: -.05),
        },
      );
      expect(c.applySpace(next), isNull);
      final cup = c.world.objects['shared.cup']!.pivot;
      final local = previousCup + const CafePoint(.05, 0, -.05);
      final expected = CafePoint(
        local.x * math.cos(math.pi / 12) -
            local.z * math.sin(math.pi / 12) +
            .20,
        local.y,
        local.x * math.sin(math.pi / 12) +
            local.z * math.cos(math.pi / 12) +
            .10,
      );
      expect((cup - expected).length, lessThan(1e-8));
      expect(c.world.targetApproach(CafeTarget.shared).x, greaterThan(1.5));
      final saved = c.space.encode();
      expect(
        c.applySpace(
          c.space.copy(
            poses: {...c.space.poses, 'shared.cup': const CafePose(x: 1.4)},
          ),
        ),
        isNotNull,
      );
      expect(c.space.encode(), saved);
      expect(
        c.applySpace(
          c.space.copy(
            poses: {...c.space.poses, 'quiet': const CafePose(x: -.7)},
          ),
        ),
        isNotNull,
      );
      expect(c.space.encode(), saved);
    },
  );

  test(
    'SQLite reopen restores per-account space and a failed write keeps the last good row and manuscript',
    () async {
      sqfliteFfiInit();
      final dir = await Directory.systemTemp.createTemp('personal-cafe-test-');
      final file = '${dir.path}/library.db';
      var db = await SqliteLibraryStore.open(file, factory: databaseFactoryFfi);
      try {
        const library = Library(
          books: [Book(id: 'b', title: 'my book')],
        );
        await db.save(library);
        final a = await db.openSpaceStore('account-a');
        final config = const CafeSpace().copy(
          brightness: 1.15,
          amounts: const {'desk.window.cup': 1},
          uses: const {'plant.3.77_-3.9': true},
          finishes: const {'shared.cup': 1, 'desk.window.cup': 2},
          accents: const {'shared.chair.right.1': 2},
          states: const {'quiet.book': false, 'lamp.0.0_0.68': false},
          lights: const {'lamp.0.0_-0.83': .5},
          cupFull: false,
          bookOpen: false,
          doorOpen: false,
          selectedBookId: 'b',
          poses: const {'shared.cup': CafePose(x: .1, turn: .3)},
          frames: const {'frame.2.44_4.84': 1},
          art: const {'frame.2.44_4.84': 2},
        );
        await a.save(config);
        expect(
          (await (await db.openSpaceStore('account-b')).load()).encode(),
          const CafeSpace().encode(),
        );
        await db.db.execute(
          "CREATE TRIGGER fail_room BEFORE INSERT ON cafe_space BEGIN SELECT RAISE(ABORT, 'injected'); END",
        );
        await expectLater(
          a.save(config.copy(brightness: .8)),
          throwsA(anything),
        );
        expect((await a.load()).encode(), config.encode());
        expect((await db.load()).encode(), library.encode());
        await db.db.execute('DROP TRIGGER fail_room');
        await db.close();
        db = await SqliteLibraryStore.open(file, factory: databaseFactoryFfi);
        expect(
          (await (await db.openSpaceStore('account-a')).load()).encode(),
          config.encode(),
        );
        await db.db.update(
          'cafe_space',
          {'payload': 'broken'},
          where: 'scope = ?',
          whereArgs: ['account-a'],
        );
        await expectLater(
          (await db.openSpaceStore('account-a')).load(),
          throwsFormatException,
        );
        expect((await db.load()).encode(), library.encode());
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'Room decoding rejects damaged versions, nonfinite positions and invalid light ranges',
    () {
      for (final raw in ['{}', '{"version":2}', '{"version":1,"poses":[]}']) {
        expect(() => CafeSpace.decode(raw), throwsFormatException);
      }
      expect(
        () => CafeSpace.decode(const CafeSpace(brightness: 3).encode()),
        throwsFormatException,
      );
      expect(
        () => CafeSpace.decode(
          const CafeSpace(poses: {'shared': CafePose(x: 12)}).encode(),
        ),
        throwsFormatException,
      );
    },
  );

  testWidgets(
    'Room save failure stays editable; cancel and re-entry restore last successful settings',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final store = FailingRoomStore();
      Widget screen(Key key) => MaterialApp(
        home: CafeScreen(
          key: key,
          books: const [],
          currentWritingLabel: 'test',
          spaceStore: store,
          onWrite: (seat, book) async => true,
          onLeave: () {},
          onRetry: () {},
        ),
      );
      await tester.pumpWidget(screen(const ValueKey('first')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('room-edit')));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('room-brightness')),
        const Offset(80, 0),
      );
      await tester.pumpAndSettle();
      final c = tester.widget<CafeScene>(find.byType(CafeScene)).controller;
      final desired = c.space.brightness;
      expect(desired, greaterThan(1));
      store.reject = true;
      await tester.ensureVisible(find.byKey(const ValueKey('room-finish')));
      await tester.tap(find.byKey(const ValueKey('room-finish')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('room-error')), findsOneWidget);
      expect(store.value.brightness, 1);
      expect(c.space.brightness, desired);
      store.reject = false;
      await tester.tap(find.byKey(const ValueKey('room-finish')));
      await tester.pumpAndSettle();
      expect(store.value.brightness, desired);
      await tester.pumpWidget(screen(const ValueKey('reopened')));
      await tester.pumpAndSettle();
      final reopened = tester
          .widget<CafeScene>(find.byType(CafeScene))
          .controller;
      expect(reopened.space.brightness, desired);
      await tester.tap(find.byKey(const ValueKey('room-edit')));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('room-brightness')),
        const Offset(-100, 0),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('room-cancel')));
      await tester.tap(find.byKey(const ValueKey('room-cancel')));
      await tester.pumpAndSettle();
      expect(reopened.space.brightness, desired);
      expect(store.value.brightness, desired);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Unreadable room settings cannot be overwritten with an empty room; retry loads the saved value',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final store = UnreadableRoomStore();
      store.value = const CafeSpace(brightness: 1.2);
      await tester.pumpWidget(
        MaterialApp(
          home: CafeScreen(
            books: const [],
            currentWritingLabel: 'test',
            spaceStore: store,
            onWrite: (seat, book) async => true,
            onLeave: () {},
            onRetry: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('room-error')), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('room-edit')))
            .onPressed,
        isNull,
      );
      expect(store.writes, 0);
      store.unreadable = false;
      await tester.tap(find.text('다시 불러오기'));
      await tester.pumpAndSettle();
      final c = tester.widget<CafeScene>(find.byType(CafeScene)).controller;
      expect(c.space.brightness, 1.2);
      expect(store.writes, 0);
      expect(find.byKey(const ValueKey('room-error')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}

class UnreadableRoomStore extends MemoryCafeSpaceStore {
  bool unreadable = true;
  int writes = 0;
  @override
  Future<CafeSpace> load() async {
    if (unreadable) {
      throw const FormatException('injected');
    }
    return value;
  }

  @override
  Future<void> save(CafeSpace v) async {
    writes++;
    await super.save(v);
  }
}
