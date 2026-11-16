import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../audio/read_aloud.dart';
import '../audio/read_aloud_native.dart'
    if (dart.library.js_interop) '../audio/read_aloud_web.dart';
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
  final speech = createReadAloud();
  return Navigator.of(context).push(
    paperPanelRoute<void>(
      (_) => ReadAloudScreen(
        speech: speech,
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

class ReadAloudScreen extends StatefulWidget {
  const ReadAloudScreen({
    super.key,
    required this.speech,
    required this.color,
    required this.bookTitle,
    required this.pages,
    required this.current,
  });

  final ReadAloud speech;
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
    _playback = null;
    playback.complete();
    if (updateScreen) {
      setState(() {
        _stopping = true;
        _pageNumber = null;
      });
    }
    try {
      await widget.speech.stop().timeout(const Duration(seconds: 5));
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
    final selection = _selection;
    final playback = Completer<void>();
    setState(() {
      _playback = playback;
      _message = null;
    });
    try {
      for (final (index, page) in selection.indexed) {
        if (index > 0) {
          await _waitForBreath(readAloudPagePause, playback);
          if (_playback != playback) return;
        }
        setState(() => _pageNumber = page.number);
        for (final phrase in readAloudPhrases(page.text)) {
          if (phrase.pauseBefore != Duration.zero) {
            await _waitForBreath(phrase.pauseBefore, playback);
            if (_playback != playback) return;
          }
          await Future.any([
            widget.speech.speak(phrase.text),
            playback.future,
          ]).timeout(const Duration(minutes: 2));
          if (_playback != playback) return;
        }
      }
      setState(() {
        _playback = null;
        _pageNumber = null;
        _message = '낭독을 마쳤어요.';
      });
    } on KoreanVoiceUnavailable {
      if (_playback != playback) return;
      setState(() {
        _playback = null;
        _pageNumber = null;
        _message = '사용할 수 있는 한국어 음성이 없어요. 기기의 음성 설정에서 한국어 음성을 설치해 주세요.';
      });
    } catch (_) {
      if (_playback != playback) return;
      await _stop();
      if (mounted && _message == null) {
        setState(() => _message = '낭독을 재생하지 못했어요. 다시 시도해 주세요.');
      }
    }
  }

  void _select(bool book) {
    setState(() {
      _book = book;
      _message = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final playing = _playback != null;
    final empty = _selection.isEmpty;
    final status = _pageNumber != null
        ? '$_pageNumber쪽 재생 중'
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
