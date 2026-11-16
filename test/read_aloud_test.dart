import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/audio/read_aloud.dart';
import 'package:writing_human/ui/paper.dart';
import 'package:writing_human/ui/read_aloud_screen.dart';

class _Speech implements ReadAloud {
  final spoken = <String>[];
  Completer<void>? pending;
  int stops = 0;
  bool voiceAvailable = true;

  @override
  Future<void> speak(String text) async {
    if (!voiceAvailable) throw const KoreanVoiceUnavailable();
    spoken.add(text);
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

Future<void> _open(WidgetTester tester, _Speech speech) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: ReadAloudScreen(
                    speech: speech,
                    color: paper,
                    bookTitle: '검수용 책',
                    current: (number: 3, text: '셋째 쪽입니다.'),
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
    final phrases = readAloudPhrases(text).toList();
    expect(phrases.first, opening);
    expect(phrases.every((phrase) => phrase.length <= 180), isTrue);
    expect(
      phrases.join().replaceAll(RegExp(r'\s'), ''),
      text.replaceAll(RegExp(r'\s'), ''),
    );
  });

  testWidgets('현재 쪽은 따로 읽고 책 전체는 쪽 순서로 기다려 읽는다', (tester) async {
    final speech = _Speech();
    await _open(tester, speech);

    await tester.tap(find.text('재생'));
    await tester.pump();
    expect(speech.spoken, ['셋째 쪽입니다.']);
    expect(find.text('3쪽 재생 중'), findsOneWidget);
    speech.finish();
    await tester.pumpAndSettle();
    expect(find.text('낭독을 마쳤어요.'), findsOneWidget);

    await tester.tap(find.text('책 전체'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('재생'));
    await tester.pump();
    expect(speech.spoken, ['셋째 쪽입니다.', '첫 쪽입니다.']);
    expect(find.text('1쪽 재생 중'), findsOneWidget);

    speech.finish();
    await tester.pump();
    expect(speech.spoken, ['셋째 쪽입니다.', '첫 쪽입니다.', '셋째 쪽입니다.']);
    expect(find.text('3쪽 재생 중'), findsOneWidget);
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

  testWidgets('설치된 한국어 음성이 없으면 안내하고 재시도할 수 있다', (tester) async {
    final speech = _Speech()..voiceAvailable = false;
    await _open(tester, speech);
    await tester.tap(find.text('재생'));
    await tester.pumpAndSettle();
    expect(find.textContaining('한국어 음성이 없어요'), findsOneWidget);
    speech.voiceAvailable = true;
    await tester.tap(find.text('재생'));
    await tester.pump();
    expect(speech.spoken, ['셋째 쪽입니다.']);
    speech.finish();
    await tester.pumpAndSettle();
  });
}
