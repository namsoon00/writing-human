// Native Flutter specimens with synthetic copy; never user data or device captures.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/data/demo_store.dart';
import 'package:writing_human/main.dart';
import 'package:writing_human/ui/book_detail_design.dart';
import 'package:writing_human/ui/book_detail_tools.dart';
import 'package:writing_human/ui/paper.dart';
import 'package:writing_human/ui/collection_sheet.dart';
import 'package:writing_human/ui/reading_details.dart';
import 'package:writing_human/ui/book_front_cover.dart';

void main() {
  testWidgets('Render ten independent design sheets with shapes and palettes', (
    tester,
  ) async {
    final shadows = debugDisableShadows;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = shadows);
    tester.view.physicalSize = const Size(1080, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await (FontLoader('WritingHumanDevelopment')..addFont(
            rootBundle.load('assets/fonts/WritingHumanDevelopment-Regular.ttf'),
          ))
          .load();
      await (FontLoader(
            'NanumMyeongjo',
          )..addFont(rootBundle.load('assets/fonts/NanumMyeongjo-Regular.ttf')))
          .load();
      await (FontLoader('NanumGothic')
            ..addFont(rootBundle.load('assets/fonts/NanumGothic-Regular.ttf')))
          .load();
    });
    for (final kind in BookDetailKind.values) {
      final key = GlobalKey();
      final design = BookDetailDesign.of(kind);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            fontFamily: 'NanumGothic',
            scaffoldBackgroundColor: paper,
          ),
          home: RepaintBoundary(
            key: key,
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${(kind.index + 1).toString().padLeft(2, '0')}   ${design.title}',
                      style: const TextStyle(
                        fontFamily: serif,
                        fontSize: 25,
                        color: brandInk,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      design.description,
                      style: const TextStyle(fontSize: 13, color: muted),
                    ),
                    const SizedBox(height: 22),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < 3; i++)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(right: i < 2 ? 28 : 0),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      design.variants[i],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: muted,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    BookDetailPreview(
                                      kind: kind,
                                      choice: BookDetailChoice(variant: i),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < 4; i++)
                          Padding(
                            padding: const EdgeInsets.only(right: 24),
                            child: Row(
                              children: [
                                Container(
                                  width: 13,
                                  height: 13,
                                  decoration: BoxDecoration(
                                    color: design.colors[i],
                                    shape: BoxShape.circle,
                                    border: Border.all(color: line),
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  design.tones[i],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const Spacer(),
                        const Text(
                          '쓰는 인간 · 모양과 색은 각각 선택',
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/images/ink-mark-bleed.png'),
          key.currentContext!,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final rendered =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
        await Directory('artifacts').create(recursive: true);
        await File(
          'artifacts/book-detail-elements-${kind.name}.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        rendered.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    debugDisableShadows = shadows;
  });

  testWidgets('Render new elements inside the ordinary application', (
    tester,
  ) async {
    final shadows = debugDisableShadows;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = shadows);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      for (final font in [
        [
          'WritingHumanDevelopment',
          'assets/fonts/WritingHumanDevelopment-Regular.ttf',
        ],
        ['NanumMyeongjo', 'assets/fonts/NanumMyeongjo-Regular.ttf'],
        ['NanumGothic', 'assets/fonts/NanumGothic-Regular.ttf'],
        ['MaterialIcons', 'fonts/MaterialIcons-Regular.otf'],
        [
          'packages/cupertino_icons/CupertinoIcons',
          'packages/cupertino_icons/assets/CupertinoIcons.ttf',
        ],
      ]) {
        await (FontLoader(font[0])..addFont(rootBundle.load(font[1]))).load();
      }
    });
    final key = GlobalKey();
    final store = DemoStore();
    final library = await store.load();
    final book = library.books.first;
    final details = library.style.bookDetails
        .withChoice(
          BookDetailKind.recordDivider,
          const BookDetailChoice(variant: 2),
        )
        .withChoice(
          BookDetailKind.pressedFlower,
          const BookDetailChoice(variant: 1, tone: 1),
        );
    await store.save(
      library.copy(
        records: [
          ...library.records,
          WritingRecord(
            id: 'render-record',
            bookId: book.id,
            title: '다시 꺼낸 문장',
          ),
        ],
        pages: [
          ...library.pages,
          const WritingPage(
            id: 'render-page',
            recordId: 'render-record',
            number: 1,
            text: '오래 곁에 둔 문장은 다시 읽을 때 달라진다.',
          ),
        ],
        style: library.style.copy(bookDetails: details),
      ),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: WritingHumanApp(store: store),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (final name in [
        'cotton-paper.jpg',
        'ink-mark-bleed.png',
        'linen-cover.webp',
        'ivory-linen-cover.webp',
        'blue-linen-cover.webp',
      ]) {
        await precacheImage(
          AssetImage('assets/images/$name'),
          key.currentContext!,
        );
      }
    });
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      expect(find.textContaining('예시'), findsNothing);
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('artifacts').create(recursive: true);
        await File(
          'artifacts/book-details-elements-$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('writing');
    await tester.tap(find.byKey(const ValueKey('writing-originals')));
    await tester.pumpAndSettle();
    await capture('source');
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('보관함'));
    await tester.pumpAndSettle();
    await capture('shelf');
    await tester.tap(find.byKey(ValueKey('shelf-details-${book.id}')));
    await tester.pumpAndSettle();
    await capture('bookplate');
    await tester.scrollUntilVisible(
      find.byType(RecordDivider),
      160,
      scrollable: find
          .descendant(
            of: find.byType(CollectionSheet),
            matching: find.byType(Scrollable),
          )
          .last,
    );
    await tester.pumpAndSettle();
    await capture('records');
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('쓰기 도구'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('책의 디테일'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('책의 디테일'));
    await tester.pumpAndSettle();
    await capture('settings');
    for (final enabled in [false, true]) {
      final coverDetails = details.withChoice(
        BookDetailKind.pressedFlower,
        BookDetailChoice(enabled: enabled, placement: 2, tone: 1),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: appFontFamily),
          home: RepaintBoundary(
            key: key,
            child: Scaffold(
              body: Column(
                children: [
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (
                        var variant = 0;
                        variant < coverNames.length;
                        variant++
                      )
                        BookCover(
                          title: variant == 1
                              ? '첫 문장'
                              : '오래 곁에 두고 싶은 문장들의 필사 노트',
                          variant: variant,
                          width: 106,
                          bookmarked: variant == 0,
                          pageCount: 12,
                          details: coverDetails,
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: BookFrontCover(
                      title: '오래 곁에 두고 싶은 문장들의 필사 노트',
                      author: '쓰는 사람',
                      style: WritingStyle(bookDetails: coverDetails),
                      pageCount: 12,
                      onOpen: () {},
                      onCollection: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture(enabled ? 'cover-on' : 'cover-off');
    }

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    debugDisableShadows = shadows;
  });
}
