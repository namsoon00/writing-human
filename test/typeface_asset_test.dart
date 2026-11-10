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
    'Full Hangul asset shapes NFC and NFD and preserves Nanum fallback',
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
        expect(info['status'], 'development-full-coverage');
        expect(info['hangul_syllables'], 11172);
        final covered = (info['characters'] as String).runes.toSet();
        for (var rune = 0xAC00; rune <= 0xD7A3; rune++) {
          expect(covered, contains(rune));
        }
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
        // Present in Nanum, outside this font's declared coverage.
        const unsupported = '©™←';
        expect(unsupported.runes.any(covered.contains), isFalse);
        expect(
          await pixels(developmentSerif, unsupported),
          orderedEquals(await pixels(serif, unsupported)),
        );
        // Detect fallback replacing newly supported syllables, Latin or digits.
        for (final text in ['쓰는인간', '똠뷁힣', 'ABCxyz', '2026', 'ㄳㅞ']) {
          expect(
            await pixels(developmentSerif, text),
            isNot(orderedEquals(await pixels(serif, text))),
            reason: text,
          );
        }
        const composed = '꽃값힣';
        final decomposed = String.fromCharCodes([
          for (final rune in composed.runes) ...[
            0x1100 + (rune - 0xAC00) ~/ 588,
            0x1161 + (rune - 0xAC00) % 588 ~/ 28,
            if ((rune - 0xAC00) % 28 != 0) 0x11A7 + (rune - 0xAC00) % 28,
          ],
        ]);
        expect(
          await pixels(developmentSerif, decomposed),
          orderedEquals(await pixels(developmentSerif, composed)),
        );
      });
    },
  );
}
