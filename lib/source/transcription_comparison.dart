import 'package:flutter/widgets.dart' show StringCharacters;

import '../data/model.dart';

typedef _ComparedCharacter = ({String value, int start, int end});
typedef _Anchor = (String, String, String);

/// Finds the next part of the original to show while the writer transcribes.
/// Offsets always refer to the original UTF-16 text.
class TranscriptionComparison {
  TranscriptionComparison(RegisteredOriginal original, {int sourceOffset = 0})
    : _original = _remaining(original, sourceOffset);

  static String _remaining(RegisteredOriginal original, int offset) {
    final text = original.text
        .substring(
          original.writingRange?.start ?? 0,
          original.writingRange?.end,
        )
        .trimLeft();
    return text.substring(offset.clamp(0, text.length));
  }

  final String _original;
  late final _source = _comparedCharacters(_original);
  late final _anchors = _indexAnchors();
  String? _lastWritten;
  var _progress = 0;
  var _offset = 0;
  var _following = true;

  int sourceOffsetFor(String written) {
    _compare(written);
    return _offset;
  }

  String remainderFor(String written, {int composingLength = 0}) {
    _compare(written);
    if (composingLength <= 0 || !_following || _progress >= _source.length) {
      return _original.substring(_offset);
    }
    final end = (_progress + composingLength).clamp(0, _source.length);
    return end == _source.length
        ? ''
        : _original.substring(_source[end - 1].end);
  }

  static final _optionalCharacter = RegExp(
    r'^[\p{P}\p{S}\p{White_Space}]',
    unicode: true,
  );

  static List<_ComparedCharacter> _comparedCharacters(String text) {
    final result = <_ComparedCharacter>[];
    var start = 0;
    for (final value in text.characters) {
      final end = start + value.length;
      if (!_optionalCharacter.hasMatch(value) && !value.endsWith('\u20e3')) {
        result.add((value: value, start: start, end: end));
      }
      start = end;
    }
    return result;
  }

  static String _formattingKey(String value) => switch (value) {
    '\r' || '\r\n' || '\u2028' || '\u2029' => '\n',
    _ => value,
  };

  int _sourcePosition(int progress, String trailingInput) {
    if (_source.isEmpty) return 0;
    if (progress == _source.length) return _original.length;
    final start = progress == 0 ? 0 : _source[progress - 1].end;
    final end = _source[progress].start;
    if (start == end || trailingInput.isEmpty) return start;
    final typedFormatting = trailingInput.characters
        .map(_formattingKey)
        .toSet();
    var offset = start;
    var matched = start;
    for (final value in _original.substring(start, end).characters) {
      offset += value.length;
      if (typedFormatting.contains(_formattingKey(value))) matched = offset;
    }
    return matched;
  }

  static _Anchor _anchorAt(List<_ComparedCharacter> text, int index) =>
      (text[index].value, text[index + 1].value, text[index + 2].value);

  Map<_Anchor, List<int>> _indexAnchors() {
    final anchors = <_Anchor, List<int>>{};
    for (var i = 0; i + 2 < _source.length; i++) {
      (anchors[_anchorAt(_source, i)] ??= []).add(i);
    }
    return anchors;
  }

  int _matchLength(List<_ComparedCharacter> typed, int input, int source) {
    var length = 0;
    while (length < 12 &&
        input + length < typed.length &&
        source + length < _source.length &&
        typed[input + length].value == _source[source + length].value) {
      length++;
    }
    return length;
  }

  int? _resumeAt(List<_ComparedCharacter> typed, int input, int source) {
    final expected = _matchLength(typed, input, source);
    if (expected >= 3 ||
        (expected > 0 &&
            input + expected == typed.length &&
            source + expected == _source.length)) {
      return source;
    }
    if (input + 2 >= typed.length) return null;

    int? match;
    var best = 2;
    for (final candidate
        in _anchors[_anchorAt(typed, input)] ?? const <int>[]) {
      if (candidate <= source) continue;
      final length = _matchLength(typed, input, candidate);
      final startsWord = _source[candidate].start > _source[candidate - 1].end;
      // A short ending within a word is easy to match in unrelated notes.
      if (candidate > source + 1 && !startsWord && length < 6) continue;
      if (length > best) {
        match = candidate;
        best = length;
      } else if (length == best) {
        // A repeated phrase does not establish where the writer resumed.
        match = null;
      }
    }
    return match;
  }

  void _compare(String written) {
    if (_lastWritten == written) return;
    _lastWritten = written;
    if (_source.isEmpty) return;
    final typed = _comparedCharacters(written);
    var source = 0;
    var lastMatch = -1;
    var following = true;

    for (
      var input = 0;
      input < typed.length && source < _source.length;
      input++
    ) {
      if (!following || typed[input].value != _source[source].value) {
        final match = _resumeAt(typed, input, source);
        if (match == null) {
          following = false;
          continue;
        }
        following = true;
        source = match;
      }
      source++;
      lastMatch = input;
    }

    _progress = source;
    _following = following;
    final formattingStart = lastMatch < 0 ? 0 : typed[lastMatch].end;
    final formattingEnd = lastMatch + 1 < typed.length
        ? typed[lastMatch + 1].start
        : written.length;
    _offset = _sourcePosition(
      source,
      written.substring(formattingStart, formattingEnd),
    );
  }
}
