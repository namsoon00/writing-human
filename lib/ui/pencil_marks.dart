import 'package:flutter/material.dart';
import '../data/model.dart';
import 'book_detail_design.dart';

/// Paints the saved range behind the glyphs using Flutter's text layout.
TextStyle passageWashStyle(BookDetailChoice choice) => TextStyle(
  backgroundColor: BookDetailDesign.color(BookDetailKind.pencil, choice)
      .withValues(
        alpha: switch (choice.variant) {
          1 => .26,
          2 => .34,
          _ => .18,
        },
      ),
);

/// Keeps Flutter's composing underline and the user's annotations in a single
/// span tree. It only reads TextEditingValue; no listener rewrites IME state.
TextSpan pencilTextSpan({
  required TextEditingValue value,
  required List<PencilMark> marks,
  TextStyle? style,
  bool withComposing = false,
  BookDetailChoice choice = const BookDetailChoice(),
}) {
  final composing =
      withComposing &&
      value.isComposingRangeValid &&
      !value.composing.isCollapsed;
  final boundaries = <int>{
    0,
    value.text.length,
    for (final m in marks) ...[
      m.start.clamp(0, value.text.length),
      m.end.clamp(0, value.text.length),
    ],
    if (composing) ...[value.composing.start, value.composing.end],
  }.toList()..sort();
  return TextSpan(
    style: style,
    children: [
      for (var i = 0; i + 1 < boundaries.length; i++)
        TextSpan(
          text: value.text.substring(boundaries[i], boundaries[i + 1]),
          style:
              composing &&
                  boundaries[i] >= value.composing.start &&
                  boundaries[i + 1] <= value.composing.end
              ? const TextStyle(decoration: TextDecoration.underline)
              : choice.enabled &&
                    marks.any(
                      (m) =>
                          m.start <= boundaries[i] &&
                          m.end >= boundaries[i + 1],
                    )
              ? passageWashStyle(choice)
              : null,
        ),
    ],
  );
}

class PencilTextController extends TextEditingController {
  PencilTextController({
    required TextEditingValue value,
    required this.annotatedText,
    required this.marks,
    this.choice = const BookDetailChoice(),
  }) : super.fromValue(value);
  String annotatedText;
  List<PencilMark> marks;
  BookDetailChoice choice;
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) => pencilTextSpan(
    value: value,
    marks: PencilMark.afterEdit(annotatedText, text, marks),
    style: style,
    withComposing: withComposing,
    choice: choice,
  );
}
