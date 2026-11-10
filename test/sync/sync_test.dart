import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:writing_human/data/library_controller.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/data/sqlite_store.dart';
import 'package:writing_human/sync/context.dart';
import 'package:writing_human/sync/coordinator.dart';
import 'package:writing_human/sync/merge.dart';
import 'package:writing_human/sync/remote.dart';

class Hub {
  int revision = 0, writes = 0;
  Library? data;
}

class DeviceRemote implements CloudRemote {
  DeviceRemote(this.hub);
  final Hub hub;
  bool offline = false;
  String user = 'same-account';
  Completer<void>? entered, release;
  void check() {
    if (offline) {
      throw const CloudFailure('unavailable');
    }
  }

  @override
  Future<CloudSession> session() async {
    check();
    return CloudSession(user, 'writer@example.test');
  }

  @override
  Future<CloudSnapshot> read() async {
    check();
    return CloudSnapshot(hub.revision, hub.data, '2026-11-09T00:00:00Z');
  }

  @override
  Future<CloudSnapshot> write(int revision, Library library) async {
    check();
    entered?.complete();
    await release?.future;
    if (revision != hub.revision) {
      throw RevisionConflict();
    }
    hub.revision++;
    hub.writes++;
    hub.data = Library.decode(jsonEncode(library.toCloudJson()));
    return read();
  }

  @override
  void close() {}
}

