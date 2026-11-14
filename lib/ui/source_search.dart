import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

enum _Collection {
  works('위키문헌', 'ko.wikisource.org'),
  quotes('위키인용집', 'ko.wikiquote.org');

  const _Collection(this.label, this.host);
  final String label, host;

  Future<List<_SourceHit>> search(http.Client client, String query) async {
    final response = await client
        .get(
          Uri.https(host, '/w/api.php', {
            'action': 'query',
            'list': 'search',
            'srsearch': query,
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
          if (title.trim().isNotEmpty && id > 0) _SourceHit(this, title, id),
    ];
  }
}

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

Future<String?> showSourceSearch(BuildContext context, Color paperColor) =>
    showDialog<String>(
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
  bool _loading = false;
  List<(_Collection, List<_SourceHit>?)> _results = const [];

  Future<void> _search() async {
    final value = _query.value;
    final query = value.text.trim();
    if (_loading ||
        query.isEmpty ||
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
    final results = await Future.wait(
      _Collection.values.map((collection) async {
        try {
          return (collection, await collection.search(_client, query));
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
                  Expanded(
                    child: Text(
                      '시·문장 검색',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: '검색 닫기',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(CupertinoIcons.xmark, size: 18),
                  ),
                ],
              ),
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
                      decoration: const InputDecoration(
                        labelText: '제목, 작가, 기억나는 구절',
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
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('검색어를 위키문헌과 위키인용집으로 보내 자료를 찾아요.'),
                    ),
                  if (_results.any((result) => result.$2?.isNotEmpty ?? false))
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('제목을 눌러 자료를 열고, 복사한 구절은 원문 등록에서 붙여넣으세요.'),
                    ),
                  if (_linkError case final error?)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Semantics(liveRegion: true, child: Text(error)),
                    ),
                  for (final (collection, hits) in _results) ...[
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
                    else if (hits.isEmpty)
                      const ListTile(title: Text('일치하는 자료가 없어요.'))
                    else
                      for (final hit in hits)
                        ListTile(
                          title: Text(hit.title),
                          onTap: () => _open(hit.url),
                          trailing: TextButton(
                            onPressed: () =>
                                Navigator.pop(context, hit.citation),
                            child: const Text('출처 넣기'),
                          ),
                        ),
                  ],
                  if (searched != null && !_loading)
                    TextButton.icon(
                      onPressed: () => _open(
                        Uri.https('search.naver.com', '/search.naver', {
                          'query': searched,
                        }),
                      ),
                      icon: const Icon(CupertinoIcons.arrow_up_right, size: 16),
                      label: const Text('네이버에서 더 찾기'),
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
