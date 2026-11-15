import 'package:flutter/widgets.dart' show StringCharacters;

import '../data/model.dart';

typedef TranscriptionDifference = ({int start, int end, String expected});

/// Compares entered graphemes with the selected passage. One short lookahead
/// distinguishes a wrong glyph from an extra or missing glyph.
class TranscriptionComparison {
  TranscriptionComparison(RegisteredOriginal original)
    : _source = original.text
          .substring(
            original.writingRange?.start ?? 0,
            original.writingRange?.end,
          )
          .trimLeft()
          .characters
          .toList(growable: false);

  final List<String> _source;
  String? _lastWritten;
  var _progress = 0;
  List<TranscriptionDifference> _differences = const [];

  List<TranscriptionDifference> differencesFor(String written) {
    _compare(written);
    return _differences;
  }

  int sourceOffsetFor(String written) {
    _compare(written);
    return _source
        .take(_progress)
        .fold(0, (offset, character) => offset + character.length);
  }

  String remainderFor(String written, {int composingLength = 0}) {
    _compare(written);
    return _source.skip(_progress + composingLength).join();
  }

  void _compare(String written) {
    if (_lastWritten == written) return;
    _lastWritten = written;
    final typed = written.characters.toList(growable: false);
    final differences = <TranscriptionDifference>[];
    var input = 0;
    var source = 0;
    var offset = 0;

    int matchingRun(int nextInput, int nextSource) {
      var count = 0;
      while (count < 6 &&
          nextInput + count < typed.length &&
          nextSource + count < _source.length &&
          typed[nextInput + count] == _source[nextSource + count]) {
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
      final end = offset + character.length;
      if (character != _source[source]) {
        final substitution = matchingRun(input + 1, source + 1);
        final insertion = matchingRun(input + 1, source);
        final omission = matchingRun(input, source + 1);
        if (hasAnchor(omission, input, source + 1) &&
            omission > substitution &&
            omission > insertion) {
          differences.add((
            start: offset,
            end: offset,
            expected: _source[source],
          ));
          source++;
          continue;
        }
        if (hasAnchor(insertion, input + 1, source) &&
            insertion > substitution) {
          differences.add((start: offset, end: end, expected: ''));
          input++;
          offset = end;
          continue;
        }
        differences.add((start: offset, end: end, expected: _source[source]));
      }
      source++;
      input++;
      offset = end;
    }
    while (input < typed.length) {
      final end = offset + typed[input].length;
      differences.add((start: offset, end: end, expected: ''));
      input++;
      offset = end;
    }
    _progress = source;
    _differences = differences;
  }
}
