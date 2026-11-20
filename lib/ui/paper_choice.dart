import 'package:flutter/material.dart';

import 'paper.dart';

class PaperChoice extends StatelessWidget {
  const PaperChoice({
    super.key,
    required this.index,
    required this.selected,
    required this.onSelected,
  });

  final int index;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final color = paperColors[index];
    const corners = BorderRadius.all(Radius.circular(2));
    return ChoiceChip(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      avatarBorder: const RoundedRectangleBorder(borderRadius: corners),
      avatar: Container(
        width: 24,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          image: paperGrain(color, paperGrainOpacity[index]),
          borderRadius: corners,
          border: Border.all(color: ink.withValues(alpha: .18)),
        ),
      ),
      label: Text(paperNames[index]),
      selected: selected,
      onSelected: onSelected,
    );
  }
}
