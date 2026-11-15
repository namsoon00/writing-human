import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'paper.dart';

class PaperSearchField extends StatelessWidget {
  const PaperSearchField({
    super.key,
    this.fieldKey,
    required this.controller,
    required this.focusNode,
    required this.hint,
    this.label,
    this.autofocus = false,
    this.enabled = true,
    this.maxLength,
    this.showIcon = true,
    this.onChanged,
    this.onSubmitted,
  });

  final Key? fieldKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final String? label;
  final bool autofocus, enabled, showIcon;
  final int? maxLength;
  final ValueChanged<String>? onChanged, onSubmitted;

  @override
  Widget build(BuildContext context) => Semantics(
    identifier: 'paper-search-input',
    child: TextField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      enabled: enabled,
      maxLength: maxLength,
      autocorrect: false,
      cursorColor: brandInk,
      cursorWidth: 1.4,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        labelText: label,
        hintStyle: const TextStyle(color: muted),
        prefixIcon: showIcon
            ? const Icon(CupertinoIcons.search, size: 17, color: brandInk)
            : null,
        prefixIconConstraints: const BoxConstraints(minWidth: 34),
        filled: false,
        isDense: true,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: const UnderlineInputBorder(borderSide: BorderSide(color: line)),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: brandInk, width: 1.25),
        ),
        disabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: line),
        ),
      ),
    ),
  );
}
