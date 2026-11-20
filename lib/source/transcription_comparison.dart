import 'package:flutter/widgets.dart' show StringCharacters;

import '../data/model.dart';

typedef TranscriptionDifference = ({int start, int end, String expected});

typedef _ComparedCharacter = ({String value, int start, int end});

/// Compares the text of a passage while allowing punctuation and line breaks
/// to be copied freely. Offsets always refer to the original UTF-16 strings.
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
  String? _lastWritten;
  var _progress = 0;
  var _offset = 0;
  List<TranscriptionDifference> _differences = const [];

  List<TranscriptionDifference> differencesFor(String written) {
    _compare(written);
    return _differences;
  }

  int sourceOffsetFor(String written) {
    _compare(written);
    return _offset;
  }

  String remainderFor(String written, {int composingLength = 0}) {
    _compare(written);
    if (composingLength <= 0 || _progress >= _source.length) {
      return _original.substring(_offset);
    }
    final end = (_progress + composingLength).clamp(0, _source.length);
    return end == _source.length
        ? ''
        : _original.substring(_source[end - 1].end);
  }

  static final _optionalCharacter = RegExp(
    r'^[\p{P}\p{S}\r\n\u2028\u2029]',
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

  void _compare(String written) {
    if (_lastWritten == written) return;
    _lastWritten = written;
    if (_source.isEmpty) return;
    final typed = _comparedCharacters(written);
    final differences = <TranscriptionDifference>[];
    var input = 0;
    var source = 0;

    int matchingRun(int nextInput, int nextSource) {
      var count = 0;
      while (count < 6 &&
          nextInput + count < typed.length &&
          nextSource + count < _source.length &&
          typed[nextInput + count].value == _source[nextSource + count].value) {
        count++;
      }
      return count;
    }

    bool hasAnchor(int run, int nextInput, int nextSource) =>
        run >= 2 ||
        (run == 1 &&
            nextInput + run == typed.length &&
            nextSource + run == _source.length);

    while (input < typed.length && source < _source.length) {
      final character = typed[input];
      if (character.value != _source[source].value) {
        final substitution = matchingRun(input + 1, source + 1);
        final insertion = matchingRun(input + 1, source);
        final omission = matchingRun(input, source + 1);
        if (hasAnchor(omission, input, source + 1) &&
            omission > substitution &&
            omission > insertion) {
          differences.add((
            start: character.start,
            end: character.start,
            expected: _source[source].value,
          ));
          source++;
          continue;
        }
        if (hasAnchor(insertion, input + 1, source) &&
            insertion > substitution) {
          differences.add((
            start: character.start,
            end: character.end,
            expected: '',
          ));
          input++;
          continue;
        }
        differences.add((
          start: character.start,
          end: character.end,
          expected: _source[source].value,
        ));
      }
      source++;
      input++;
    }
    for (; input < typed.length; input++) {
      final character = typed[input];
      differences.add((
        start: character.start,
        end: character.end,
        expected: '',
      ));
    }
    _progress = source;
    _offset = _sourcePosition(
      source,
      written.substring(typed.lastOrNull?.end ?? 0),
    );
    _differences = differences;
  }
}
