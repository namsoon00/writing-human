import 'package:flutter/material.dart';

enum PaperTool {
  writing('글쓰기', Icons.edit_outlined),
  highlighter('형광펜', Icons.border_color_outlined),
  eraser('지우개', Icons.backspace_outlined);

  const PaperTool(this.label, this.icon);

  final String label;
  final IconData icon;
}
