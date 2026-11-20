import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/brand_read_aloud.dart';
import '../audio/narration_model_assets.dart';
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
        brandSpeech: ModelReadAloud.new,
        preferences: SharedPreferencesAsync(),
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
    BrandReadAloud Function(
      NarrationVoice voice,
      ValueChanged<double?> progress,
    );

const _voiceKey = 'narration.voice.v1';

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
    required this.speech,
    required this.color,
    required this.bookTitle,
    required this.pages,
    required this.current,
    this.brandSpeech,
    this.preferences,
  });

  final ReadAloud speech;
  final NarrationFactory? brandSpeech;
  final SharedPreferencesAsync? preferences;
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
  late NarrationVoice _voice = widget.brandSpeech == null
      ? NarrationVoice.device
      : NarrationVoice.f3;
  bool _voiceTouched = false;
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
    unawaited(_restoreVoice());
  }

  Future<void> _restoreVoice() async {
    try {
      final name = await widget.preferences?.getString(_voiceKey);
      if (!mounted || _voiceTouched || widget.brandSpeech == null) return;
      final voice = NarrationVoice.values
          .where((item) => item.name == name)
          .firstOrNull;
      if (voice != null) setState(() => _voice = voice);
    } catch (_) {
      // A failed preference read leaves the default F3 available.
    }
  }

  Future<void> _selectVoice(NarrationVoice voice) async {
    _voiceTouched = true;
    setState(() {
      _voice = voice;
      _message = null;
    });
    try {
      await widget.preferences?.setString(_voiceKey, voice.name);
    } catch (_) {
      if (mounted && _voice == voice && _playback == null) {
        setState(() => _message = '목소리 선택을 저장하지 못했어요.');
      }
    }
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
    final source = _brandVoice ?? widget.speech;
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
    _voiceTouched = true;
    final playback = Completer<void>();
    final brandVoice = _voice == NarrationVoice.device
        ? null
        : widget.brandSpeech?.call(_voice, (progress) {
            if (mounted && _playback == playback) {
              setState(() => _modelProgress = progress);
            }
          });
    final cues = _cues(_selection, brandVoice == null ? 180 : 120).iterator;
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
        final spoken = brandVoice == null
            ? widget.speech.speak(cue.text)
            : brandVoice.speak(
                cue.text,
                next: hasCue ? cues.current.text : null,
              );
        await Future.any([
          spoken,
          playback.future,
        ]).timeout(Duration(minutes: brandVoice == null ? 2 : 15));
        if (_playback != playback) return;
      }
      if (brandVoice != null) {
        await brandVoice.stop().timeout(const Duration(seconds: 5));
        if (_playback != playback) return;
      }
      setState(() {
        _playback = null;
        _brandVoice = null;
        _pageNumber = null;
        _modelProgress = null;
        _message = '낭독을 마쳤어요.';
      });
    } on KoreanVoiceUnavailable {
      if (_playback != playback) return;
      setState(() {
        _playback = null;
        _brandVoice = null;
        _pageNumber = null;
        _modelProgress = null;
        _message = '사용할 수 있는 한국어 음성이 없어요. 기기의 음성 설정에서 한국어 음성을 설치해 주세요.';
      });
    } catch (_) {
      if (_playback != playback) return;
      await _stop();
      if (mounted && _message == null) {
        setState(() {
          _message = brandVoice == null
              ? '낭독을 재생하지 못했어요. 다시 시도해 주세요.'
              : 'AI 음성을 재생하지 못했어요. 잠시 후 다시 시도하거나 기기 음성을 선택해 주세요.';
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
    ]);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('음성 모델 사용 조건'),
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
        ? '$_pageNumber쪽 ${_brandVoice == null ? '재생' : '낭독'} 중'
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
                  if (widget.brandSpeech != null) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: [
                        for (final voice in NarrationVoice.values)
                          ChoiceChip(
                            label: Text(voice.label),
                            selected: _voice == voice,
                            selectedColor: panelSelectedColor(widget.color),
                            onSelected: playing || _stopping
                                ? null
                                : (_) => _selectVoice(voice),
                          ),
                      ],
                    ),
                    if (_voice != NarrationVoice.device) ...[
                      const SizedBox(height: 8),
                      Text(
                        '첫 재생 때 AI 음성 모델 약 ${narrationDownloadMegabytes}MB를 받아요.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: muted),
                      ),
                      Center(
                        child: TextButton(
                          onPressed: playing ? null : _showModelLicense,
                          child: const Text('음성 모델 사용 조건'),
                        ),
                      ),
                    ],
                  ],
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
