import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../data/library_controller.dart';
import 'paper.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({
    super.key,
    required this.controller,
    this.initialTab = 0,
    this.onBack,
  });
  final LibraryController controller;
  final int initialTab;
  final VoidCallback? onBack;
  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  late int tab = widget.initialTab;
  LibraryController get c => widget.controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) => Material(
      color: appPaper,
      child: PaperBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 60,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '돌아가기',
                      onPressed: widget.onBack ?? () => Navigator.pop(context),
                      icon: const Icon(CupertinoIcons.arrow_left, size: 23),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      tab == 2 ? '글꼴' : '쓰기 도구',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 21,
                      ),
                    ),
                  ],
                ),
              ),
              if (c.saveError != null)
                Container(
                  color: const Color(0xffffe6d2),
                  padding: const EdgeInsets.only(left: 14),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '도구 설정을 저장하지 못했습니다.',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                      TextButton(
                        onPressed: c.retrySave,
                        child: const Text(
                          '저장 재시도',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 27),
                child: Row(
                  children: [
                    for (var i = 0; i < 3; i++)
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => tab = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: tab == i ? ink : line,
                                  width: tab == i ? 1.4 : .6,
                                ),
                              ),
                            ),
                            child: Text(
                              ['종이', '펜', '글꼴'][i],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: tab == i
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(27, 24, 27, 28),
                  child: tab == 0
                      ? _paper()
                      : tab == 1
                      ? _pen()
                      : _fonts(),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _paper() => Column(
    children: [
      SizedBox(
        height: 239,
        child: Row(
          children: [
            IconButton(
              tooltip: '이전 종이',
              onPressed: () => c.setStyle(
                c.library.style.copy(
                  paperIndex: (c.library.style.paperIndex + 3) % 4,
                ),
              ),
              icon: const Icon(CupertinoIcons.chevron_left, size: 19),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: PaperSurface(
                  color: paperColors[c.library.style.paperIndex],
                  torn: true,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            IconButton(
              tooltip: '다음 종이',
              onPressed: () => c.setStyle(
                c.library.style.copy(
                  paperIndex: (c.library.style.paperIndex + 1) % 4,
                ),
              ),
              icon: const Icon(CupertinoIcons.chevron_right, size: 19),
            ),
          ],
        ),
      ),
      const SizedBox(height: 13),
      Text(
        paperNames[c.library.style.paperIndex],
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text(
        [
          '부드럽고 따뜻한 결',
          '은은하게 깊어지는 미색',
          '차분하고 담백한 회백색',
          '햇살을 머금은 크림빛',
        ][c.library.style.paperIndex],
        style: const TextStyle(fontSize: 12, color: muted),
      ),
      const SizedBox(height: 27),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < 4; i++)
            Semantics(
              selected: c.library.style.paperIndex == i,
              child: InkWell(
                onTap: () => c.setStyle(c.library.style.copy(paperIndex: i)),
                child: Container(
                  width: 58,
                  height: 61,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: c.library.style.paperIndex == i
                          ? burgundy
                          : Colors.transparent,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: PaperSurface(
                    color: paperColors[i],
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 30),
      const Divider(color: line, height: 1),
      Row(
        children: [
          const Text(
            '줄 가이드',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const Spacer(),
          Switch.adaptive(
            value: c.library.style.guides,
            activeTrackColor: burgundy,
            onChanged: (value) =>
                c.setStyle(c.library.style.copy(guides: value)),
          ),
        ],
      ),
    ],
  );

  Widget _pen() => Column(
    children: [
      SizedBox(
        height: 230,
        child: Image.asset(
          'assets/images/fountain-pen.png',
          fit: BoxFit.contain,
        ),
      ),
      Text(
        ['클래식 만년필', '따뜻한 브라운', '고요한 블루'][c.library.style.penIndex],
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
      ),
      const SizedBox(height: 9),
      const Text(
        '문장에 남기는 나만의 잉크빛',
        style: TextStyle(color: muted, fontSize: 12),
      ),
      const SizedBox(height: 30),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              child: Semantics(
                label: ['잉크 브라운', '웜 브라운', '고요한 블루'][i],
                selected: c.library.style.penIndex == i,
                button: true,
                child: InkWell(
                  onTap: () => c.setStyle(c.library.style.copy(penIndex: i)),
                  child: Container(
                    width: 47,
                    height: 47,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: c.library.style.penIndex == i
                            ? burgundy
                            : Colors.transparent,
                      ),
                    ),
                    padding: const EdgeInsets.all(5),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: penColors[i],
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 35),
      const Divider(color: line),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text(
          '펜 움직임',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: const Text(
          '입력 위치를 따라, 한 획씩 가볍게',
          style: TextStyle(color: muted, fontSize: 11, height: 1.7),
        ),
        activeTrackColor: burgundy,
        value: c.library.style.penMotion,
        onChanged: (value) =>
            c.setStyle(c.library.style.copy(penMotion: value)),
      ),
      const SizedBox(height: 13),
      const Text(
        '한글 조합 중에는 흔들림을 멈춥니다.\n쓰기 소리는 준비 중입니다.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: muted, height: 1.8),
      ),
    ],
  );

  Widget _fonts() => Column(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(3),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(CupertinoIcons.lock, size: 17, color: muted),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '쓰는 인간체',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '브랜드 전용 · 개발 중',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                  SizedBox(height: 9),
                  Text(
                    '오래 읽고, 오래 쓰는 문장을 위해\n천천히 다듬고 있습니다.',
                    style: TextStyle(fontSize: 12, color: muted, height: 1.7),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      for (var i = 0; i < 3; i++)
        InkWell(
          onTap: () => c.setStyle(c.library.style.copy(fontIndex: i)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  c.library.style.fontIndex == i
                      ? CupertinoIcons.checkmark_circle_fill
                      : CupertinoIcons.circle,
                  size: 20,
                  color: c.library.style.fontIndex == i ? burgundy : line,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fontNames[i], style: writingTextStyle(i, size: 17)),
                      const SizedBox(height: 3),
                      Text(
                        ['부드럽고 편안한 본문', '또렷하고 단단한 문장', '담백하고 단정한 인상'][i],
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 15),
      SizedBox(
        height: 188,
        child: PaperSurface(
          color: paperColors[c.library.style.paperIndex],
          torn: true,
          child: Padding(
            padding: const EdgeInsets.all(21),
            child: Text(
              '새는 알에서 나오려고\n투쟁한다.\n알은 세계다.',
              style: writingTextStyle(
                c.library.style.fontIndex,
                size: 22,
                color: penColors[c.library.style.penIndex],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
