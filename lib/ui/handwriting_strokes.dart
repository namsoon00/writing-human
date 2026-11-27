import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

import 'paper_sound_effect.dart';

const _short = PaperSoundEffect.pencilShort;
const _straight = PaperSoundEffect.pencilStraight;
const _sweep = PaperSoundEffect.pencilSweep;
const _bend = PaperSoundEffect.pencilBend;

// Each item is a continuous pen contact, including turns made on the paper.
const _contacts = <String, List<PaperSoundEffect>>{
  'ㄱ': [_bend],
  'ㄴ': [_bend],
  'ㄷ': [_straight, _bend],
  'ㄹ': [_bend, _short, _sweep],
  'ㅁ': [_straight, _bend, _straight],
  'ㅂ': [_straight, _straight, _short, _short],
  'ㅅ': [_sweep, _straight],
  'ㅇ': [_sweep],
  'ㅈ': [_bend, _straight],
  'ㅊ': [_short, _bend, _straight],
  'ㅋ': [_bend, _short],
  'ㅌ': [_straight, _short, _bend],
  'ㅍ': [_straight, _short, _short, _straight],
  'ㅎ': [_short, _straight, _sweep],
  'ㅏ': [_straight, _short],
  'ㅐ': [_straight, _short, _straight],
  'ㅑ': [_straight, _short, _short],
  'ㅒ': [_straight, _short, _short, _straight],
  'ㅓ': [_short, _straight],
  'ㅔ': [_short, _straight, _straight],
  'ㅕ': [_short, _short, _straight],
  'ㅖ': [_short, _short, _straight, _straight],
  'ㅗ': [_short, _straight],
  'ㅛ': [_short, _short, _straight],
  'ㅜ': [_straight, _short],
  'ㅠ': [_straight, _short, _short],
  'ㅡ': [_sweep],
  'ㅣ': [_straight],
};

const _initials = 'ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ';
const _vowels = 'ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ';
const _finals = ' ㄱㄲㄳㄴㄵㄶㄷㄹㄺㄻㄼㄽㄾㄿㅀㅁㅂㅄㅅㅆㅇㅈㅊㅋㅌㅍㅎ';

// Keep the same parts when the IME moves a final consonant into the next
// syllable (간 → 가나), or combines two keystrokes into one jamo (고 → 과).
const _parts = {
  'ㄲ': 'ㄱㄱ',
  'ㄳ': 'ㄱㅅ',
  'ㄵ': 'ㄴㅈ',
  'ㄶ': 'ㄴㅎ',
  'ㄸ': 'ㄷㄷ',
  'ㄺ': 'ㄹㄱ',
  'ㄻ': 'ㄹㅁ',
  'ㄼ': 'ㄹㅂ',
  'ㄽ': 'ㄹㅅ',
  'ㄾ': 'ㄹㅌ',
  'ㄿ': 'ㄹㅍ',
  'ㅀ': 'ㄹㅎ',
  'ㅃ': 'ㅂㅂ',
  'ㅄ': 'ㅂㅅ',
  'ㅆ': 'ㅅㅅ',
  'ㅉ': 'ㅈㅈ',
  'ㅘ': 'ㅗㅏ',
  'ㅙ': 'ㅗㅐ',
  'ㅚ': 'ㅗㅣ',
  'ㅝ': 'ㅜㅓ',
  'ㅞ': 'ㅜㅔ',
  'ㅟ': 'ㅜㅣ',
  'ㅢ': 'ㅡㅣ',
};

Iterable<String> _jamo(String unit) sync* {
  if (unit.length != 1) {
    final codes = unit.codeUnits;
    if (codes.every((code) => code >= 0x1100 && code <= 0x11c2)) {
      for (final code in codes) {
        yield* _jamo(String.fromCharCode(code));
      }
    } else {
      yield unit;
    }
    return;
  }
  final code = unit.codeUnitAt(0);
  if (code >= 0xac00 && code <= 0xd7a3) {
    final index = code - 0xac00;
    yield* _jamo(_initials[index ~/ (21 * 28)]);
    yield* _jamo(_vowels[index ~/ 28 % 21]);
    final tail = index % 28;
    if (tail != 0) yield* _jamo(_finals[tail]);
    return;
  }
  final letter = switch (code) {
    >= 0x1100 && <= 0x1112 => _initials[code - 0x1100],
    >= 0x1161 && <= 0x1175 => _vowels[code - 0x1161],
    >= 0x11a8 && <= 0x11c2 => _finals[code - 0x11a7],
    _ => unit,
  };
  final parts = _parts[letter];
  if (parts == null) {
    yield letter;
  } else {
    yield* parts.split('');
  }
}

List<PaperSoundEffect> newWritingStrokes(
  TextEditingValue before,
  TextEditingValue after,
) {
  if (before.text == after.text ||
      !after.selection.isValid ||
      !after.selection.isCollapsed ||
      after.selection.end > after.text.length) {
    return const [];
  }

  final wasComposing =
      before.isComposingRangeValid && !before.composing.isCollapsed;
  final composing = after.isComposingRangeValid && !after.composing.isCollapsed;
  final start = wasComposing ? before.composing.start : before.selection.start;
  final oldEnd = wasComposing ? before.composing.end : before.selection.end;
  final newEnd = composing ? after.composing.end : after.selection.end;
  if (start < 0 ||
      oldEnd > before.text.length ||
      (composing && after.composing.start < start) ||
      newEnd <= start ||
      newEnd - start > 24) {
    return const [];
  }

  if (after.text.length - newEnd != before.text.length - oldEnd ||
      !after.text.startsWith(before.text.substring(0, start)) ||
      !after.text.endsWith(before.text.substring(oldEnd))) {
    return const [];
  }
  final inserted = after.text.substring(start, newEnd).characters;
  final previous = wasComposing
      ? before.text.substring(start, oldEnd).characters
      : ''.characters;
  if (inserted.length > previous.length + 1) return const [];

  final oldParts = previous.expand(_jamo).toList();
  final newParts = inserted.expand(_jamo).toList();
  if (oldParts.length >= newParts.length) return const [];
  for (var i = 0; i < oldParts.length; i++) {
    if (oldParts[i] != newParts[i]) return const [];
  }

  return [
    for (final letter in newParts.skip(oldParts.length))
      if (letter.trim().isNotEmpty) ...(_contacts[letter] ?? const [_short]),
  ];
}
