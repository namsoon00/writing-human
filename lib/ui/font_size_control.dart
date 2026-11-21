import 'package:flutter/material.dart';

import '../data/model.dart';
import 'paper.dart';

class FontSizeControl extends StatefulWidget {
  const FontSizeControl({
    super.key,
    required this.style,
    required this.onChanged,
    this.showSpecimen = true,
    this.onPreviewChanged,
  });
  final WritingStyle style;
  final bool showSpecimen;
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
    void step(double delta) => widget.onChanged(
      (size + delta).clamp(WritingStyle.minFontSize, WritingStyle.maxFontSize),
    );
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
            IconButton(
              tooltip: '글자 작게',
              onPressed: size > WritingStyle.minFontSize
                  ? () => step(-1)
                  : null,
              icon: const Icon(Icons.text_decrease, size: 19),
            ),
            Text(
              size.toStringAsFixed(0),
              key: const ValueKey('font-size-value'),
            ),
            IconButton(
              tooltip: '글자 크게',
              onPressed: size < WritingStyle.maxFontSize ? () => step(1) : null,
              icon: const Icon(Icons.text_increase, size: 19),
            ),
          ],
        ),
        Slider(
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
        if (widget.showSpecimen)
          Container(
            key: const ValueKey('font-paper-specimen'),
            constraints: const BoxConstraints(minHeight: 86),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            decoration: BoxDecoration(
              color: paperColors[widget.style.paperIndex],
              image: paperGrain(paperColors[widget.style.paperIndex], .20),
              border: Border.all(color: line, width: .7),
              boxShadow: [
                BoxShadow(
                  color: ink.withValues(alpha: .05),
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 150),
              child: Text(
                '마음에 남은 문장',
                key: ValueKey(size),
                maxLines: 2,
                textAlign: TextAlign.center,
                style: writingTextStyle(
                  widget.style.fontIndex,
                  size: size,
                  color: penColors[widget.style.penIndex],
                  useDevelopmentTypeface: widget.style.useDevelopmentTypeface,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
