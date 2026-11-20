import 'package:flutter/widgets.dart' show StringCharacters;

abstract interface class ReadAloud {
  Future<void> speak(String text);
  Future<void> stop();
}

abstract interface class BrandReadAloud implements ReadAloud {
  @override
  Future<void> speak(String text, {String? next});
}

enum NarrationVoice {
  f3('여성 F3'),
  m2('남성 M2'),
  device('기기 음성');

  const NarrationVoice(this.label);
  final String label;
}

class KoreanVoiceUnavailable implements Exception {
  const KoreanVoiceUnavailable();
}

const readAloudRate = 0.92;
const readAloudPagePause = Duration(milliseconds: 420);

bool isKoreanVoice(String locale) =>
    locale.toLowerCase().split(RegExp('[-_]')).first == 'ko';

typedef ReadAloudPhrase = ({String text, Duration pauseBefore});

/// Keep the shape of a paragraph or verse and its punctuation for the engine.
Iterable<ReadAloudPhrase> readAloudPhrases(
  String text, {
  int limit = 180,
}) sync* {
  final paragraphs = text
      .replaceAll(RegExp(r'\r\n?'), '\n')
      .split(RegExp(r'\n[^\S\n]*\n'));
  var pause = Duration.zero;
  for (final paragraph in paragraphs) {
    final content = paragraph.trim();
    if (content.isEmpty) continue;
    for (final phrase in _splitLongParagraph(content, limit)) {
      yield (text: phrase, pauseBefore: pause);
      pause = const Duration(milliseconds: 70);
    }
    pause = const Duration(milliseconds: 480);
  }
}

Iterable<String> _splitLongParagraph(String text, int limit) sync* {
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
