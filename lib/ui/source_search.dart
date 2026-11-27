import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import '../data/library_search.dart';
import '../data/model.dart';

import '../source/source_intake.dart';
import '../source/wikisource_preview.dart';
import 'original_list_item.dart';
import 'paper.dart';
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
    for (final work in WikisourceWork.reviewed.values) {
      if (!listed.contains(work.pageId) && _compact(work.title) == compact) {
        hits.add(_SourceHit(this, work.title, work.pageId));
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
        ...matches.where((hit) => hit.work != null),
        ...matches.where((hit) => hit.work == null),
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

class SourceSearchChoice {
  const SourceSearchChoice({this.citation, this.text, this.photo});

  final String? citation, text;
  final SourcePhoto? photo;
}

class _SourceHit {
  const _SourceHit(this.collection, this.title, this.id);

  final _Collection collection;
  final String title;
  final int id;

  WikisourceWork? get work =>
      collection == _Collection.works ? WikisourceWork.reviewed[id] : null;

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

/// Returns null if the user cancels replacement of an existing draft.
typedef CatalogTranscription =
    Future<bool?> Function(String text, String citation);

Future<SourceSearchChoice?> showSourceSearch(
  BuildContext context,
  WritingStyle style,
  SourceIntake intake, {
  CatalogTranscription? onCatalogTranscription,
}) async {
  final route = paperPanelRoute<SourceSearchChoice>(
    (_) => _SourceSearch(
      style: style,
      intake: intake,
      onCatalogTranscription: onCatalogTranscription,
    ),
    color: originalPanelColor,
  );
  final result = await Navigator.of(context).push(route);
  await route.completed;
  return result;
}

class _SourceSearch extends StatefulWidget {
  const _SourceSearch({
    required this.style,
    required this.intake,
    this.onCatalogTranscription,
  });

  final WritingStyle style;
  final SourceIntake intake;
  final CatalogTranscription? onCatalogTranscription;

  @override
  State<_SourceSearch> createState() => _SourceSearchState();
}

class _SourceSearchState extends State<_SourceSearch> {
  final _query = TextEditingController();
  final _client = http.Client();
  final _focus = FocusNode();
  final _catalogQuery = TextEditingController();
  final _catalogFocus = FocusNode();
  final _catalogScroll = ScrollController();
  String? _searched, _linkError;
  bool _loading = false, _importing = false;
  bool _webSearch = false;
  ({WikisourceWork work, String? text, String error})? _catalogRetry;
  WikisourceGenre? _catalogGenre;
  _SearchMode _mode = _SearchMode.title;
  _SourceHit? _selected;
  Future<List<String>?>? _preview;
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
      _SearchMode.title => WikisourceWork.reviewed.values.map(
        (work) => work.title,
      ),
      _SearchMode.author => WikisourceWork.reviewed.values.map(
        (work) => work.author,
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

  Future<SourcePhoto?> _pickScreenshot() =>
      widget.intake.pickPhoto(camera: false);

  Future<void> _open(Uri url, {required String title, String? citation}) async {
    final choice = await openSourceBrowser(
      context,
      url: url,
      title: title,
      hasCitation: citation != null,
      launchLabel: kIsWeb ? '새 탭에서 열기' : '웹페이지 열기',
      pickScreenshot: _pickScreenshot,
    );
    if (mounted && ModalRoute.isCurrentOf(context) == true && choice != null) {
      Navigator.pop(
        context,
        SourceSearchChoice(
          citation: citation,
          text: choice.text,
          photo: choice.photo,
        ),
      );
    }
  }

  Future<void> _collect(
    Future<SourceSearchChoice?> Function() read, {
    required String failure,
  }) async {
    if (_importing) return;
    setState(() {
      _importing = true;
      _linkError = null;
    });
    String? error;
    try {
      final choice = await read();
      if (mounted &&
          ModalRoute.isCurrentOf(context) == true &&
          choice != null) {
        Navigator.pop(context, choice);
      }
    } on FormatException catch (exception) {
      error = exception.message;
    } on SourceIntakeException catch (exception) {
      error = exception.message;
    } on Exception {
      error = failure;
    } finally {
      if (mounted) {
        setState(() {
          _importing = false;
          _linkError = error;
        });
      }
    }
  }

  Future<List<String>?> _loadPreview(WikisourceWork work) async {
    try {
      return await work.load(_client);
    } on Exception {
      return null;
    }
  }

  Future<void> _selectCatalogWork(WikisourceWork work, {String? text}) async {
    if (_importing) return;
    final transcribe = widget.onCatalogTranscription;
    if (transcribe == null) {
      _showHit(_SourceHit(_Collection.works, work.title, work.pageId));
      return;
    }
    _catalogFocus.unfocus();
    setState(() {
      _importing = true;
      _catalogRetry = null;
      _linkError = null;
    });
    String? error;
    try {
      final body = text ?? (await _loadPreview(work))?.join('\n\n');
      if (!mounted) return;
      if (body == null) {
        error = '원문을 불러오지 못했어요.';
      } else {
        text = body;
        final saved = await transcribe(body, work.citation);
        if (!mounted) return;
        if (saved == true && ModalRoute.isCurrentOf(context) == true) {
          Navigator.pop(context);
          return;
        }
        if (saved == false) error = '원문과 필사 쪽을 저장하지 못했어요.';
      }
    } on Exception {
      error = '원문과 필사 쪽을 저장하지 못했어요.';
    } finally {
      if (mounted) {
        if (error != null) _resetCatalogScroll();
        setState(() {
          _importing = false;
          _catalogRetry = error == null
              ? null
              : (work: work, text: text, error: error);
        });
      }
    }
  }

  void _showHit(_SourceHit hit) {
    _catalogFocus.unfocus();
    final work = hit.work;
    setState(() {
      _selected = hit;
      _linkError = null;
      _preview = work == null ? null : _loadPreview(work);
    });
  }

  Widget _previewBody(
    _SourceHit hit,
    WikisourceWork work,
    Future<List<String>?> preview,
  ) => FutureBuilder<List<String>?>(
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
                  work.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text('${_workDetails(work)} · 위키문헌'),
                const SizedBox(height: 8),
                Text(stanzas.join('\n\n')),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _open(
                      work.url,
                      title: work.title,
                      citation: work.citation,
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
            child: FilledButton(
              onPressed: () => Navigator.pop(
                context,
                SourceSearchChoice(
                  citation: work.citation,
                  text: stanzas.join('\n\n'),
                ),
              ),
              child: const Text('원문 가져오기'),
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
          onPressed: _importing ? null : () => _showHit(hit),
          child: const Text('다시 시도'),
        ),
      ],
      if (_mode != _SearchMode.author) ...[
        const SizedBox(height: 12),
        const Text('원문을 복사하거나 화면을 캡처한 뒤 가져오세요.'),
      ],
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _importing
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
          onPressed: _importing
              ? null
              : () => _collect(
                  () async => SourceSearchChoice(
                    citation: hit.citation,
                    text: await readSourceExcerpt(),
                  ),
                  failure: '붙여넣지 못했어요. 글을 다시 복사해 주세요.',
                ),
          child: const Text('복사한 글 가져오기'),
        ),
        OutlinedButton.icon(
          onPressed: _importing
              ? null
              : () => _collect(() async {
                  final photo = await _pickScreenshot();
                  return photo == null
                      ? null
                      : SourceSearchChoice(
                          citation: hit.citation,
                          photo: photo,
                        );
                }, failure: '캡처를 가져오지 못했어요. 다시 골라 주세요.'),
          icon: const Icon(CupertinoIcons.photo, size: 17),
          label: const Text('캡처 가져오기'),
        ),
        TextButton(
          onPressed: _importing
              ? null
              : () => Navigator.pop(
                  context,
                  SourceSearchChoice(citation: hit.citation),
                ),
          child: const Text('출처만 넣기'),
        ),
      ],
      if (_linkError case final error?)
        Semantics(liveRegion: true, child: Text(error)),
    ],
  );

  String _workDetails(WikisourceWork work) {
    final info = work.catalogInfo;
    if (info == null) return work.author;
    final unit = info.characters < 1000 ? 10 : 100;
    final rounded = (info.characters / unit).round() * unit;
    final count = rounded.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+$)'),
      (_) => ',',
    );
    return '${work.author} · ${info.genre.label} · 약 $count자';
  }

  void _resetCatalogScroll() {
    if (_catalogScroll.hasClients) _catalogScroll.jumpTo(0);
  }

  Widget _catalog() {
    final query = _compact(_catalogQuery.text);
    final genre = _catalogGenre;
    final works = WikisourceWork.reviewed.values.where((work) {
      return (genre == null || work.catalogInfo?.genre == genre) &&
          (_compact(work.title).contains(query) ||
              _compact(work.author).contains(query));
    }).toList();

    return CustomScrollView(
      key: const PageStorageKey('source-catalog-list'),
      controller: _catalogScroll,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PaperSearchField(
                  fieldKey: const ValueKey('source-catalog-query'),
                  enabled: !_importing,
                  controller: _catalogQuery,
                  focusNode: _catalogFocus,
                  hint: '작품 제목이나 작가',
                  maxLength: 160,
                  onChanged: (_) {
                    _resetCatalogScroll();
                    setState(() {});
                  },
                  onSubmitted: (_) => _catalogFocus.unfocus(),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final filter in [null, ...WikisourceGenre.values])
                      ChoiceChip(
                        label: Text(filter?.label ?? '전체'),
                        selected: genre == filter,
                        showCheckmark: false,
                        selectedColor: brandInk,
                        backgroundColor: Colors.transparent,
                        side: BorderSide(
                          color: genre == filter ? brandInk : line,
                        ),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 5),
                        labelStyle: TextStyle(
                          color: genre == filter ? Colors.white : brandInk,
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        onSelected: _importing
                            ? null
                            : (_) {
                                _catalogFocus.unfocus();
                                _resetCatalogScroll();
                                setState(() => _catalogGenre = filter);
                              },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (widget.onCatalogTranscription != null)
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                '작품을 누르면 바로 필사를 시작해요.',
                style: TextStyle(color: muted, fontSize: 13),
              ),
            ),
          ),
        if (_catalogRetry case final retry?)
          SliverToBoxAdapter(
            child: ListTile(
              title: Semantics(liveRegion: true, child: Text(retry.error)),
              trailing: TextButton(
                onPressed: () =>
                    _selectCatalogWork(retry.work, text: retry.text),
                child: const Text('다시 시도'),
              ),
            ),
          ),
        if (works.isEmpty)
          SliverToBoxAdapter(
            child: ListTile(
              title: Text(
                genre == null
                    ? '다른 제목이나 작가로 찾아보세요.'
                    : '다른 제목이나 작가로 찾거나 갈래를 바꿔 보세요.',
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            sliver: SliverList.builder(
              itemCount: works.length,
              itemBuilder: (_, index) {
                final work = works[index];
                return OriginalListItem(
                  key: ValueKey('wikisource-work-${work.pageId}'),
                  style: widget.style,
                  title: work.title,
                  preview: work.catalogInfo?.excerpt,
                  subtitle: _workDetails(work),
                  indexCard: true,
                  showDivider: index > 0,
                  onTap: _importing ? null : () => _selectCatalogWork(work),
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _completionDelay?.cancel();
    _query.removeListener(_queueCompletions);
    _focus.removeListener(_queueCompletions);
    _client.close();
    _query.dispose();
    _focus.dispose();
    _catalogQuery.dispose();
    _catalogFocus.dispose();
    _catalogScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searched = _searched;
    final selected = _selected;
    final preview = _preview;
    final hasHits = _results.any((entry) => entry.$2?.isNotEmpty ?? false);
    PaperNavigationScope.maybeOf(
      context,
    )?.name(context, selected == null ? '새 원문 찾기' : '원문 미리보기');
    void backToResults() => setState(() {
      _selected = null;
      _preview = null;
      _linkError = null;
    });
    return PopScope(
      canPop: !_importing && selected == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_importing && selected != null) backToResults();
      },
      child: PaperInternalBack(
        enabled: selected != null && !_importing,
        onBack: backToResults,
        child: PaperPanel(
          color: originalPanelColor,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: PaperHeaderRow(
                  children: [
                    PaperBackButton(
                      label: selected == null
                          ? null
                          : (_webSearch ? '검색 결과' : '작품 목록'),
                      enabled: !_importing,
                      onPressed: selected == null ? null : backToResults,
                    ),
                    Expanded(
                      child: PaperPanelTitle(
                        selected == null
                            ? '새 원문 찾기'
                            : preview != null
                            ? '원문 미리보기'
                            : '자료 가져오기',
                        fontSize: 22,
                      ),
                    ),
                    PaperWritingReturn(
                      enabled: !_importing,
                      force: selected != null,
                    ),
                  ],
                ),
              ),
              if (selected != null)
                Expanded(
                  child: preview == null
                      ? _details(selected)
                      : _previewBody(selected, selected.work!, preview),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final web in [false, true])
                          ChoiceChip(
                            label: Text(web ? '웹 검색' : '작품 둘러보기'),
                            selected: _webSearch == web,
                            shape: const RoundedRectangleBorder(),
                            side: BorderSide.none,
                            backgroundColor: Colors.transparent,
                            selectedColor: Colors.transparent,
                            showCheckmark: false,
                            labelStyle: TextStyle(
                              color: _webSearch == web ? brandInk : muted,
                              decoration: _webSearch == web
                                  ? TextDecoration.underline
                                  : null,
                            ),
                            onSelected: _importing
                                ? null
                                : (_) {
                                    _focus.unfocus();
                                    _catalogFocus.unfocus();
                                    setState(() => _webSearch = web);
                                    _queueCompletions();
                                  },
                          ),
                      ],
                    ),
                  ),
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
                          child: Text('웹 원문은 본문을 복사하거나 화면을 캡처해서 가져올 수 있어요.'),
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
                                  subtitle: switch (hit.work) {
                                    final work? => Text(
                                      '원문 미리보기 · ${_workDetails(work)}',
                                    ),
                                    null when _mode == _SearchMode.author =>
                                      null,
                                    null => const Text('웹 원문 · 복사 또는 캡처'),
                                  },
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
                            child: Text('네이버에서 글을 복사하거나 캡처한 뒤 가져오세요.'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ] else ...[
                  if (_importing && ModalRoute.isCurrentOf(context) == true)
                    const LinearProgressIndicator(semanticsLabel: '원문을 담고 있어요'),
                  Expanded(child: _catalog()),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
