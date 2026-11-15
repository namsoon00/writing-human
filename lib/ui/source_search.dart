import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import '../data/library_search.dart';

import '../source/wikisource_preview.dart';
import 'source_browser.dart';
import 'paper_panel.dart';
import 'paper_search_field.dart';
import 'search_completions.dart';

enum _Collection {
  works('위키문헌', 'ko.wikisource.org'),
  quotes('위키인용집', 'ko.wikiquote.org');

  const _Collection(this.label, this.host);
  final String label, host;

  Future<List<String>> complete(
    http.Client client,
    String query,
    _SearchMode mode,
  ) async {
    final authors = mode == _SearchMode.author;
    final phrase = mode == _SearchMode.phrase;
    final module = authors ? 'prefixsearch' : 'search';
    final words = _words(query).split(' ');
    final titleTerms = RegExp(r'^[가-힣]+$').hasMatch(_compact(query))
        ? [_compact(query)]
        : words;
    final response = await client
        .get(
          Uri.https(host, '/w/api.php', {
            'action': 'query',
            'list': module,
            if (authors) ...{
              'pssearch': query,
              'psnamespace': '100',
              'pslimit': '6',
            } else ...{
              'srsearch': phrase
                  ? [
                      if (words.length > 1)
                        '"${words.take(words.length - 1).join(' ')}"',
                      '${words.last}*',
                    ].join(' ')
                  : [
                      ...titleTerms
                          .take(titleTerms.length - 1)
                          .map((term) => 'intitle:$term'),
                      'intitle:${titleTerms.last}*',
                    ].join(' '),
              'srnamespace': '0',
              'srlimit': '6',
              'srprop': phrase ? 'snippet' : '',
            },
            'format': 'json',
            'origin': '*',
          }),
        )
        .timeout(const Duration(seconds: 4));
    if (response.statusCode != 200) return const [];
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data case {'query': final Map results} when results[module] is List) {
      final rows = results[module] as List;
      if (phrase) {
        return [
          for (final row in rows)
            if (row case {'snippet': final String markup})
              (html.parseFragment(markup).text ?? '').replaceAll(
                RegExp(r'\s+'),
                ' ',
              ),
        ];
      }
      return [
        for (final row in rows)
          if (row case {'title': final String title})
            title.split('/').last.replaceFirst('저자:', '').trim(),
      ];
    }
    return const [];
  }

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
    final listed = hits.map((hit) => hit.id).toSet();
    for (final poem in WikisourcePoem.reviewed.values) {
      if (!listed.contains(poem.pageId) && _compact(poem.title) == compact) {
        hits.add(_SourceHit(this, poem.title, poem.pageId));
      }
    }
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

