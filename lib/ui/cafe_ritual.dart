import 'package:flutter/material.dart';
import '../cafe/cafe_home.dart';
import '../cafe/cafe_visit.dart';
import 'paper.dart';
import 'paper_panel.dart';
import 'original_photo.dart';

enum CafeRitualAction { returnSeat, rainWindow, openPastWriting }

typedef CafePastWriting = ({
  String pageId,
  String text,
  String? date,
  String? photoId,
});

/// A paper-like reading surface, opened by the real card or accessible guide.
class CafeRitualSheet extends StatefulWidget {
  const CafeRitualSheet({
    super.key,
    required this.page,
    required this.home,
    required this.moment,
    required this.onSave,
    this.currentSeat,
    this.chair,
    this.lastSentence = '',
    this.pastWriting,
    this.canTranscribe = false,
  });
  final String page, lastSentence;
  final CafePastWriting? pastWriting;
  final CafeHome home;
  final DateTime moment;
  final CafeSeat? currentSeat;
  final String? chair;
  final bool canTranscribe;
  final Future<bool> Function(CafeHome) onSave;
  @override
  State<CafeRitualSheet> createState() => _CafeRitualSheetState();
}

class _CafeRitualSheetState extends State<CafeRitualSheet> {
  late var home = widget.home;
  bool busy = false;
  String? error, notice;
  Future<void> save(CafeHome value) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      final ok = await widget.onSave(value);
      if (!mounted) return;
      setState(() {
        home = value;
        if (!ok) {
          error = '공간을 저장하지 못했어요. 다시 저장해 주세요.';
        } else {
          notice = '다음에 와도 그대로 둘게요.';
        }
      });
    } catch (_) {
      if (mounted) setState(() => error = '공간을 저장하지 못했어요. 다시 저장해 주세요.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String shortLine(String source) {
    final result = StringBuffer();
    for (final letter in source.trim().characters) {
      if (result.length + letter.length > 320) break;
      result.write(letter);
    }
    return result.toString();
  }

  Widget action(String text, Object result, String key) => FilledButton(
    key: ValueKey(key),
    onPressed: busy ? null : () => Navigator.pop(context, result),
    child: Text(text),
  );
  Widget _memory(BuildContext context, String current) => PopScope(
    canPop: !busy,
    child: PaperPanel(
      color: originalPanelColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
            child: PaperPanelHeader(
              '내가 남긴 문장',
              backLabel: '카페',
              canClose: !busy,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              children: [
                if (widget.pastWriting case final past?) ...[
                  Text(
                    past.date == null ? '지난 필사' : '지난 필사 · ${past.date}',
                    style: const TextStyle(color: muted, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    past.text,
                    style: const TextStyle(fontSize: 21, height: 1.75),
                  ),
                  if (past.photoId case final photo?) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: busy
                          ? null
                          : () => showOriginalPhoto(
                              context,
                              photo,
                              color: originalPanelColor,
                            ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 86,
                            height: 62,
                            child: OriginalPhoto(
                              id: photo,
                              compact: true,
                              thumbnailSize: const Size(172, 124),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Flexible(child: Text('원본 사진 보기')),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  action(
                    '필사한 쪽 열기',
                    CafeRitualAction.openPastWriting,
                    'cafe-open-past-writing',
                  ),
                  const Divider(height: 32),
                ],
                Text(
                  home.pinned ?? '아직 걸어 둔 문장이 없어요.',
                  key: const ValueKey('cafe-pinned-sentence'),
                  style: const TextStyle(fontSize: 23, height: 1.8),
                ),
                const SizedBox(height: 20),
                if (current.isNotEmpty) ...[
                  const Text(
                    '지금 쓰던 글에서',
                    style: TextStyle(color: muted, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(current, style: const TextStyle(height: 1.7)),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const ValueKey('cafe-pin-sentence'),
                    onPressed: busy
                        ? null
                        : () => save(home.copy(pinned: current)),
                    child: const Text('이 문장을 액자에 걸기'),
                  ),
                ] else
                  const Text(
                    '필사하거나 쓴 문장을 이곳에 걸어 둘 수 있어요.',
                    style: TextStyle(height: 1.7),
                  ),
                if (home.pinned != null)
                  TextButton(
                    key: const ValueKey('cafe-unpin-sentence'),
                    onPressed: busy
                        ? null
                        : () => save(home.copy(clearPinned: true)),
                    child: const Text('액자 비우기'),
                  ),
                if (error case final message?)
                  Text(message, style: const TextStyle(color: burgundy)),
                if (notice case final message?)
                  Text(message, style: const TextStyle(color: muted)),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final line = CafeEditorial.today(widget.moment, home.topic),
        page = widget.page;
    final favorite = CafeSeat.values
        .where((s) => s.name == home.seat)
        .firstOrNull;
    if (page == 'memory') {
      return _memory(context, shortLine(widget.lastSentence));
    }
    return PopScope(
      canPop: !busy,
      child: Dialog(
        backgroundColor: const Color(0xfff7efdf),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 460,
            maxHeight: MediaQuery.sizeOf(context).height * .8,
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(switch (page) {
                        'today' => '오늘의 문장',
                        'letter' => '쓰는 인간의 쪽지',
                        'mood' => '공간의 시간',
                        _ => '나를 기다리는 자리',
                      }, style: const TextStyle(fontSize: 22)),
                    ),
                    PaperBackButton(label: '카페', enabled: !busy),
                  ],
                ),
                const Divider(height: 22),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (page == 'arrival') ...[
                          const Text(
                            '오늘은 한 줄만\n남겨도 좋아요.',
                            style: TextStyle(
                              fontSize: 26,
                              height: 1.7,
                              color: brandInk,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            favorite == null
                                ? '창밖을 바라보다가, 쓰고 싶을 때 노트를 펼쳐요.'
                                : '${favorite.label}에 좋아하는 물건과 노트를 놓아두었어요.',
                            style: const TextStyle(height: 1.7),
                          ),
                          const SizedBox(height: 20),
                          action(
                            favorite == null ? '비 오는 창가에서 쉬기' : '나의 자리로 돌아가기',
                            favorite == null
                                ? CafeRitualAction.rainWindow
                                : CafeRitualAction.returnSeat,
                            'cafe-return-home',
                          ),
                          if (favorite != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: TextButton(
                                key: const ValueKey('cafe-rain-window'),
                                onPressed: busy
                                    ? null
                                    : () => Navigator.pop(
                                        context,
                                        CafeRitualAction.rainWindow,
                                      ),
                                child: const Text('비 오는 창가에서 쉬기'),
                              ),
                            ),
                          if (widget.currentSeat != null)
                            TextButton(
                              key: const ValueKey('cafe-remember-seat'),
                              onPressed: busy
                                  ? null
                                  : () => save(
                                      home.copy(
                                        seat: widget.currentSeat!.name,
                                        chair: widget.chair,
                                        clearChair: widget.chair == null,
                                      ),
                                    ),
                              child: const Text('지금 자리를 나의 자리로'),
                            ),
                        ],
                        if (page == 'today') ...[
                          Wrap(
                            spacing: 6,
                            children: [
                              for (
                                var i = 0;
                                i < CafeEditorial.topics.length;
                                i++
                              )
                                ChoiceChip(
                                  label: Text(CafeEditorial.topics[i]),
                                  selected: home.topic == i,
                                  onSelected: busy
                                      ? null
                                      : (_) => save(home.copy(topic: i)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            line.text,
                            key: const ValueKey('cafe-daily-sentence'),
                            style: const TextStyle(
                              fontSize: 24,
                              height: 1.9,
                              color: brandInk,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            line.citation,
                            style: const TextStyle(color: muted, fontSize: 14),
                          ),
                          const SizedBox(height: 24),
                          if (widget.canTranscribe)
                            action(
                              '이 문장 필사하기',
                              line,
                              'cafe-transcribe-sentence',
                            ),
                          const SizedBox(height: 8),
                          const Text(
                            '읽고 쉬어 가도 좋아요.',
                            style: TextStyle(color: muted, fontSize: 14),
                          ),
                        ],
                        if (page == 'letter') ...[
                          Text(
                            CafeEditorial.letter(widget.moment),
                            key: const ValueKey('cafe-weekly-letter'),
                            style: const TextStyle(fontSize: 20, height: 1.9),
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            '쓰는 인간이 준비한 네 편의 쪽지를 주마다 한 편씩 펼쳐요.',
                            style: TextStyle(
                              color: muted,
                              fontSize: 14,
                              height: 1.6,
                            ),
                          ),
                        ],
                        if (page == 'mood') ...[
                          const Text(
                            '머물고 싶은 시간을 골라 보세요.',
                            style: TextStyle(height: 1.7),
                          ),
                          const SizedBox(height: 12),
                          for (var i = 0; i < 3; i++)
                            ListTile(
                              key: ValueKey('cafe-mood-$i'),
                              selected: home.mood == i,
                              leading: Icon(
                                home.mood == i
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                              ),
                              onTap: busy
                                  ? null
                                  : () => save(home.copy(mood: i)),
                              title: Text(['따뜻한 낮', '해 질 무렵', '조용한 저녁'][i]),
                            ),
                          const Text(
                            '내 공간의 연출이에요. 소리는 카페 위쪽에서 따로 켤 수 있어요.',
                            style: TextStyle(
                              color: muted,
                              fontSize: 14,
                              height: 1.7,
                            ),
                          ),
                        ],
                        if (error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            error!,
                            style: const TextStyle(
                              color: burgundy,
                              height: 1.6,
                            ),
                          ),
                          TextButton(
                            key: const ValueKey('cafe-ritual-retry'),
                            onPressed: busy ? null : () => save(home),
                            child: const Text('다시 저장'),
                          ),
                        ] else if (notice != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              notice!,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
