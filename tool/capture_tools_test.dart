// Explicit synthetic data, Flutter test renderer; not a device/browser capture.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/data/demo_store.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/main.dart';
import 'package:writing_human/ui/tools_screen.dart';

void main() {
  testWidgets('Capture the paper specimen and contextual writing tools', (
    tester,
  ) async {
    final shadows = debugDisableShadows;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = shadows);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.runAsync(() async {
      for (final entry in {
        'WritingHumanDevelopment':
            'assets/fonts/WritingHumanDevelopment-Regular.ttf',
        'NanumMyeongjo': 'assets/fonts/NanumMyeongjo-Regular.ttf',
        'NanumGothic': 'assets/fonts/NanumGothic-Regular.ttf',
        'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
        'packages/cupertino_icons/CupertinoIcons':
            'packages/cupertino_icons/assets/CupertinoIcons.ttf',
      }.entries) {
        await (FontLoader(
          entry.key,
        )..addFont(rootBundle.load(entry.value))).load();
      }
    });
    final store = DemoStore();
    await store.save(const Library());
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: WritingHumanApp(store: store),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('쓰기 도구'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/images/cotton-paper.jpg'),
        boundary.currentContext!,
      );
      await precacheImage(
        const AssetImage('assets/images/ink-mark-bleed.png'),
        boundary.currentContext!,
      );
    });
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final target = File('output/tools-eraser-top-20261121/$name.png');
        await target.parent.create(recursive: true);
        await target.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('pen-390');
    await tester.tap(
      find.byKey(const ValueKey('choose-paper-tool-highlighter')),
    );
    await tester.pumpAndSettle();
    await capture('highlighter-390');
    final erase = find.byKey(const ValueKey('choose-paper-tool-eraser'));
    await tester.ensureVisible(erase);
    await tester.tap(erase);
    await tester.pumpAndSettle();
    await capture('eraser-390');
    await tester.tap(
      find.byKey(const ValueKey('choose-paper-tool-highlighter')),
    );
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('tool-paper-specimen')),
    );
    await tester.pumpAndSettle();
    await capture('highlighter-320');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: WritingHumanApp(store: store),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('쓰기 도구'));
    await tester.pumpAndSettle();
    final highlighter = find.byKey(
      const ValueKey('choose-paper-tool-highlighter'),
    );
    await tester.ensureVisible(highlighter);
    await tester.tap(highlighter);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('tool-paper-specimen')),
    );
    await tester.pumpAndSettle();
    expect(
      MediaQuery.textScalerOf(
        tester.element(find.byType(ToolsScreen)),
      ).scale(20),
      40,
    );
    final rich = find.descendant(
      of: find.byKey(const ValueKey('tool-specimen-text')),
      matching: find.byType(RichText),
    );
    expect(tester.widget<RichText>(rich).textScaler.scale(20), 40);
    await capture('large-text-specimen-320');
    await tester.ensureVisible(erase);
    await tester.pumpAndSettle();
    await capture('large-text-controls-320');
    debugDisableShadows = shadows;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
