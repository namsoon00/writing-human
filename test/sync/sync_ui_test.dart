import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/data/library_controller.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/data/store.dart';
import 'package:writing_human/sync/context.dart';
import 'package:writing_human/sync/coordinator.dart';
import 'package:writing_human/sync/remote.dart';
import 'package:writing_human/ui/workspace.dart';

class UiStore implements LibraryStore {
  Library library = const Library(
    books: [Book(id: 'b', title: '나의 동기화 책장', author: '나')],
    records: [WritingRecord(id: 'r', bookId: 'b', title: '필사 1')],
    pages: [
      WritingPage(id: 'p', recordId: 'r', number: 1, text: '두 기기에서 이어 쓰는 문장'),
    ],
    activePageId: 'p',
  );
  @override
  Future<Library> load() async => library;
  @override
  Future<void> save(Library next) async {
    library = Library.decode(next.encode());
  }

  @override
  Future<void> close() async {}
}

class UiRemote implements CloudRemote {
  bool offline = false, unauthenticated = false;
  String user = 'writer';
  CloudSnapshot snapshot = const CloudSnapshot(0, null, null);
  void check() {
    if (unauthenticated) {
      throw const CloudFailure('sign_in_required');
    }
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
    return snapshot;
  }

  @override
  Future<CloudSnapshot> write(int revision, Library library) async {
    check();
    return snapshot = CloudSnapshot(
      revision + 1,
      Library.decode(jsonEncode(library.toCloudJson())),
      '2026-11-09T00:00:00Z',
    );
  }

  @override
  void close() {}
}

void main() {
  testWidgets(
    'Cloud status distinguishes offline storage, and account changes hide the old library',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        final font = FontLoader('NanumMyeongjo')
          ..addFont(rootBundle.load('assets/fonts/NanumMyeongjo-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/NanumMyeongjo-Bold.ttf'));
        await font.load();
        await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
              rootBundle.load(
                'packages/cupertino_icons/assets/CupertinoIcons.ttf',
              ),
            ))
            .load();
      });
      final store = UiStore(), remote = UiRemote();
      final c = LibraryController(store, await store.load());
      final sync = SyncCoordinator(
        c,
        SyncContext(
          store: store,
          remote: remote,
          account: const CloudSession('writer', 'writer@example.test'),
          reload: () {},
        ),
        automatic: false,
      );
      final boundary = GlobalKey();
      await sync.syncNow();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(useMaterial3: true, fontFamily: 'NanumMyeongjo'),
            home: Workspace(controller: c, sync: sync),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/images/linen-cover.png'),
          boundary.currentContext!,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('더 보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('기기 동기화'));
      await tester.pumpAndSettle();
      expect(find.text('기기 간 동기화 완료'), findsOneWidget);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('artifacts').create(recursive: true);
        await File(
          'artifacts/sync-widget.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
      remote.offline = true;
      await tester.tap(find.text('지금 동기화'));
      await tester.pumpAndSettle();
      expect(find.text('기기에 저장됨 · 연결되면 다시 동기화'), findsOneWidget);
      expect(find.text('기기 간 동기화 완료'), findsNothing);
      expect(store.library.pages.single.text, '두 기기에서 이어 쓰는 문장');
      // Dismiss the modal before testing the full-screen identity guard.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      remote.offline = false;
      remote.user = 'other';
      await sync.syncNow();
      await tester.pumpAndSettle();
      expect(find.text('로그인 계정이 바뀌었습니다.'), findsOneWidget);
      expect(find.text('나의 동기화 책장'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      sync.dispose();
      c.dispose();
    },
  );
}
