import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/brand_read_aloud.dart';
import '../audio/narration_model_assets.dart';
import '../audio/read_aloud.dart';
import '../data/model.dart';
import 'paper.dart';
import 'paper_panel.dart';

Future<void> showReadAloud(
  BuildContext context, {
  required Library library,
  required Color color,
  Book? book,
  WritingPage? page,
}) {
  final volume = library.volumePages(
    bookId: book?.id,
    recordId: page?.recordId,
  );
  final pageIndex = volume.indexWhere((entry) => entry.id == page?.id);
  return Navigator.of(context).push(
    paperPanelRoute<void>(
      (_) => ReadAloudScreen(
        createSpeech: ModelReadAloud.new,
        color: color,
        bookTitle: book?.title,
        pages: [
          if (book != null)
            for (final (index, page) in volume.indexed)
              if (page.text.trim().isNotEmpty)
                (number: index + 1, text: page.text),
        ],
        current: page == null
            ? null
            : (
                number: pageIndex < 0 ? page.number : pageIndex + 1,
                text: page.text,
              ),
      ),
      color: color,
    ),
  );
}

typedef NarrationPage = ({int number, String text});
typedef _Cue = ({int page, String text, Duration pauseBefore});
typedef NarrationFactory =
    BrandReadAloud Function(ValueChanged<double?> progress);

Iterable<_Cue> _cues(List<NarrationPage> pages, int limit) sync* {
  for (final (index, page) in pages.indexed) {
    for (final (part, phrase) in readAloudPhrases(
      page.text,
      limit: limit,
    ).indexed) {
      yield (
        page: page.number,
        text: phrase.text,
        pauseBefore: index > 0 && part == 0
            ? readAloudPagePause
            : phrase.pauseBefore,
      );
    }
  }
}

class ReadAloudScreen extends StatefulWidget {
  const ReadAloudScreen({
    super.key,
    required this.createSpeech,
    required this.color,
    required this.bookTitle,
    required this.pages,
    required this.current,
  });

  final NarrationFactory createSpeech;
  final Color color;
  final String? bookTitle;
  final List<NarrationPage> pages;
  final NarrationPage? current;

  @override
  State<ReadAloudScreen> createState() => _ReadAloudScreenState();
}

class _ReadAloudScreenState extends State<ReadAloudScreen>
    with WidgetsBindingObserver {
  late bool _book = widget.current == null;
  Completer<void>? _playback;
  bool _stopping = false;
  int? _pageNumber;
  String? _message;
  BrandReadAloud? _brandVoice;
  double? _modelProgress;

  List<NarrationPage> get _selection => _book
      ? widget.pages
      : [
          ?widget.current?.text.trim().isNotEmpty == true
              ? widget.current
              : null,
        ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      unawaited(_stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_stop(updateScreen: false));
    super.dispose();
  }

  Future<void> _stop({bool updateScreen = true}) async {
    final playback = _playback;
    if (playback == null) return;
    final source = _brandVoice!;
    _playback = null;
    _brandVoice = null;
    playback.complete();
    if (updateScreen) {
      setState(() {
        _stopping = true;
        _pageNumber = null;
        _modelProgress = null;
      });
    }
    try {
      await source.stop().timeout(const Duration(seconds: 5));
    } catch (_) {
      if (updateScreen && mounted) _message = '낭독을 멈추지 못했어요.';
    } finally {
      if (updateScreen && mounted) setState(() => _stopping = false);
    }
  }

  Future<void> _waitForBreath(Duration pause, Completer<void> playback) async {
    final elapsed = Completer<void>();
    final timer = Timer(pause, elapsed.complete);
    try {
      await Future.any([elapsed.future, playback.future]);
    } finally {
      timer.cancel();
    }
  }

  Future<void> _play() async {
    final playback = Completer<void>();
    final brandVoice = widget.createSpeech((progress) {
      if (mounted && _playback == playback) {
        setState(() => _modelProgress = progress);
      }
    });
    final cues = _cues(_selection, 120).iterator;
    var hasCue = cues.moveNext();
    setState(() {
      _playback = playback;
      _brandVoice = brandVoice;
      _message = null;
    });
    try {
      while (hasCue) {
        final cue = cues.current;
        hasCue = cues.moveNext();
        if (cue.pauseBefore != Duration.zero) {
          await _waitForBreath(cue.pauseBefore, playback);
          if (_playback != playback) return;
        }
        if (_pageNumber != cue.page) {
          setState(() => _pageNumber = cue.page);
        }
        final spoken = brandVoice.speak(
          cue.text,
          next: hasCue ? cues.current.text : null,
        );
        await Future.any([
          spoken,
          playback.future,
        ]).timeout(const Duration(minutes: 15));
        if (_playback != playback) return;
      }
      await brandVoice.stop().timeout(const Duration(seconds: 5));
      if (_playback != playback) return;
      setState(() {
        _playback = null;
        _brandVoice = null;
        _pageNumber = null;
        _modelProgress = null;
        _message = '낭독을 마쳤어요.';
      });
    } catch (_) {
      if (_playback != playback) return;
      await _stop();
      if (mounted && _message == null) {
        setState(() {
          _message = '낭독을 재생하지 못했어요. 잠시 후 다시 시도해 주세요.';
        });
      }
    }
  }

  void _select(bool book) {
    setState(() {
      _book = book;
      _message = null;
    });
  }

  Future<void> _showModelLicense() async {
    final licenses = await Future.wait([
      rootBundle.loadString('assets/audio/supertonic-license.txt'),
      rootBundle.loadString('assets/audio/supertonic-code-license.txt'),
      rootBundle.loadString('assets/audio/signalsmith-code-license.txt'),
    ]);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('음성 사용 조건'),
        scrollable: true,
        content: SelectableText(licenses.join('\n\n')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playing = _playback != null;
    final empty = _selection.isEmpty;
    final progress = _modelProgress;
    final status = progress != null
        ? (progress < 1
              ? '음성 모델 준비 중 · ${(progress * 100).round()}%'
              : '음성을 만드는 중')
        : _pageNumber != null
        ? '$_pageNumber쪽 낭독 중'
        : _message ?? (empty ? '읽을 필사 본문이 없어요.' : null);
    return PopScope<void>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(_stop(updateScreen: false));
      },
      child: PaperPanel(
        color: widget.color,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 6, 12, 8),
              child: PaperPanelHeader('낭독'),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                children: [
                  if (widget.bookTitle case final title?)
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, color: ink),
                    ),
                  if (widget.bookTitle != null && widget.current != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        children: [
                          for (final (book, label) in [
                            (false, '이 쪽'),
                            (true, '책 전체'),
                          ])
                            ChoiceChip(
                              label: Text(label),
                              selected: _book == book,
                              selectedColor: panelSelectedColor(widget.color),
                              onSelected: playing || _stopping
                                  ? null
                                  : (_) => _select(book),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  const Text('따뜻한 여성 목소리로 읽어요.', textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    '첫 재생 때 AI 음성 모델 약 ${narrationDownloadMegabytes}MB를 받아요.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: muted),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: playing ? null : _showModelLicense,
                      child: const Text('음성 사용 조건'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: FilledButton.icon(
                      onPressed: playing
                          ? _stop
                          : (empty || _stopping ? null : _play),
                      icon: Icon(
                        playing
                            ? CupertinoIcons.stop_fill
                            : CupertinoIcons.play_fill,
                        size: 16,
                      ),
                      label: Text(playing ? '정지' : '재생'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ),
                  if (status != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          status,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: muted),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
