import 'package:flutter/widgets.dart' show StringCharacters;

abstract interface class ReadAloud {
  Future<void> speak(String text);
  Future<void> stop();
}

class KoreanVoiceUnavailable implements Exception {
  const KoreanVoiceUnavailable();
}

const readAloudRate = 0.92;
const readAloudPagePause = Duration(milliseconds: 420);

bool isKoreanVoice(String locale) =>
    locale.toLowerCase().split(RegExp('[-_]')).first == 'ko';

typedef ReadAloudPhrase = ({String text, Duration pauseBefore});

/// Keep punctuation for the voice engine and leave more room between verses.
Iterable<ReadAloudPhrase> readAloudPhrases(String text) sync* {
  var pause = Duration.zero;
  for (final line in text.split(RegExp(r'\r\n|\r|\n'))) {
    final content = line.trim();
    if (content.isEmpty) {
      if (pause != Duration.zero) pause = const Duration(milliseconds: 480);
      continue;
    }
    for (final phrase in _splitLongLine(content)) {
      yield (text: phrase, pauseBefore: pause);
      pause = const Duration(milliseconds: 70);
    }
    pause = const Duration(milliseconds: 165);
  }
}

Iterable<String> _splitLongLine(String text) sync* {
  const limit = 180;
  if (text.length <= limit) {
    yield text;
    return;
  }

  final sentence = RegExp(
    r'''[.!?。！？…]+[”’」』》）"')\]]*(?=\s|$)''',
  ).allMatches(text).map((match) => match.end).toSet();
  var start = 0;
  var end = 0;
  var sentenceEnd = 0;
  var whitespace = 0;
  for (final glyph in text.characters) {
    if (end > start && end + glyph.length - start > limit) {
      final cut = sentenceEnd > start
          ? sentenceEnd
          : (whitespace > start ? whitespace : end);
      final phrase = text.substring(start, cut).trim();
      if (phrase.isNotEmpty) yield phrase;
      start = cut;
    }
    end += glyph.length;
    if (glyph.trim().isEmpty) whitespace = end;
    if (sentence.contains(end)) sentenceEnd = end;
  }
  final phrase = text.substring(start).trim();
  if (phrase.isNotEmpty) yield phrase;
}
