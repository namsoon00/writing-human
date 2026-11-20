import 'package:flutter/widgets.dart' show StringCharacters;

const _keyboardCharacters = {
  '‘': "'",
  '’': "'",
  '‚': "'",
  '‛': "'",
  '′': "'",
  '“': '"',
  '”': '"',
  '„': '"',
  '‟': '"',
  '″': '"',
  '「': '"',
  '」': '"',
  '『': '"',
  '』': '"',
  '〈': '<',
  '〉': '>',
  '《': '<',
  '》': '>',
  '【': '[',
  '】': ']',
  '〔': '[',
  '〕': ']',
  '…': '...',
  '⋯': '...',
  '‐': '-',
  '‑': '-',
  '‒': '-',
  '–': '-',
  '—': '-',
  '―': '-',
  '−': '-',
  '·': ',',
  '・': ',',
  '‧': ',',
  '〜': '~',
  '～': '~',
  '×': '*',
  '÷': '/',
  '≤': '<=',
  '≥': '>=',
  '≠': '!=',
  '±': '+/-',
  '←': '<-',
  '→': '->',
  '↔': '<->',
  '‼': '!!',
  '⁉': '!?',
};
final _spacing = RegExp(r'[\u00a0\u1680\u2000-\u200a\u202f\u205f\u3000]');
final _invisible = RegExp(
  r'[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f\u00ad\u200b\u2060\ufeff]',
);
final _ornaments = RegExp(r'[※★☆♥♡■□●○◆◇▪▫▶▷◀◁✓✔✕✖]');
final _emoji = RegExp(
  r'\p{Extended_Pictographic}|\p{Regional_Indicator}',
  unicode: true,
);
final _variants = RegExp('[\ufe0e\ufe0f\u20e3]');
final _candidates = RegExp(
  '[${RegExp.escape(_keyboardCharacters.keys.join())}]|'
  '${_spacing.pattern}|${_invisible.pattern}|${_ornaments.pattern}|'
  '${_emoji.pattern}|${_variants.pattern}|'
  r'[\u{ff01}-\u{ff5e}\u{2460}-\u{2473}]',
  unicode: true,
);

bool needsOriginalTextCleanup(String text) => _candidates.hasMatch(text);

final _wordStart = RegExp(r'^[\p{L}\p{N}\p{M}]', unicode: true);
final _wordEnd = RegExp(r'[\p{L}\p{N}\p{M}]$', unicode: true);

/// An explicit editing action, preserving words, punctuation and line breaks.
String cleanOriginalText(String text) {
  if (!needsOriginalTextCleanup(text)) return text;
  final result = StringBuffer();
  var removed = false;
  var lastWasWord = false;
  var lastWasSpace = false;
  for (final glyph in text.characters) {
    final replacement = _keyboardGlyph(glyph);
    if (replacement == null) {
      removed = true;
      continue;
    }
    if (replacement.isEmpty) continue;
    if (removed && lastWasWord && _wordStart.hasMatch(replacement)) {
      result.write(' ');
    }
    if (!(removed && lastWasSpace && replacement == ' ')) {
      result.write(replacement);
    }
    removed = false;
    lastWasWord = _wordEnd.hasMatch(replacement);
    lastWasSpace = replacement == ' ';
  }
  return result.toString();
}

String? _keyboardGlyph(String glyph) {
  final visible = glyph.replaceAll(_invisible, '').replaceAll(_variants, '');
  if (_keyboardCharacters[visible] case final replacement?) return replacement;
  if (_emoji.hasMatch(glyph) || _ornaments.hasMatch(glyph)) return null;
  if (visible.runes.length == 1) {
    final rune = visible.runes.single;
    if (rune >= 0xff01 && rune <= 0xff5e) {
      return String.fromCharCode(rune - 0xfee0);
    }
    if (rune >= 0x2460 && rune <= 0x2473) {
      return (rune - 0x245f).toString();
    }
  }
  return visible.replaceAll(_spacing, ' ');
}
