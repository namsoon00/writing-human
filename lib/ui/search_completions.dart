import 'package:flutter/material.dart';

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
      final query = value.text.trim();
      if (!focusNode.hasFocus ||
          query.isEmpty ||
          (value.isComposingRangeValid && !value.composing.isCollapsed)) {
        return const SizedBox.shrink();
      }
      final suggestions = options(query).take(5).toList();
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
                padding: const EdgeInsets.symmetric(horizontal: 4),
                scrollDirection: Axis.horizontal,
                itemCount: suggestions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 4),
                itemBuilder: (context, index) {
                  final suggestion = suggestions[index];
                  return TextButton.icon(
                    icon: const Icon(Icons.north_west, size: 14),
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
                      controller.value = TextEditingValue(
                        text: suggestion,
                        selection: TextSelection.collapsed(
                          offset: suggestion.length,
                        ),
                      );
                      focusNode.unfocus();
                      onSelected(suggestion);
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
