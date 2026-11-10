import 'dart:convert';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/ui/paper.dart';

Future<Uint8List> pixels(String family, String text) async {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: family,
        fontFamilyFallback: const [serif],
        fontSize: 32,
        color: Colors.black,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..drawColor(Colors.white, BlendMode.src);
  painter.paint(
    canvas,
    Offset(
      10,
      64 - painter.computeDistanceToActualBaseline(TextBaseline.alphabetic),
    ),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(400, 100);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final result = Uint8List.fromList(data!.buffer.asUint8List());
  painter.dispose();
  image.dispose();
  picture.dispose();
  return result;
}

void main() {
  testWidgets(
    'Real bundled glyphs differ and unsupported text uses Nanum fallback',
    (tester) async {
      await tester.runAsync(() async {
        final bytes = await rootBundle.load(
          'assets/fonts/WritingHumanDevelopment-Regular.ttf',
        );
        final info =
            jsonDecode(
                  await rootBundle.loadString(
                    'assets/fonts/WritingHumanDevelopment-info.json',
                  ),
                )
                as Map<String, dynamic>;
        expect(info['status'], 'development-partial-font');
        expect(
          sha256
              .convert(
                bytes.buffer.asUint8List(
                  bytes.offsetInBytes,
                  bytes.lengthInBytes,
                ),
              )
              .toString(),
          info['font_sha256'],
        );
        await (FontLoader(developmentSerif)..addFont(
              rootBundle.load(
                'assets/fonts/WritingHumanDevelopment-Regular.ttf',
              ),
            ))
            .load();
        await (FontLoader(serif)..addFont(
              rootBundle.load('assets/fonts/NanumMyeongjo-Regular.ttf'),
            ))
            .load();
        // All these characters are deliberately absent from the 111-glyph proof.
        const unsupported = '똠뷁힣ABC2026';
        expect(
          await pixels(developmentSerif, unsupported),
          orderedEquals(await pixels(serif, unsupported)),
        );
        // Detect an accidental alias to Nanum or a missing custom asset load.
        expect(
          await pixels(developmentSerif, '쓰는인간'),
          isNot(orderedEquals(await pixels(serif, '쓰는인간'))),
        );
      });
    },
  );
}
