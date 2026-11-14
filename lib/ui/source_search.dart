import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../source/source_intake.dart';
import '../source/wikisource_preview.dart';

enum _Collection {
  works('위키문헌', 'ko.wikisource.org'),
  quotes('위키인용집', 'ko.wikiquote.org');

  const _Collection(this.label, this.host);
  final String label, host;

  Future<List<_SourceHit>> search(
    http.Client client,
    String query, {
    required _SearchMode mode,
  }) async {
    final authors = mode == _SearchMode.author;
    final module = authors ? 'prefixsearch' : 'search';
    final response = await client
        .get(
          Uri.https(host, '/w/api.php', {
            'action': 'query',
            'list': module,
            if (authors) ...{
              'pssearch': query,
              'psnamespace': '100',
              'pslimit': '8',
            } else ...{
              'srsearch': mode == _SearchMode.title
                  ? 'intitle:${_titleQuery(query)}'
                  : '"$query"',
              'srnamespace': '0',
              'srprop': '',
              'srlimit': mode == _SearchMode.title ? '30' : '8',
            },
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
      {'query': final Map query} when query[module] is List =>
        query[module] as List,
      _ => throw const FormatException('Invalid search response'),
    };
    final hits = <_SourceHit>[];
    for (final row in rows) {
      if (row case {
        'title': final String title,
        'pageid': final int id,
      } when title.trim().isNotEmpty && id > 0) {
        hits.add(_SourceHit(this, title, id));
      }
    }
    if (mode != _SearchMode.title) return hits;

    final compact = _compact(query);
    // Use the individual work title when the page is inside a collection.
    final exact = <_SourceHit>[];
    final prefixes = <_SourceHit>[];
    for (final hit in hits) {
      final title = _workTitle(hit.title);
      if (title == compact) {
        exact.add(hit);
      } else if (compact.length >= 3 && title.startsWith(compact)) {
        prefixes.add(hit);
      }
    }
    return [
      for (final matches in [exact, prefixes]) ...[
        ...matches.where((hit) => hit.poem != null),
        ...matches.where((hit) => hit.poem == null),
      ],
    ].take(12).toList();
  }
}

enum _SearchMode {
  title('작품 제목', '작품 제목을 입력하세요', '위키문헌에서 작품의 제목을 찾아요.'),
  author('작가 이름', '작가 이름을 입력하세요', '위키문헌의 작가 페이지에서 작품 목록을 볼 수 있어요.'),
  phrase('기억나는 구절', '기억나는 구절을 입력하세요', '위키문헌과 위키인용집에서 같은 구절을 찾아요.');

  const _SearchMode(this.label, this.hint, this.help);

  final String label, hint, help;
}

String _workTitle(String title) {
  final leaf = title.split('/').last;
  return _compact(leaf.replaceFirst(RegExp(r'\s*\([^()]+\)$'), ''));
}

String _titleQuery(String query) {
  final compact = _compact(query);
  return RegExp(r'^[가-힣]+$').hasMatch(compact) ? compact : '"$query"';
}

String _compact(String value) => _words(value).replaceAll(' ', '');

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

  WikisourcePoem? get poem =>
      collection == _Collection.works ? WikisourcePoem.reviewed[id] : null;

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
  bool _loading = false, _pasting = false;
  _SearchMode _mode = _SearchMode.title;
  _SourceHit? _selected;
  Future<List<String>>? _preview;
  final _stanzas = <int>{};
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
    final mode = _mode;
    final collections = mode == _SearchMode.phrase
        ? _Collection.values
        : [_Collection.works];
    final results = await Future.wait(
      collections.map((collection) async {
        try {
          return (
            collection,
            await collection.search(_client, query, mode: mode),
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

  void _showHit(_SourceHit hit) {
    setState(() {
      _selected = hit;
      _linkError = null;
      _stanzas.clear();
      _preview = hit.poem?.load(_client);
    });
  }

  Widget _previewBody(
    _SourceHit hit,
    WikisourcePoem poem,
    Future<List<String>> preview,
  ) => FutureBuilder<List<String>>(
    future: preview,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      final stanzas = snapshot.data;
      if (stanzas == null) {
        return _details(hit, previewFailed: true);
      }
      return Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Text(
                  poem.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text('${poem.author} · 위키문헌'),
                const SizedBox(height: 8),
                const Text('필사할 연을 골라 주세요.'),
                for (var index = 0; index < stanzas.length; index++)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _stanzas.contains(index),
                    title: Text(stanzas[index]),
                    onChanged: (selected) => setState(() {
                      if (selected == true) {
                        _stanzas.add(index);
                      } else {
                        _stanzas.remove(index);
                      }
                    }),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _open(poem.url),
                    child: const Text('위키문헌에서 원문 보기'),
                  ),
                ),
                if (_linkError case final error?)
                  Semantics(liveRegion: true, child: Text(error)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, (
                    citation: poem.citation,
                    text: stanzas.join('\n\n'),
                  )),
                  child: const Text('전체 담기'),
                ),
                FilledButton(
                  onPressed: _stanzas.isEmpty
                      ? null
                      : () {
                          final selected = _stanzas.toList()..sort();
                          Navigator.pop(context, (
                            citation: poem.citation,
                            text: selected
                                .map((index) => stanzas[index])
                                .join('\n\n'),
                          ));
                        },
                  child: const Text('선택한 구절 담기'),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );

  Widget _details(_SourceHit hit, {bool previewFailed = false}) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(hit.title, style: Theme.of(context).textTheme.titleMedium),
      Text(hit.collection.label),
      if (previewFailed) ...[
        const Text('원문 미리보기를 불러오지 못했어요.'),
        TextButton(
          onPressed: _pasting ? null : () => _showHit(hit),
          child: const Text('다시 시도'),
        ),
      ],
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _pasting ? null : () => _open(hit.url),
        icon: const Icon(CupertinoIcons.arrow_up_right, size: 16),
        label: Text(_mode == _SearchMode.author ? '작품 목록 열기' : '원문 열기'),
      ),
      if (_mode != _SearchMode.author) ...[
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _pasting ? null : () => _collect(hit),
          child: const Text('복사한 구절과 출처 넣기'),
        ),
        TextButton(
          onPressed: _pasting
              ? null
              : () => Navigator.pop(context, (
                  citation: hit.citation,
                  text: null,
                )),
          child: const Text('출처만 넣기'),
        ),
      ],
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
    final preview = _preview;
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
                              _preview = null;
                              _linkError = null;
                            }),
                      icon: const Icon(CupertinoIcons.chevron_back, size: 18),
                    ),
                  Expanded(
                    child: Text(
                      selected == null
                          ? '시·문장 검색'
                          : preview != null
                          ? '원문 미리보기'
                          : '자료 가져오기',
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
              Expanded(
                child: preview == null
                    ? _details(selected)
                    : _previewBody(selected, selected.poem!, preview),
              )
            else ...[
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final mode in _SearchMode.values)
                    ChoiceChip(
                      label: Text(mode.label),
                      selected: _mode == mode,
                      onSelected: _loading
                          ? null
                          : (_) => setState(() {
                              _mode = mode;
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
                          hintText: _mode.hint,
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
                        child: Text(_mode.help),
                      )
                    else if (!_loading &&
                        !hasHits &&
                        _results.every((entry) => entry.$2 != null))
                      const ListTile(title: Text('이 자료에서 찾지 못했어요.')),
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
                              subtitle: hit.poem == null
                                  ? null
                                  : const Text('원문 미리보기'),
                              onTap: () => _showHit(hit),
                            ),
                      ],
                    if (searched != null && !_loading)
                      TextButton.icon(
                        onPressed: () => _open(
                          Uri.https('search.naver.com', '/search.naver', {
                            'query': switch (_mode) {
                              _SearchMode.title => '$searched 원문',
                              _SearchMode.author => '$searched 작품',
                              _SearchMode.phrase => '$searched 구절 출처',
                            },
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
