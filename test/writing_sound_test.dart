import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/ui/paper_sound_effect.dart';
import 'package:writing_human/ui/writing_sound.dart';

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
  int plays = 0, pauses = 0, closes = 0;

  @override
  void play(PaperSoundRequest request) {
    if (request.canPlay) plays++;
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

  test(
    'Writing loads the selected original pencil recording and page turns stay one-shot',
    () async {
      final effect = PaperSoundEffect.writingRhythm;
      final info =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/audio/pencil-on-paper-original-info.json',
                ),
              )
              as Map<String, dynamic>;
      expect(info['source_video_id'], 'KxVtZQxxA1s');
      final processing = info['processing'] as Map<String, dynamic>;
      final wav = await rootBundle.load('assets/${effect.asset}');
      // The bundled PCM file uses a standard 44-byte WAV header.
      final byteRate = wav.getUint32(28, .little);
      final pcmLength = wav.getUint32(40, .little);
      expect(pcmLength, wav.lengthInBytes - 44);
      final duration = Duration(microseconds: pcmLength * 1000000 ~/ byteRate);
      expect(
        duration.inMicroseconds,
        closeTo((processing['duration_seconds'] as num) * 1000000, 1),
      );
      expect(
        sha256
            .convert(
              wav.buffer.asUint8List(wav.offsetInBytes, wav.lengthInBytes),
            )
            .toString(),
        processing['asset_sha256'],
      );
      expect(wav.getUint16(20, .little), 1);
      expect(wav.getUint16(22, .little), 1);
      expect(wav.getUint32(24, .little), 44100);
      expect(wav.getUint16(34, .little), 16);
      // A short gesture must reach an actual pencil stroke, not the quiet lead-in.
      final firstSample = writingPencilLeadIn.inMicroseconds * 44100 ~/ 1000000;
      final sampleCount = writingRhythmIdle.inMicroseconds * 44100 ~/ 1000000;
      var energy = 0.0;
      for (var i = firstSample; i < firstSample + sampleCount; i++) {
        final value = wav.getInt16(44 + i * 2, .little) / 32768;
        energy += value * value;
      }
      expect(energy / sampleCount, greaterThan(.0001));
      expect(effect.loops, isTrue);
      expect(effect.volume, 1);
      expect(PaperSoundEffect.pageTurn.loops, isFalse);
    },
  );

  testWidgets(
    'One letter ends its writing activity within 120ms, without a later replay',
    (tester) async {
      final playback = _Playback();
      final sound = PaperSound.writing(playback: playback);
      sound.play(() => true);
      expect(playback.plays, 1);
      await tester.pump(const Duration(milliseconds: 119));
      expect(playback.pauses, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(playback.pauses, 1);
      await tester.pump(const Duration(seconds: 4));
      expect(playback.plays, 1);
      expect(playback.pauses, 1);
      await sound.dispose();
      expect(playback.closes, 1);
    },
  );

  testWidgets(
    'Only actual new input extends the short gesture; exit cancels it',
    (tester) async {
      final playback = _Playback();
      final sound = PaperSound.writing(playback: playback);
      sound.play(() => false);
      expect(playback.plays, 0);
      sound.play(() => true);
      await tester.pump(const Duration(milliseconds: 80));
      sound.play(() => true);
      await tester.pump(const Duration(milliseconds: 80));
      expect(playback.pauses, 0);
      await tester.pump(const Duration(milliseconds: 40));
      expect(playback.plays, 2);
      expect(playback.pauses, 1);
      sound.play(() => true);
      await sound.dispose();
      await tester.pump(const Duration(seconds: 4));
      expect(playback.plays, 3);
      expect(playback.pauses, 1);
      expect(playback.closes, 1);
    },
  );

  test('Each new letter or syllable requests one stroke', () {
    final cases = [
      (input('', 0), input('ㅎ', 1, const TextRange(start: 0, end: 1)), true),
      (
        input('ㅎ', 1, const TextRange(start: 0, end: 1)),
        input('한', 1, const TextRange(start: 0, end: 1)),
        false,
      ),
      (input('한', 1, const TextRange(start: 0, end: 1)), input('한', 1), false),
      (
        input('한', 1, const TextRange(start: 0, end: 1)),
        input('한ㄱ', 2, const TextRange(start: 1, end: 2)),
        true,
      ),
      (input('한ㄱ', 2, const TextRange(start: 1, end: 2)), input('한', 1), false),
      (
        input('가다', 1),
        input('가ㄴ다', 2, const TextRange(start: 1, end: 2)),
        true,
      ),
      (
        input('가ㄴ다', 2, const TextRange(start: 1, end: 2)),
        input('가나다', 2),
        false,
      ),
      (input('가다', 1), input('가나다', 2), true),
      (input('', 0), input('글을 붙여 넣는다', 9), false),
      (input('가', 1), input('가 ', 2), false),
      (input('가', 1), input('가\n', 2), false),
      (input('가나다', 2), input('가다', 1), false),
      (input('가나다', 2), input('가나다', 1), false),
    ];
    for (final (before, after, sounds) in cases) {
      expect(
        hasNewWrittenCharacter(before, after),
        sounds,
        reason: '$before → $after',
      );
    }
  });
}