void main() {
  test(
    'Font fallback index and development flag remain one choice when merging',
    () {
      const base = Library();
      final local = base.copy(style: base.style.copy(fontIndex: 2));
      final remote = base.copy(
        style: base.style.copy(useDevelopmentTypeface: true),
      );
      final merged = mergeLibraries(base, local, remote).library;
      expect(merged.style.fontIndex, 2);
      expect(merged.style.useDevelopmentTypeface, isFalse);
      final paperOnly = base.copy(style: base.style.copy(paperIndex: 2));
      final complementary = mergeLibraries(base, paperOnly, remote).library;
      expect(complementary.style.useDevelopmentTypeface, isTrue);
      expect(complementary.style.paperIndex, 2);
    },
  );
  sqfliteFfiInit();
  late Directory dir;
  late SqliteLibraryStore aStore, bStore;
  late LibraryController a, b;
  late SyncCoordinator sa, sb;
  late DeviceRemote ra, rb;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('writing-human-sync-');
    aStore = await SqliteLibraryStore.open(
      '${dir.path}/pc.db',
      factory: databaseFactoryFfi,
    );
    bStore = await SqliteLibraryStore.open(
      '${dir.path}/mobile.db',
      factory: databaseFactoryFfi,
    );
    a = LibraryController(aStore, await aStore.load());
    b = LibraryController(bStore, await bStore.load());
    final hub = Hub();
    ra = DeviceRemote(hub);
    rb = DeviceRemote(hub);
    sa = SyncCoordinator(
      a,
      SyncContext(
        store: aStore,
        remote: ra,
        account: const CloudSession('same-account', ''),
      ),
      automatic: false,
    );
    sb = SyncCoordinator(
      b,
      SyncContext(
        store: bStore,
        remote: rb,
        account: const CloudSession('same-account', ''),
      ),
      automatic: false,
    );
  });
  tearDown(() async {
    sa.dispose();
    sb.dispose();
    await a.settled;
    await b.settled;
    a.dispose();
    b.dispose();
    await aStore.close();
    await bStore.close();
    await dir.delete(recursive: true);
  });
  Future<void> establish() async {
    a.createBook('두 기기에서 쓰는 책', '나');
    a.editPage(a.library.activePageId!, '처음 쓴 한글 문장', 2, 4, 44);
    await a.settled;
    await sa.syncNow();
    await sb.syncNow();
    expect(a.saveError, isNull);
    expect(b.saveError, isNull);
  }

  test(
    'Separate SQLite devices receive content, position, preferences and durable baseline',
    () async {
      await establish();
      expect(b.library.activePage!.text, '처음 쓴 한글 문장');
      expect(b.library.activePage!.base, 2);
      expect(b.library.activePage!.scroll, 44);
      a.setStyle(
        a.library.style.copy(
          paperIndex: 2,
          penIndex: 1,
          fontIndex: 2,
          useDevelopmentTypeface: true,
          penMotion: false,
        ),
      );
      await a.settled;
      await sa.syncNow();
      await sb.syncNow();
      expect(b.library.style.paperIndex, 2);
      expect(b.library.style.penIndex, 1);
      expect(b.library.style.fontIndex, 2);
      expect(b.library.style.useDevelopmentTypeface, isTrue);
      expect(b.library.style.penMotion, isFalse);
      await bStore.close();
      bStore = await SqliteLibraryStore.open(
        '${dir.path}/mobile.db',
        factory: databaseFactoryFfi,
      );
      final persisted = await bStore.load();
      expect(persisted.style.useDevelopmentTypeface, isTrue);
      expect(persisted.sync.accountId, 'same-account');
      expect(persisted.sync.revision, ra.hub.revision);
      expect(persisted.sync.baseline, isNotNull);
      expect(persisted.activePage!.text, '처음 쓴 한글 문장');
    },
  );

  test(
    'Offline edits on the same page preserve both prose versions and converge',
    () async {
      await establish();
      final id = a.library.activePageId!;
      ra.offline = true;
      rb.offline = true;
      a.editPage(id, 'PC에서 고친 문장', 3, 3, 0);
      b.editPage(id, '모바일에서 고친 문장', 4, 4, 0);
      await a.settled;
      await b.settled;
      await sa.syncNow();
      expect(sa.phase, 'offline');
      expect((await aStore.load()).activePage!.text, 'PC에서 고친 문장');
      ra.offline = false;
      rb.offline = false;
      await sa.syncNow();
      await sb.syncNow();
      await sa.syncNow();
      for (final c in [a, b]) {
        expect(
          c.library.pages.map((p) => p.text),
          containsAll(['PC에서 고친 문장', '모바일에서 고친 문장']),
        );
        expect(
          c.library.records.where((r) => r.title.contains('충돌 보관')).length,
          1,
        );
        expect(c.saveError, isNull);
      }
      expect(
        sameData(a.library.toCloudJson(), b.library.toCloudJson()),
        isTrue,
      );
    },
  );

  test(
    'Offline page-number collisions keep both new pages in real SQLite',
    () async {
      await establish();
      a.addPage();
      b.addPage();
      a.editPage(a.library.activePageId!, 'PC의 새 페이지', 0, 0, 0);
      b.editPage(b.library.activePageId!, '모바일의 새 페이지', 0, 0, 0);
      await a.settled;
      await b.settled;
      await sa.syncNow();
      await sb.syncNow();
      await sa.syncNow();
      final data = await aStore.load();
      expect(data.pages.length, 3);
      expect(data.pages.map((p) => p.number).toSet(), {1, 2, 3});
      expect(
        data.pages.map((p) => p.text),
        containsAll(['PC의 새 페이지', '모바일의 새 페이지']),
      );
      expect(a.saveError, isNull);
      expect(b.saveError, isNull);
    },
  );

  test(
    'Edits during an in-flight upload are rebased without rolling back typing',
    () async {
      await establish();
      final id = a.library.activePageId!;
      a.editPage(id, '요청을 시작한 문장', 2, 2, 0);
      await a.settled;
      ra.entered = Completer<void>();
      ra.release = Completer<void>();
      final pending = sa.syncNow();
      await ra.entered!.future;
      a.editPage(id, '요청 도중 더 쓴 마지막 문장', 4, 4, 0);
      await a.settled;
      ra.release!.complete();
      await pending;
      expect(a.library.activePage!.text, '요청 도중 더 쓴 마지막 문장');
      expect(sa.phase, 'pending');
      ra.entered = null;
      ra.release = null;
      await sa.syncNow();
      await sb.syncNow();
      expect(b.library.activePage!.text, '요청 도중 더 쓴 마지막 문장');
    },
  );

  test(
    'IME composition and focused remote edits never replace the active editor',
    () async {
      await establish();
      final id = a.library.activePageId!;
      b.editPage(id, '다른 기기에서 온 새 문장', 2, 2, 0);
      await b.settled;
      await sb.syncNow();
      a.setEditorState(focused: true, isComposing: true);
      await sa.syncNow();
      expect(sa.phase, 'composing');
      expect(a.library.activePage!.text, '처음 쓴 한글 문장');
      a.setEditorState(focused: true, isComposing: false);
      await sa.syncNow();
      expect(sa.phase, 'incoming');
      expect(a.editorEpoch, 0);
      a.setEditorState(focused: false, isComposing: false);
      await sa.syncNow();
      expect(a.library.activePage!.text, '다른 기기에서 온 새 문장');
      expect(a.editorEpoch, 1);
    },
  );

  test(
    'Idle devices do not send stale navigation back and forth; reopen resumes the cloud position',
    () async {
      await establish();
      final first = a.library.activePageId!;
      a.addPage();
      final second = a.library.activePageId!;
      await a.settled;
      await sa.syncNow();
      await sb.syncNow();
      b.openPage(first);
      await b.settled;
      await sb.syncNow();
      final writes = ra.hub.writes;
      await sa.syncNow();
      await sa.syncNow();
      expect(
        a.library.activePageId,
        second,
      ); // Keep the current visible reading route.
      expect(
        ra.hub.data!.activePageId,
        first,
      ); // Preserve the most recent real interaction.
      expect(ra.hub.writes, writes);
      expect(sa.phase, 'synced');
      final disk = await aStore.load();
      expect(disk.sync.positionDirty, isFalse);
      sa.dispose();
      a.dispose();
      a = LibraryController(aStore, disk);
      sa = SyncCoordinator(
        a,
        SyncContext(
          store: aStore,
          remote: ra,
          account: const CloudSession('same-account', ''),
        ),
        automatic: false,
      );
      await sa.syncNow();
      expect(a.library.activePageId, first);
    },
  );

  test(
    'Explicit legacy import keeps the original device file unchanged',
    () async {
      final legacyStore = await SqliteLibraryStore.open(
        '${dir.path}/guest.db',
        factory: databaseFactoryFfi,
      );
      final legacy = LibraryController(legacyStore, await legacyStore.load());
      try {
        legacy.createBook('이전 기기 기록', '나');
        legacy.editPage(
          legacy.library.activePageId!,
          '먼저 쓴 문장을 지우지 않는다.',
          3,
          3,
          0,
        );
        await legacy.settled;
        final before = (await legacyStore.load()).encode();
        sa.dispose();
        sa = SyncCoordinator(
          a,
          SyncContext(
            store: aStore,
            remote: ra,
            account: const CloudSession('same-account', ''),
            legacy: legacyStore,
          ),
          automatic: false,
        );
        await sa.inspectLegacy();
        await sa.syncNow();
        expect(sa.hasLegacy, isTrue);
        expect(ra.hub.data!.books, isEmpty);
        await sa.importLegacy();
        expect(ra.hub.data!.pages.single.text, '먼저 쓴 문장을 지우지 않는다.');
        expect((await aStore.load()).sync.legacyImported, isTrue);
        expect(sa.hasLegacy, isFalse);
        expect((await legacyStore.load()).encode(), before);
      } finally {
        legacy.dispose();
        await legacyStore.close();
      }
    },
  );

  test(
    'An account change stops writes rather than copying the previous account',
    () async {
      await establish();
      final writes = ra.hub.writes;
      ra.user = 'another-account';
      a.editPage(a.library.activePageId!, '보내면 안 되는 이전 계정 기록', 0, 0, 0);
      await a.settled;
      await sa.syncNow();
      expect(sa.accountMismatch, isTrue);
      expect(ra.hub.writes, writes);
      expect(ra.hub.data!.pages.single.text, '처음 쓴 한글 문장');
    },
  );
}
