import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/library_search.dart';

String? searchQueryThroughCaret(TextEditingValue value) {
  final selection = value.selection;
  final caret = selection.extentOffset;
  if (!selection.isValid ||
      !selection.isCollapsed ||
      caret > value.text.length ||
      (value.isComposingRangeValid && !value.composing.isCollapsed)) {
    return null;
  }
  final query = value.text.substring(0, caret);
  return searchWordPrefix(query).isEmpty ? null : query;
}

class SearchCompletions extends StatelessWidget {
  const SearchCompletions({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.options,
    required this.onSelected,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Iterable<String> Function(String query) options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, focusNode]),
    builder: (context, _) {
      final value = controller.value;
      final query = searchQueryThroughCaret(value);
      if (!focusNode.hasFocus || query == null) return const SizedBox.shrink();
      final start = query.length - searchWordPrefix(query).length;
      final suffix = value.text.substring(query.length);
      final end = query.length + searchWordSuffixLength(suffix);
      final currentWord = value.text.substring(start, end).toLowerCase();
      final suggestions = options(
        query,
      ).where((word) => word.toLowerCase() != currentWord).take(5).toList();
      if (suggestions.isEmpty) return const SizedBox.shrink();
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxHeight < 48) return const SizedBox.shrink();
          return Semantics(
            label: '검색어 자동완성',
            child: SizedBox(
              height: 48,
              child: ListView.separated(
                key: const ValueKey('search-completions'),
                scrollDirection: Axis.horizontal,
                itemCount: suggestions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 4),
                itemBuilder: (context, index) {
                  final suggestion = suggestions[index];
                  return TextButton.icon(
                    icon: const Icon(CupertinoIcons.arrow_up_left, size: 13),
                    label: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: (constraints.maxWidth - 60).clamp(0.0, 260.0),
                      ),
                      child: Text(
                        suggestion,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    onPressed: () {
                      final text = value.text.replaceRange(
                        start,
                        end,
                        suggestion,
                      );
                      controller.value = TextEditingValue(
                        text: text,
                        selection: TextSelection.collapsed(
                          offset: start + suggestion.length,
                        ),
                      );
                      focusNode.unfocus();
                      onSelected(text);
                    },
                  );
                },
              ),
            ),
          );
        },
      );
    },
  );
}
