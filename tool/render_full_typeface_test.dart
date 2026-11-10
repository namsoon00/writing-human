// Actual bundled TTF in the Flutter test rasterizer, not a device screenshot.
// flutter test tool/render_full_typeface_test.dart --no-pub
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/ui/paper.dart';

const _ink = Color(0xff302c27);
const _paper = Color(0xfff7f2e8);
const _reading =
    '꽃잎이 책갈피 사이에 남아 있었다. 오래전에 읽은 문장을 다시 옮겨 적는다. '
    '괜찮다. 서두르지 않아도 된다. 흙을 밟고 돌아온 마음이 종이 위에서 조금씩 고요해진다.\n\n'
    '값진 하루는 작은 기록으로 남는다. 2026년 11월 10일, 오늘도 한 페이지를 쓴다.';

Size paintText(
  Canvas canvas,
  String text,
  Offset offset,
  double width,
  double size, {
  String family = developmentSerif,
  double height = 1.9,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: family,
        fontSize: size,
        height: height,
        color: _ink,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: width);
  painter.paint(canvas, offset);
  final result = painter.size;
  painter.dispose();
  return result;
}

Future<void> render(
  WidgetTester tester,
  String filename,
  Size size,
  void Function(Canvas) paint,
) async {
  await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(3);
    canvas.drawColor(_paper, BlendMode.src);
    paint(canvas);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (size.width * 3).round(),
      (size.height * 3).round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final output = File('artifacts/typeface/v006/$filename.png');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });
}

void main() {
  testWidgets('Render full coverage font at actual reading sizes', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await (FontLoader(developmentSerif)..addFont(
            rootBundle.load('assets/fonts/WritingHumanDevelopment-Regular.ttf'),
          ))
          .load();
      await (FontLoader('NanumGothic')
            ..addFont(rootBundle.load('assets/fonts/NanumGothic-Regular.ttf')))
          .load();
    });
    for (final size in [18.0, 23.0]) {
      await render(tester, 'reading-${size.round()}', const Size(390, 844), (
        canvas,
      ) {
        paintText(canvas, '쓰는 인간', const Offset(32, 30), 326, 26);
        paintText(
          canvas,
          '전체 문자 개발판 · Flutter 렌더 · ${size.round()}px',
          const Offset(32, 90),
          326,
          11,
          family: 'NanumGothic',
        );
        final textSize = paintText(
          canvas,
          _reading,
          const Offset(32, 145),
          326,
          size,
        );
        expect(textSize.height + 145, lessThan(790));
      });
    }
    await render(tester, 'sizes-flutter', const Size(1050, 1180), (canvas) {
      paintText(
        canvas,
        '쓰는 인간체 0.006 / 실제 번들 TTF / Flutter 테스트 렌더',
        const Offset(45, 30),
        960,
        17,
        family: 'NanumGothic',
      );
      var y = 100.0;
      for (final size in [14.0, 18.0, 23.0, 32.0, 42.0]) {
        paintText(
          canvas,
          '${size.round()}px',
          Offset(45, y),
          75,
          13,
          family: 'NanumGothic',
        );
        paintText(canvas, '값싼 흙과 꽃잎, 괜찮다. 똠뷁힣', Offset(130, y), 875, size);
        y += size * 2 + 30;
      }
      for (final line in [
        'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
        'abcdefghijklmnopqrstuvwxyz 0123456789',
        'Writing Human — Paper & Ink. ₩12,345',
        '읽 앉 맑 닭 삶 값 읊 흙 왜 외 웨 위 의',
        '“오늘의 문장” ‘쉼’ … 「기록」 『책』',
        'ㄱ ㄳ ㄵ ㄺ ㄿ ㅄ ㅏ ㅒ ㅘ ㅙ ㅞ ㅢ',
      ]) {
        paintText(canvas, line, Offset(45, y), 960, 28);
        y += 70;
      }
      expect(y, lessThan(1180));
    });
  });
}
