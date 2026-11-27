import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/ui/handwriting_strokes.dart';
import 'package:writing_human/ui/paper_sound_effect.dart';
import 'package:writing_human/ui/writing_sound.dart';

const short = PaperSoundEffect.pencilShort;
const straight = PaperSoundEffect.pencilStraight;
const sweep = PaperSoundEffect.pencilSweep;
const bend = PaperSoundEffect.pencilBend;

TextEditingValue input(
  String text,
  int caret, [
  TextRange range = TextRange.empty,
]) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: caret),
  composing: range,
);

class _Playback implements PaperSoundPlayback {
  final played = <PaperSoundEffect>[];
  int pauses = 0, closes = 0;

  @override
  void play(PaperSoundRequest request) {
    if (request.canPlay) played.add(request.effect);
  }

  @override
  void pause() {
    pauses++;
  }

  @override
  Future<void> dispose() async {
    closes++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Contacts preserve the chosen recording at its original speed', (
    tester,
  ) async {
    await tester.runAsync(() async {
      const source = 'assets/audio/pencil-on-paper-original';
      final info =
          jsonDecode(await rootBundle.loadString('$source-info.json'))
              as Map<String, dynamic>;
      final original = await rootBundle.load('$source.wav');
      final pcm = original.buffer.asUint8List(
        original.offsetInBytes,
        original.lengthInBytes,
      );
      expect(info['source_video_id'], 'KxVtZQxxA1s');
      expect(
        sha256.convert(pcm).toString(),
        info['processing']['asset_sha256'],
      );

      const startSamples = {
        short: 145839,
        straight: 108706,
        sweep: 249430,
        bend: 53890,
      };
      expect(
        startSamples.keys,
        unorderedEquals(PaperSoundEffect.pencilContacts),
      );
      for (final entry in startSamples.entries) {
        final effect = entry.key;
        final clip = await rootBundle.load('assets/${effect.asset}');
        final sampleCount = (clip.lengthInBytes - 44) ~/ 2;
        expect(clip.getUint16(20, .little), 1); // PCM
        expect(clip.getUint16(22, .little), 1); // mono
        expect(clip.getUint32(24, .little), 44100);
        expect(clip.getUint16(34, .little), 16);
        expect(clip.getUint32(40, .little), sampleCount * 2);
        expect(
          sampleCount * 1000 / 44100,
          closeTo(effect.interval.inMilliseconds, .04),
        );
        expect(clip.getInt16(44, .little), 0);
        expect(clip.getInt16(clip.lengthInBytes - 2, .little), 0);

        var squaredAmplitude = 0;
        for (var i = 0; i < sampleCount; i++) {
          final sample = clip.getInt16(44 + i * 2, .little);
          squaredAmplitude += sample * sample;
        }
        expect(math.sqrt(squaredAmplitude / sampleCount), greaterThan(280));

        const firstAfterAttack = 400;
        final referenceStep =
            clip.getInt16(44 + (firstAfterAttack + 1) * 2, .little) -
            clip.getInt16(44 + firstAfterAttack * 2, .little);
        final originalIndex = 44 + (entry.value + firstAfterAttack) * 2;
        final originalStep =
            original.getInt16(originalIndex + 2, .little) -
            original.getInt16(originalIndex, .little);
        expect(referenceStep, closeTo(originalStep * .84, 1));
      }
    });
  }, skip: kIsWeb);

  test('Each modern Hangul syllable has the constituent stroke counts', () {
    const initialCounts = [
      1,
      2,
      1,
      2,
      4,
      3,
      3,
      4,
      8,
      2,
      4,
      1,
      2,
      4,
      3,
      2,
      3,
      4,
      3,
    ];
    const vowelCounts = [
      2,
      3,
      3,
      4,
      2,
      3,
      3,
      4,
      2,
      4,
      5,
      3,
      3,
      2,
      4,
      5,
      3,
      3,
      1,
      2,
      1,
    ];
    const finalCounts = [
      0,
      1,
      2,
      3,
      1,
      3,
      4,
      2,
      3,
      4,
      6,
      7,
      5,
      6,
      7,
      6,
      3,
      4,
      6,
      2,
      4,
      1,
      2,
      3,
      2,
      3,
      4,
      3,
    ];
    expect(newWritingStrokes(input('', 0), input('가', 1)), [
      bend,
      straight,
      short,
    ]);
    expect(newWritingStrokes(input('', 0), input('다', 1)), [
      straight,
      bend,
      straight,
      short,
    ]);
    expect(newWritingStrokes(input('', 0), input('글', 1)), [
      bend,
      sweep,
      bend,
      short,
      sweep,
    ]);
    for (var index = 0; index <= 0xd7a3 - 0xac00; index++) {
      final syllable = String.fromCharCode(0xac00 + index);
      final count =
          initialCounts[index ~/ (21 * 28)] +
          vowelCounts[index ~/ 28 % 21] +
          finalCounts[index % 28];
      expect(
        newWritingStrokes(input('', 0), input(syllable, 1)).length,
        count,
        reason: syllable,
      );
    }
  });

  test('IME appends contacts only for the new jamo across edits', () {
    const first = TextRange(start: 0, end: 1);
    const second = TextRange(start: 1, end: 2);
    final cases = [
      (input('', 0), input('ㄱ', 1, first), [bend]),
      (input('ㄱ', 1, first), input('가', 1, first), [straight, short]),
      (input('가', 1, first), input('가', 1), <PaperSoundEffect>[]),
      (input('가', 1, first), input('간', 1, first), [bend]),
      (input('간', 1, first), input('가나', 2, second), [straight, short]),
      (input('간', 1, first), input('가ㄴ', 2, second), <PaperSoundEffect>[]),
      (input('갑', 1, first), input('값', 1, first), [sweep, straight]),
      (input('값', 1, first), input('갑사', 2, second), [straight, short]),
      (input('고', 1, first), input('과', 1, first), [straight, short]),
      (input('가ㄱ', 2), input('가가', 2), [straight, short]),
      (input('앞간뒤', 2), input('앞가나뒤', 3), [straight, short]),
      (input('고', 1), input('과', 1), [straight, short]),
      (input('간', 1), input('가', 1), <PaperSoundEffect>[]),
      (input('가', 1), input('다', 1), <PaperSoundEffect>[]),
      (input('a', 1), input('가', 1), <PaperSoundEffect>[]),
      (input('한', 1, first), input('한ㄱ', 2, second), [bend]),
      (input('간', 1, first), input('가', 1, first), <PaperSoundEffect>[]),
      (input('간', 1, first), input('갇', 1, first), <PaperSoundEffect>[]),
      (input('가다', 1), input('가ㄴ다', 2, second), [bend]),
      (input('가ㄴ다', 2, second), input('가나다', 2), [straight, short]),
      (input('', 0), input('가', 2), [bend, straight, short]),
      (input('가다', 1), input('가a다', 2), [short]),
      (input('', 0), input('복사한 글', 5), <PaperSoundEffect>[]),
      (input('가', 1), input('가 ', 2), <PaperSoundEffect>[]),
      (input('가', 1), input('가\n', 2), <PaperSoundEffect>[]),
      (input('가', 1, first), input('가\n', 2), <PaperSoundEffect>[]),
      (input('가나다', 2), input('가다', 1), <PaperSoundEffect>[]),
      (input('가나다', 2), input('가나다', 1), <PaperSoundEffect>[]),
      (
        const TextEditingValue(
          text: '가나다',
          selection: TextSelection(baseOffset: 1, extentOffset: 2),
        ),
        input('가마다', 2),
        [straight, bend, straight, straight, short],
      ),
    ];
    for (final (before, after, strokes) in cases) {
      expect(
        newWritingStrokes(before, after),
        strokes,
        reason: '$before → $after',
      );
    }
  });

  testWidgets('A composing syllable plays in order with a pen-lift gap', (
    tester,
  ) async {
    final playback = _Playback();
    final sound = PaperSound.writing(playback: playback);
    sound.write([bend], () => true);
    expect(playback.played, [bend]);
    await tester.pump(const Duration(milliseconds: 100));
    sound.write([straight, short], () => true);
    await tester.pump(const Duration(milliseconds: 195));
    expect(playback.played, [bend]);
    await tester.pump(const Duration(milliseconds: 1));
    expect(playback.played, [bend, straight]);
    await tester.pump(const Duration(milliseconds: 213));
    expect(playback.played, [bend, straight, short]);
    await tester.pump(const Duration(seconds: 1));
    expect(playback.played, [bend, straight, short]);
    await sound.dispose();
    expect(playback.closes, 1);
  });

  testWidgets(
    'Rapid input catches up at a contact boundary, and blur cancels',
    (tester) async {
      final playback = _Playback();
      final sound = PaperSound.writing(playback: playback);
      sound.write([bend, bend, bend], () => true);
      sound.write([short, sweep], () => true);
      expect(playback.played, [bend]);
      await tester.pump(const Duration(milliseconds: 296));
      expect(playback.played, [bend, short]);
      sound.pause();
      await tester.pump(const Duration(seconds: 2));
      expect(playback.played, [bend, short]);
      expect(playback.pauses, 1);
      sound.write([sweep], () => false);
      expect(playback.played, [bend, short]);
      sound.write([straight, bend], () => true);
      expect(playback.played, [bend, short, straight]);
      await sound.dispose();
      await tester.pump(const Duration(seconds: 2));
      expect(playback.played, [bend, short, straight]);
      expect(playback.closes, 1);
    },
  );
}
