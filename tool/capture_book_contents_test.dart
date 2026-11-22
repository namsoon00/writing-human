// Product render with self-written QA text, never personal records.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/main.dart';
import '../test/widget_test.dart' show MemoryStore;

void main() {
  testWidgets(
    'Capture the contents leaf and its compact and large type states',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.runAsync(() async {
        for (final (family, asset) in [
          (
            'WritingHumanDevelopment',
            'assets/fonts/WritingHumanDevelopment-Regular.ttf',
          ),
          ('NanumMyeongjo', 'assets/fonts/NanumMyeongjo-Regular.ttf'),
          ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
          (
            'packages/cupertino_icons/CupertinoIcons',
            'packages/cupertino_icons/assets/CupertinoIcons.ttf',
          ),
        ]) {
          await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
        }
        await Directory(
          'output/book-contents-20261122',
        ).create(recursive: true);
      });
      const library = Library(
        books: [Book(id: 'book', title: '오래 곁에 둘 문장', coverIndex: 2)],
        records: [
          WritingRecord(id: 'a', bookId: 'book', title: '창가에서'),
          WritingRecord(id: 'b', bookId: 'book', title: '필사 7'),
        ],
        pages: [
          WritingPage(
            id: 'a1',
            recordId: 'a',
            number: 1,
            text: '창가에 앉아 책을 펼칩니다.',
          ),
          WritingPage(
            id: 'a2',
            recordId: 'a',
            number: 2,
            text: '마음에 남은 문장을 천천히 씁니다.',
          ),
          WritingPage(
            id: 'b1',
            recordId: 'b',
            number: 1,
            text: '오늘 적은 한 줄은 나의 한 권으로 남습니다.',
          ),
        ],
        activePageId: 'b1',
      );
      final store = MemoryStore()..data = library;
      for (final (name, size, scale) in [
        ('phone', const Size(390, 844), 1.0),
        ('compact', const Size(320, 568), 1.0),
        ('large-text', const Size(320, 640), 2.0),
        ('wide', const Size(900, 700), 1.0),
      ]) {
        tester.view.physicalSize = size;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('capture'),
            child: WritingHumanApp(key: ValueKey(name), store: store),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('open-bookshelf')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('shelf-book-book')));
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await tester.pumpAndSettle();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('capture')),
        );
        Future<void> capture(String label) => tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List();
          await File(
            'output/book-contents-20261122/$label.png',
          ).writeAsBytes(bytes);
          image.dispose();
        });
        await capture(name);
        if (scale >= 2) {
          final resume = find.byKey(const ValueKey('contents-resume-writing'));
          await tester.scrollUntilVisible(
            resume,
            160,
            scrollable: find.descendant(
              of: find.byKey(const ValueKey('book-contents-book')),
              matching: find.byType(Scrollable),
            ),
          );
          await tester.pumpAndSettle();
          expect(resume.hitTestable(), findsOneWidget);
          await capture('$name-end');
        }
        expect(tester.takeException(), isNull);
      }
    },
  );
}
