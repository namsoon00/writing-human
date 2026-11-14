import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../source/source_intake.dart';

enum _Collection {
  works('위키문헌', 'ko.wikisource.org'),
  quotes('위키인용집', 'ko.wikiquote.org');

  const _Collection(this.label, this.host);
  final String label, host;

  Future<List<_SourceHit>> search(
    http.Client client,
    String query, {
    required bool byTitle,
  }) async {
    final response = await client
        .get(
          Uri.https(host, '/w/api.php', {
            'action': 'query',
            'list': 'search',
            'srsearch': byTitle ? 'intitle:"$query"' : '"$query"',
            'srnamespace': '0',
            'srprop': '',
            'srlimit': '8',
            'format': 'json',
            'origin': '*',
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw http.ClientException('Search failed: ${response.statusCode}');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final rows = switch (data) {
      {'query': {'search': final List rows}} => rows,
      _ => throw const FormatException('Invalid search response'),
    };
    return [
      for (final row in rows)
        if (row case {'title': final String title, 'pageid': final int id})
          if (title.trim().isNotEmpty &&
              id > 0 &&
              (!byTitle || ' ${_words(title)} '.contains(' ${_words(query)} ')))
            _SourceHit(this, title, id),
    ];
  }
}

String _words(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^가-힣ㄱ-ㅎㅏ-ㅣ一-龯a-z0-9]+'), ' ')
    .trim();

typedef SourceSearchChoice = ({String citation, String? text});

class _SourceHit {
  const _SourceHit(this.collection, this.title, this.id);

  final _Collection collection;
  final String title;
  final int id;

  Uri get url => Uri.https(collection.host, '/w/index.php', {'curid': '$id'});
  String get citation {
    final suffix = ' · ${collection.label} · $url';
    final limit = 500 - suffix.length;
    if (title.length <= limit) return '$title$suffix';
    final prefix = StringBuffer();
    for (final character in title.characters) {
      if (prefix.length + character.length >= limit) break;
      prefix.write(character);
    }
    return '$prefix…$suffix';
  }
}

Future<SourceSearchChoice?> showSourceSearch(
  BuildContext context,
  Color paperColor,
) => showDialog<SourceSearchChoice>(
  context: context,
  builder: (_) => _SourceSearch(paperColor: paperColor),
);

class _SourceSearch extends StatefulWidget {
  const _SourceSearch({required this.paperColor});

  final Color paperColor;

  @override
  State<_SourceSearch> createState() => _SourceSearchState();
}

class _SourceSearchState extends State<_SourceSearch> {
  final _query = TextEditingController();
  final _client = http.Client();
  final _focus = FocusNode();
  String? _searched, _linkError;
  bool _loading = false, _byTitle = true, _pasting = false;
  _SourceHit? _selected;
  List<(_Collection, List<_SourceHit>?)> _results = const [];

  Future<void> _search() async {
    final value = _query.value;
    final query = value.text
        .replaceAll(RegExp(r'["“”«»]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (_loading ||
        _words(query).isEmpty ||
        (value.isComposingRangeValid && !value.composing.isCollapsed)) {
      return;
    }
    _focus.unfocus();
    setState(() {
      _searched = query;
      _linkError = null;
      _results = const [];
      _loading = true;
    });
    final byTitle = _byTitle;
    final collections = byTitle ? [_Collection.works] : _Collection.values;
    final results = await Future.wait(
      collections.map((collection) async {
        try {
          return (
            collection,
            await collection.search(_client, query, byTitle: byTitle),
          );
        } on Exception {
          return (collection, null);
        }
      }),
    );
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  Future<void> _open(Uri url) async {
    try {
      if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
    } on Exception {
      // Report when the platform cannot hand off to a browser.
    }
    if (mounted) setState(() => _linkError = '브라우저를 열지 못했어요.');
  }

  Future<void> _collect(_SourceHit hit) async {
    if (_pasting) return;
    setState(() {
      _pasting = true;
      _linkError = null;
    });
    String? error;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted) return;
      final text = normalizeSource(data?.text ?? '');
      if (text.isEmpty) {
        error = '복사한 구절이 없어요.';
      } else if (text.length > sourceLengthLimit) {
        error = '구절이 너무 길어요. 필요한 부분만 복사해 주세요.';
      } else {
        Navigator.pop(context, (citation: hit.citation, text: text));
        return;
      }
    } on Exception {
      error = '붙여넣지 못했어요. 구절을 다시 복사해 주세요.';
    } finally {
      if (mounted) {
        setState(() {
          _pasting = false;
          _linkError = error;
        });
      }
    }
  }

  Widget _details(_SourceHit hit) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(hit.title, style: Theme.of(context).textTheme.titleMedium),
      Text(hit.collection.label),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _pasting ? null : () => _open(hit.url),
        icon: const Icon(CupertinoIcons.arrow_up_right, size: 16),
        label: const Text('원문 열기'),
      ),
      const SizedBox(height: 8),
      FilledButton(
        onPressed: _pasting ? null : () => _collect(hit),
        child: const Text('복사한 구절과 출처 넣기'),
      ),
      TextButton(
        onPressed: _pasting
            ? null
            : () =>
                  Navigator.pop(context, (citation: hit.citation, text: null)),
        child: const Text('출처만 넣기'),
      ),
      if (_linkError case final error?)
        Semantics(liveRegion: true, child: Text(error)),
    ],
  );

