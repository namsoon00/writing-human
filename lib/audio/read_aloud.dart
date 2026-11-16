import 'package:flutter/widgets.dart' show StringCharacters;

abstract interface class ReadAloud {
  Future<void> speak(String text);
  Future<void> stop();
}

class KoreanVoiceUnavailable implements Exception {
  const KoreanVoiceUnavailable();
}

bool isKoreanVoice(String locale) =>
    locale.toLowerCase().split(RegExp('[-_]')).first == 'ko';

/// Keep utterances short and prefer the existing breaks in the writing.
Iterable<String> readAloudPhrases(String text) sync* {
  final boundary = RegExp(r'[.!?。！？…\n]');
  const limit = 180;
  var start = 0;
  var end = 0;
  var sentence = 0;
  var whitespace = 0;
  for (final glyph in text.characters) {
    if (end > start && end + glyph.length - start > limit) {
      final cut = sentence > start
          ? sentence
          : (whitespace > start ? whitespace : end);
      final phrase = text.substring(start, cut).trim();
      if (phrase.isNotEmpty) yield phrase;
      start = cut;
    }
    end += glyph.length;
    if (glyph.trim().isEmpty) whitespace = end;
    if (boundary.hasMatch(glyph)) sentence = end;
  }
  final phrase = text.substring(start).trim();
  if (phrase.isNotEmpty) yield phrase;
}
