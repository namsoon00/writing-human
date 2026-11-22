import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/audio/read_aloud.dart';
import 'package:writing_human/ui/paper.dart';
import 'package:writing_human/ui/read_aloud_screen.dart';

class _Speech implements BrandReadAloud {
  final spoken = <String>[];
  final following = <String?>[];
  Completer<void>? pending;
  int stops = 0;
  bool voiceAvailable = true;

  @override
  Future<void> speak(String text, {String? next}) async {
    if (!voiceAvailable) throw StateError('voice unavailable');
    spoken.add(text);
    following.add(next);
    final utterance = pending = Completer<void>();
    await utterance.future;
  }

  void finish() => pending!.complete();

  @override
  Future<void> stop() async {
    stops++;
    // Model a platform that never finishes the interrupted request.
  }
}

Future<void> _open(
  WidgetTester tester,
  _Speech speech, {
  NarrationFactory? brandSpeech,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: ReadAloudScreen(
                    createSpeech: brandSpeech ?? ((_) => speech),
                    color: paper,
                    bookTitle: '검수용 책',
                    current: (number: 3, text: '셋째 쪽입니다.\n다음 문장입니다.'),
                    pages: const [
                      (number: 1, text: '첫 쪽입니다.'),
                      (number: 3, text: '셋째 쪽입니다.'),
                    ],
                  ),
                ),
              ),
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

