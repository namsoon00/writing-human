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
      expect(effect.loops, isTrue);
      expect(effect.volume, 1);
      expect(PaperSoundEffect.pageTurn.loops, isFalse);
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