  @override
  void dispose() {
    _client.close();
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searched = _searched;
    final selected = _selected;
    final hasHits = _results.any((entry) => entry.$2?.isNotEmpty ?? false);
    return Dialog(
      backgroundColor: widget.paperColor,
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 500,
        height: 550,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 6, 0),
              child: Row(
                children: [
                  if (selected != null)
                    IconButton(
                      tooltip: '검색 결과로 돌아가기',
                      onPressed: _pasting
                          ? null
                          : () => setState(() {
                              _selected = null;
                              _linkError = null;
                            }),
                      icon: const Icon(CupertinoIcons.chevron_back, size: 18),
                    ),
                  Expanded(
                    child: Text(
                      selected == null ? '시·문장 검색' : '자료 가져오기',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: '검색 닫기',
                    onPressed: _pasting ? null : () => Navigator.pop(context),
                    icon: const Icon(CupertinoIcons.xmark, size: 18),
                  ),
                ],
              ),
            ),
            if (selected != null)
              Expanded(child: _details(selected))
            else ...[
              Wrap(
                spacing: 8,
                children: [
                  for (final byTitle in [true, false])
                    ChoiceChip(
                      label: Text(byTitle ? '작품 제목' : '기억나는 구절'),
                      selected: _byTitle == byTitle,
                      onSelected: _loading
                          ? null
                          : (_) => setState(() {
                              _byTitle = byTitle;
                              _searched = null;
                              _linkError = null;
                              _results = const [];
                            }),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _query,
                        focusNode: _focus,
                        enabled: !_loading,
                        maxLength: 160,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _search(),
                        decoration: InputDecoration(
                          hintText: _byTitle
                              ? '작품 제목을 입력하세요'
                              : '기억나는 구절을 입력하세요',
                          labelText: '검색어',
                          counterText: '',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '자료 검색',
                      onPressed: _loading ? null : _search,
                      icon: const Icon(CupertinoIcons.search, size: 19),
                    ),
                  ],
                ),
              ),
              if (_loading) const LinearProgressIndicator(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  children: [
                    if (searched == null)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          _byTitle
                              ? '위키문헌에서 제목이 맞는 작품을 찾아요.'
                              : '위키문헌과 위키인용집에서 같은 구절을 찾아요.',
                        ),
                      )
                    else if (!_loading &&
                        !hasHits &&
                        _results.every((entry) => entry.$2 != null))
                      const ListTile(title: Text('일치하는 자료가 없어요.')),
                    if (_linkError case final error?)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Semantics(liveRegion: true, child: Text(error)),
                      ),
                    for (final (collection, hits) in _results)
                      if (hits == null || hits.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                          child: Semantics(
                            header: true,
                            child: Text(
                              collection.label,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        ),
                        if (hits == null)
                          const ListTile(title: Text('검색 결과를 가져오지 못했어요.'))
                        else
                          for (final hit in hits)
                            ListTile(
                              title: Text(hit.title),
                              trailing: const Icon(
                                CupertinoIcons.chevron_right,
                                size: 15,
                              ),
                              onTap: () => setState(() {
                                _selected = hit;
                                _linkError = null;
                              }),
                            ),
                      ],
                    if (searched != null && !_loading && !hasHits)
                      TextButton.icon(
                        onPressed: () => _open(
                          Uri.https('search.naver.com', '/search.naver', {
                            'query': searched,
                          }),
                        ),
                        icon: const Icon(
                          CupertinoIcons.arrow_up_right,
                          size: 16,
                        ),
                        label: const Text('네이버에서 더 찾기'),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