void main() {
  test('긴 본문을 나누어도 문자와 문장 순서가 유지된다', () {
    final opening = '${List.filled(40, '첫 문장 ').join().substring(0, 101)}.';
    final longWord = List.filled(200, '한').join();
    final text = '$opening\n$longWord👩🏽‍💻 끝';
    final phrases = readAloudPhrases(
      text,
    ).map((phrase) => phrase.text).toList();
    expect(phrases.first, opening);
    expect(phrases.every((phrase) => phrase.length <= 180), isTrue);
    expect(
      phrases.join().replaceAll(RegExp(r'\s'), ''),
      text.replaceAll(RegExp(r'\s'), ''),
    );
  });

  test('연 안에서 줄바꿈을 보존하고 연 사이에는 호흡을 둔다', () {
    final phrases = readAloudPhrases(
      '\n“달이 떴나요?” 별이 떴다.\r\n바람이 불었다.\r\n \r\n다시 밤이 온다.',
    ).toList();
    expect(phrases.map((part) => part.text), [
      '“달이 떴나요?” 별이 떴다.\n바람이 불었다.',
      '다시 밤이 온다.',
    ]);
    expect(phrases[0].pauseBefore, Duration.zero);
    expect(phrases[1].pauseBefore, greaterThan(Duration.zero));
    expect(phrases[1].pauseBefore, const Duration(milliseconds: 480));
  });

  test('긴 인용문은 닫는 따옴표까지 한 호흡으로 묶는다', () {
    final quote = '“${List.filled(50, '가나 ').join().trim()}?”';
    final continuation = List.filled(90, '다라 ').join().trim();
    final phrases = readAloudPhrases('$quote $continuation');
    expect(phrases.first.text, quote);
    expect(phrases.first.pauseBefore, Duration.zero);
    expect(
      phrases.skip(1).every((part) => part.pauseBefore > Duration.zero),
      isTrue,
    );
  });

  testWidgets('현재 쪽은 따로 읽고 책 전체는 쪽 순서로 기다려 읽는다', (tester) async {
    final speech = _Speech();
    await _open(tester, speech);

    await tester.tap(find.text('재생'));
    await tester.pump();
    expect(speech.spoken, ['셋째 쪽입니다.\n다음 문장입니다.']);
    expect(find.text('3쪽 낭독 중'), findsOneWidget);
    speech.finish();
    await tester.pumpAndSettle();
    expect(find.text('낭독을 마쳤어요.'), findsOneWidget);

    await tester.tap(find.text('책 전체'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('재생'));
    await tester.pump();
    expect(speech.spoken, ['셋째 쪽입니다.\n다음 문장입니다.', '첫 쪽입니다.']);
    expect(find.text('1쪽 낭독 중'), findsOneWidget);

    speech.finish();
    await tester.pump();
    expect(speech.spoken, ['셋째 쪽입니다.\n다음 문장입니다.', '첫 쪽입니다.']);
    await tester.pump(readAloudPagePause);
    expect(speech.spoken, ['셋째 쪽입니다.\n다음 문장입니다.', '첫 쪽입니다.', '셋째 쪽입니다.']);
    expect(find.text('3쪽 낭독 중'), findsOneWidget);
    speech.finish();
    await tester.pumpAndSettle();
  });

  testWidgets('정지나 닫기 뒤에는 다음 쪽이 재생되지 않는다', (tester) async {
    final speech = _Speech();
    await _open(tester, speech);
    await tester.tap(find.text('책 전체'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('재생'));
    await tester.pump();
    await tester.tap(find.text('정지'));
    await tester.pumpAndSettle();
    speech.finish();
    await tester.pumpAndSettle();
    expect(speech.spoken, ['첫 쪽입니다.']);
    expect(speech.stops, 1);

    await tester.tap(find.text('재생'));
    await tester.pump();
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    speech.finish();
    await tester.pumpAndSettle();
    expect(speech.spoken, ['첫 쪽입니다.', '첫 쪽입니다.']);
    expect(speech.stops, 2);
  });

  testWidgets('쪽 사이에 쉬는 동안 정지하면 다음 쪽은 재생되지 않는다', (tester) async {
    final speech = _Speech();
    await _open(tester, speech);
    await tester.tap(find.text('책 전체'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('재생'));
    await tester.pump();

    speech.finish();
    await tester.pump();
    await tester.tap(find.text('정지'));
    await tester.pump(readAloudPagePause);
    expect(speech.spoken, ['첫 쪽입니다.']);
    expect(speech.stops, 1);
  });

  testWidgets('음성 준비에 실패하면 다른 음색 없이 재시도할 수 있다', (tester) async {
    final speech = _Speech()..voiceAvailable = false;
    await _open(tester, speech);
    await tester.tap(find.text('재생'));
    await tester.pumpAndSettle();
    expect(find.textContaining('낭독을 재생하지 못했어요'), findsOneWidget);
    speech.voiceAvailable = true;
    await tester.tap(find.text('재생'));
    await tester.pump();
    expect(speech.spoken, ['셋째 쪽입니다.\n다음 문장입니다.']);
    speech.finish();
    await tester.pumpAndSettle();
  });

  testWidgets('선택한 여성 목소리 하나로 쪽과 책을 읽고 음색 선택은 제공하지 않는다', (tester) async {
    final female = _Speech();
    late ValueChanged<double?> reportProgress;
    var creations = 0;
    await _open(
      tester,
      female,
      brandSpeech: (progress) {
        creations++;
        reportProgress = progress;
        return female;
      },
    );
    expect(find.text('여성 F3'), findsNothing);
    expect(find.text('남성 M2'), findsNothing);
    expect(find.text('기기 음성'), findsNothing);
    expect(find.text('따뜻한 여성 목소리로 읽어요.'), findsOneWidget);
    expect(find.textContaining('약 106MB'), findsOneWidget);
    expect(female.spoken, isEmpty);
    await tester.tap(find.text('재생'));
    await tester.pump();
    expect(female.spoken, ['셋째 쪽입니다.\n다음 문장입니다.']);
    reportProgress(.43);
    await tester.pump();
    expect(find.text('음성 모델 준비 중 · 43%'), findsOneWidget);
    await tester.tap(find.text('정지'));
    await tester.pumpAndSettle();
    female.finish();
    await tester.pumpAndSettle();
    expect(female.stops, 1);
    await tester.tap(find.text('책 전체'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('재생'));
    await tester.pump();
    expect(female.spoken.last, '첫 쪽입니다.');
    expect(female.following.last, '셋째 쪽입니다.');
    expect(creations, 2);
    await tester.tap(find.text('정지'));
    await tester.pumpAndSettle();
    female.finish();
  });
}
