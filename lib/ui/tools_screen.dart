import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../data/library_controller.dart';
import 'paper.dart';

/// Secondary preferences, deliberately kept off the writing surface.
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key, required this.controller, this.onBack});
  final LibraryController controller;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final style = controller.library.style;
      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '쓰기 취향',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: onBack,
                    icon: const Icon(CupertinoIcons.xmark, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _row(
                '종이',
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 4; i++)
                      _swatch(
                        label: paperNames[i],
                        color: paperColors[i],
                        selected: style.paperIndex == i,
                        onTap: () =>
                            controller.setStyle(style.copy(paperIndex: i)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _row(
                '잉크',
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++)
                      _swatch(
                        label: ['먹빛', '브라운', '블루'][i],
                        color: penColors[i],
                        selected: style.penIndex == i,
                        onTap: () =>
                            controller.setStyle(style.copy(penIndex: i)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('글꼴', style: TextStyle(fontSize: 13, color: muted)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < 3; i++)
                    ChoiceChip(
                      label: Text(
                        fontNames[i],
                        style: TextStyle(
                          fontFamily: i == 2 ? 'NanumGothic' : serif,
                          fontSize: 13,
                        ),
                      ),
                      selected: style.fontIndex == i,
                      onSelected: (_) =>
                          controller.setStyle(style.copy(fontIndex: i)),
                      showCheckmark: false,
                      selectedColor: const Color(0xffe2e9df),
                      backgroundColor: paper,
                      side: BorderSide(
                        color: style.fontIndex == i ? green : line,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(color: line),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('펜 움직임', style: TextStyle(fontSize: 14)),
                value: style.penMotion,
                activeTrackColor: green,
                onChanged: (v) => controller.setStyle(style.copy(penMotion: v)),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('줄 가이드', style: TextStyle(fontSize: 14)),
                value: style.guides,
                activeTrackColor: green,
                onChanged: (v) => controller.setStyle(style.copy(guides: v)),
              ),
              if (controller.saveError != null)
                TextButton(
                  onPressed: controller.retrySave,
                  child: const Text('설정 저장 실패 · 다시 시도'),
                ),
              const SizedBox(height: 6),
              const Text(
                '쓰는 인간체는 다듬는 중입니다. 지금은 나눔 글꼴로 씁니다.',
                style: TextStyle(color: muted, fontSize: 11, height: 1.7),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _row(String label, Widget child) => Row(
    children: [
      Expanded(
        child: Text(label, style: const TextStyle(fontSize: 13, color: muted)),
      ),
      child,
    ],
  );

  Widget _swatch({
    required String label,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) => Semantics(
    label: label,
    selected: selected,
    button: true,
    child: Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: selected ? green : Colors.transparent),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: ink.withValues(alpha: .12)),
            ),
          ),
        ),
      ),
    ),
  );
}
