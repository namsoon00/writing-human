import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../source/source_intake.dart';
import 'source_browser_native.dart'
    if (dart.library.js_interop) 'source_browser_web.dart'
    as browser;

Future<String> readSourceExcerpt() async {
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  final text = normalizeSource(data?.text ?? '');
  if (text.isEmpty) throw const FormatException('복사한 글이 없어요.');
  if (text.length > sourceLengthLimit) {
    throw const FormatException('구절이 너무 길어요. 필요한 부분만 복사해 주세요.');
  }
  return text;
}

typedef SourceBrowserChoice = ({String? text, SourcePhoto? photo});

Future<SourceBrowserChoice?> openSourceBrowser(
  BuildContext context, {
  required Uri url,
  required String title,
  required String launchLabel,
  required bool hasCitation,
  Future<SourcePhoto?> Function()? pickScreenshot,
}) => Navigator.of(context).push<SourceBrowserChoice>(
  MaterialPageRoute<SourceBrowserChoice>(
    fullscreenDialog: true,
    builder: (_) => _SourceBrowser(
      url: url,
      title: title,
      launchLabel: launchLabel,
      hasCitation: hasCitation,
      pickScreenshot: pickScreenshot,
    ),
  ),
);

class _SourceBrowser extends StatefulWidget {
  const _SourceBrowser({
    required this.url,
    required this.title,
    required this.launchLabel,
    required this.hasCitation,
    this.pickScreenshot,
  });

  final Uri url;
  final String title, launchLabel;
  final bool hasCitation;
  final Future<SourcePhoto?> Function()? pickScreenshot;

  @override
  State<_SourceBrowser> createState() => _SourceBrowserState();
}

class _SourceBrowserState extends State<_SourceBrowser> {
  bool _collecting = false, _opening = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (browser.openOnEntry) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.isCurrentOf(context) == true) _launch();
      });
    }
  }

  Future<void> _launch() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    var opened = false;
    try {
      opened = await browser.launchSourcePage(widget.url);
    } on Exception {
      // Import actions remain available if launching the browser fails.
    }
    if (!mounted) return;
    setState(() {
      _opening = false;
      if (!opened) _error = '브라우저를 열지 못했어요.';
    });
  }

  Future<void> _collect(
    Future<SourceBrowserChoice?> Function() read, {
    required String failure,
  }) async {
    if (_collecting) return;
    setState(() {
      _collecting = true;
      _error = null;
    });
    try {
      final choice = await read();
      if (choice != null &&
          mounted &&
          ModalRoute.isCurrentOf(context) == true) {
        Navigator.pop(context, choice);
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on SourceIntakeException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Exception {
      if (mounted) setState(() => _error = failure);
    } finally {
      if (mounted) setState(() => _collecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = browser.embeddedSourcePage(widget.url);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '원문 브라우저 닫기',
          icon: const Icon(CupertinoIcons.xmark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (page != null)
            TextButton(
              onPressed: _opening ? null : _launch,
              child: Text(widget.launchLabel),
            ),
        ],
      ),
      body:
          page ??
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.url.host),
                  const SizedBox(height: 12),
                  Text(
                    widget.pickScreenshot != null
                        ? '웹에서 글을 복사하거나 화면을 캡처한 뒤 돌아오세요.'
                        : browser.collectionInstructions,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _opening ? null : _launch,
                    icon: const Icon(CupertinoIcons.globe, size: 17),
                    label: Text(widget.launchLabel),
                  ),
                ],
              ),
            ),
          ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error case final error?)
              Semantics(
                liveRegion: true,
                child: Text(error, textAlign: TextAlign.center),
              ),
            FilledButton.icon(
              onPressed: _collecting
                  ? null
                  : () => _collect(
                      () async =>
                          (text: await readSourceExcerpt(), photo: null),
                      failure: '붙여넣지 못했어요. 글을 다시 복사해 주세요.',
                    ),
              icon: const Icon(CupertinoIcons.doc_on_clipboard, size: 17),
              label: Text(widget.hasCitation ? '복사한 글과 출처 가져오기' : '복사한 글 가져오기'),
            ),
            if (widget.pickScreenshot case final pick?)
              OutlinedButton.icon(
                onPressed: _collecting
                    ? null
                    : () => _collect(() async {
                        final photo = await pick();
                        return photo == null
                            ? null
                            : (text: null, photo: photo);
                      }, failure: '캡처를 가져오지 못했어요. 다시 골라 주세요.'),
                icon: const Icon(CupertinoIcons.photo, size: 17),
                label: const Text('캡처 가져오기'),
              ),
          ],
        ),
      ),
    );
  }
}
