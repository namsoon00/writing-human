import 'package:flutter/material.dart';

export 'writing_sound_native.dart'
    if (dart.library.js_interop) 'writing_sound_web.dart';

/// Accept a single visible grapheme at the edit position. A composing range can
/// move forward when the IME commits one syllable and starts the next.
bool hasNewWrittenCharacter(TextEditingValue before, TextEditingValue after) {
  if (before == after ||
      !after.selection.isValid ||
      !after.selection.isCollapsed ||
      after.selection.end > after.text.length) {
    return false;
  }
  final wasComposing =
      before.isComposingRangeValid && !before.composing.isCollapsed;
  final composing = after.isComposingRangeValid && !after.composing.isCollapsed;
  final start = wasComposing ? before.composing.start : before.selection.start;
  final oldEnd = wasComposing ? before.composing.end : before.selection.end;
  final end = composing ? after.composing.start : after.selection.end;
  final newEnd = composing ? after.composing.end : end;
  if (start < 0 ||
      oldEnd > before.text.length ||
      end <= start ||
      end - start > 24 ||
      (!wasComposing && composing) ||
      (!wasComposing && before.text == after.text)) {
    return false;
  }

  // Check the edited range, including when input happens in the middle.
  final tailLength = before.text.length - oldEnd;
  if (after.text.length - newEnd != tailLength ||
      !after.text.startsWith(before.text.substring(0, start)) ||
      !after.text.endsWith(before.text.substring(oldEnd))) {
    return false;
  }
  final inserted = after.text.substring(start, end);
  return inserted.trim().isNotEmpty && inserted.characters.length == 1;
}
