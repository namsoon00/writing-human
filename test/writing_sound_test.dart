import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
  test('Only a newly written character requests a stroke', () {
    final cases = [
      (input('', 0), input('ㅎ', 1, const TextRange(start: 0, end: 1)), false),
      (
        input('ㅎ', 1, const TextRange(start: 0, end: 1)),
        input('한', 1, const TextRange(start: 0, end: 1)),
        false,
      ),
      (input('한', 1, const TextRange(start: 0, end: 1)), input('한', 1), true),
      (
        input('한', 1, const TextRange(start: 0, end: 1)),
        input('한ㄱ', 2, const TextRange(start: 1, end: 2)),
        true,
      ),
      (input('한ㄱ', 2, const TextRange(start: 1, end: 2)), input('한', 1), false),
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