typedef SourceSearchChoice = ({String? citation, String? text});

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
) => Navigator.of(context).push(
  paperPanelRoute<SourceSearchChoice>(
    (_) => _SourceSearch(paperColor: paperColor),
    color: paperColor,
  ),
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
  bool _webSearch = false;
  _SearchMode _mode = _SearchMode.title;
  _SourceHit? _selected;
  Future<List<String>>? _preview;
  final _stanzas = <int>{};
  List<(_Collection, List<_SourceHit>?)> _results = const [];

  Timer? _completionDelay;
  (_SearchMode, String)? _completionQuery;
  int _completionVersion = 0;
  List<String> _remoteSearchText = const [];

  @override
  void initState() {
    super.initState();
    _query.addListener(_queueCompletions);
    _focus.addListener(_queueCompletions);
  }

  void _queueCompletions() {
    final query = searchQueryThroughCaret(_query.value)?.trimLeft();
    final next =
        _webSearch &&
            _focus.hasFocus &&
            !_loading &&
            query != null &&
            _words(query).characters.length >= 2
        ? (_mode, query)
        : null;
    if (_completionQuery == next) return;
    _completionDelay?.cancel();
    _completionQuery = next;
    final version = ++_completionVersion;
    if (_remoteSearchText.isNotEmpty) {
      setState(() => _remoteSearchText = const []);
    }
    if (next != null) {
      _completionDelay = Timer(const Duration(milliseconds: 350), () async {
        final (mode, text) = next;
        final collections = mode == _SearchMode.phrase
            ? _Collection.values
            : [_Collection.works];
        final results = await Future.wait(
          collections.map((collection) async {
            try {
              return await collection.complete(_client, text, mode);
            } on Exception {
              return const <String>[];
            }
          }),
        );
        if (mounted && _completionVersion == version) {
          setState(
            () => _remoteSearchText = results.expand((rows) => rows).toList(),
          );
        }
      });
    }
  }

  Iterable<String> _completions(String query) {
    final terms = switch (_mode) {
      _SearchMode.title => WikisourcePoem.reviewed.values.map(
        (poem) => poem.title,
      ),
      _SearchMode.author => WikisourcePoem.reviewed.values.map(
        (poem) => poem.author,
      ),
      _SearchMode.phrase => const <String>[],
    };
    return searchCompletions(query, [...terms, ..._remoteSearchText]);
  }

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

  Future<void> _open(Uri url, {required String title, String? citation}) async {
    final excerpt = await openSourceBrowser(
      context,
      url: url,
      title: title,
      hasCitation: citation != null,
      launchLabel: kIsWeb ? '새 탭에서 열기' : '웹페이지 열기',
    );
    if (mounted && excerpt != null) {
      Navigator.pop(context, (citation: citation, text: excerpt));
    }
  }

  Future<void> _collect(_SourceHit hit) async {
    if (_pasting) return;
    setState(() {
      _pasting = true;
      _linkError = null;
    });
    String? error;
    try {
      final text = await readSourceExcerpt();
      if (!mounted) return;
      Navigator.pop(context, (citation: hit.citation, text: text));
    } on FormatException catch (exception) {
      error = exception.message;
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
                    onPressed: () => _open(
                      poem.url,
                      title: poem.title,
                      citation: poem.citation,
                    ),
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
      if (_mode != _SearchMode.author) ...[
        const SizedBox(height: 12),
        const Text('원문에서 구절을 복사한 뒤 ‘복사한 구절과 출처 담기’를 누르세요.'),
      ],
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _pasting
            ? null
            : () => _open(
                hit.url,
                title: hit.title,
                citation: _mode == _SearchMode.author ? null : hit.citation,
              ),
        icon: const Icon(CupertinoIcons.globe, size: 16),
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
    _completionDelay?.cancel();
    _query.removeListener(_queueCompletions);
    _focus.removeListener(_queueCompletions);
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
    return PopScope(
      canPop: !_pasting,
      child: PaperPanel(
        color: widget.paperColor,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 6, 0),
              child: Row(
                children: [
                  if (selected != null)
                    IconButton(
                      tooltip: _webSearch ? '검색 결과로 돌아가기' : '바로 담기 목록으로 돌아가기',
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
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  for (final web in [false, true])
                    ChoiceChip(
                      label: Text(web ? '웹 검색' : '바로 담기'),
                      selected: _webSearch == web,
                      onSelected: (_) {
                        _focus.unfocus();
                        setState(() => _webSearch = web);
                        _queueCompletions();
                      },
                    ),
                ],
              ),
              if (_webSearch) ...[
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
                            : (_) {
                                setState(() {
                                  _mode = mode;
                                  _searched = null;
                                  _linkError = null;
                                  _results = const [];
                                });
                                _queueCompletions();
                              },
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: PaperSearchField(
                          controller: _query,
                          focusNode: _focus,
                          enabled: !_loading,
                          maxLength: 160,
                          hint: _mode.hint,
                          label: '검색어',
                          showIcon: false,
                          onSubmitted: (_) => _search(),
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
                Flexible(
                  child: SearchCompletions(
                    controller: _query,
                    focusNode: _focus,
                    options: _completions,
                    onSelected: (_) => _search(),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          '‘복사 필요’가 표시된 자료는 웹에서 원문을 열고 원하는 구절을 복사해 주세요.',
                        ),
                      ),
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
                          child: Semantics(
                            liveRegion: true,
                            child: Text(error),
                          ),
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
                                subtitle: hit.poem != null
                                    ? const Text('원문 미리보기')
                                    : _mode == _SearchMode.author
                                    ? null
                                    : const Text('웹 원문 · 복사 필요'),
                                onTap: () => _showHit(hit),
                              ),
                        ],
                      if (searched != null && !_loading) ...[
                        TextButton.icon(
                          onPressed: () => _open(
                            Uri.https('search.naver.com', '/search.naver', {
                              'query': switch (_mode) {
                                _SearchMode.title => '$searched 원문',
                                _SearchMode.author => '$searched 작품',
                                _SearchMode.phrase => '$searched 구절 출처',
                              },
                            }),
                            title: '네이버 검색',
                          ),
                          icon: const Icon(CupertinoIcons.globe, size: 16),
                          label: const Text('네이버에서 더 찾기'),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('네이버에서 구절을 복사한 뒤 ‘복사한 구절 담기’를 누르세요.'),
                        ),
                      ],
                    ],
                  ),
                ),
              ] else
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('바로 담을 수 있는 시'),
                      ),
                      for (final poem in WikisourcePoem.reviewed.values)
                        ListTile(
                          title: Text(poem.title),
                          subtitle: Text(poem.author),
                          trailing: const Icon(
                            CupertinoIcons.chevron_right,
                            size: 15,
                          ),
                          onTap: () => _showHit(
                            _SourceHit(
                              _Collection.works,
                              poem.title,
                              poem.pageId,
                            ),
                          ),
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
