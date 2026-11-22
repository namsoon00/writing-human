import 'package:flutter/material.dart';

import '../data/model.dart';
import 'paper.dart';

class FontSizeControl extends StatefulWidget {
  const FontSizeControl({
    super.key,
    required this.style,
    required this.onChanged,
    this.onPreviewChanged,
  });
  final WritingStyle style;
  final ValueChanged<double> onChanged;
  final ValueChanged<double?>? onPreviewChanged;

  @override
  State<FontSizeControl> createState() => _FontSizeControlState();
}

class _FontSizeControlState extends State<FontSizeControl> {
  double? _draft;

  @override
  Widget build(BuildContext context) {
    final size = _draft ?? widget.style.fontSize;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '글자 크기',
                style: TextStyle(fontSize: 13, color: muted),
              ),
            ),
            Text(
              size.toStringAsFixed(0),
              key: const ValueKey('font-size-value'),
            ),
          ],
        ),
        Semantics(
          label: '글자 크기',
          child: Slider(
            key: const ValueKey('font-size-slider'),
            min: WritingStyle.minFontSize,
            max: WritingStyle.maxFontSize,
            divisions: (WritingStyle.maxFontSize - WritingStyle.minFontSize)
                .round(),
            value: size,
            label: size.toStringAsFixed(0),
            onChanged: (value) {
              setState(() => _draft = value);
              widget.onPreviewChanged?.call(value);
            },
            onChangeEnd: (value) {
              setState(() => _draft = null);
              widget.onChanged(value);
              widget.onPreviewChanged?.call(null);
            },
          ),
        ),
      ],
    );
  }
}
