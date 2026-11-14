import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'paper.dart';

class SourcePoem {
  const SourcePoem({
    required this.title,
    required this.poet,
    required this.text,
    required this.source,
  });

  factory SourcePoem.fromJson(Map<String, dynamic> json) => SourcePoem(
    title: json['title'] as String,
    poet: json['poet'] as String,
    text: json['text'] as String,
    source: json['source'] as String,
  );

  final String title, poet, text, source;

  String get citation => '$poet · $title · 위키문헌 $source';
}

Future<SourcePoem?> showPoemSearch(BuildContext context) =>
    showDialog<SourcePoem>(
      context: context,
      builder: (_) => const _PoemSearch(),
    );

class _PoemSearch extends StatefulWidget {
  const _PoemSearch();

  @override
  State<_PoemSearch> createState() => _PoemSearchState();
}

class _PoemSearchState extends State<_PoemSearch> {
  static final _punctuation = RegExp(r'[^가-힣ㄱ-ㅎㅏ-ㅣa-z0-9]');
  late Future<List<SourcePoem>> _catalog = _loadCatalog();
  String _query = '';
  SourcePoem? _selected;

  static Future<List<SourcePoem>> _loadCatalog() async {
    final raw = await rootBundle.loadString('assets/poems/korean.json');
    return (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>()
        .map(SourcePoem.fromJson)
        .toList();
  }

  static String _searchText(String value) =>
      value.toLowerCase().replaceAll(_punctuation, '');

  List<SourcePoem> _matches(List<SourcePoem> poems) {
    final words = _query
        .split(RegExp(r'\s+'))
        .map(_searchText)
        .where((word) => word.isNotEmpty);
    return [
      for (final poem in poems)
        if (words.every(
          _searchText('${poem.title} ${poem.poet} ${poem.text}').contains,
        ))
          poem,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Dialog(
      backgroundColor: paper,
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 480,
        height: 550,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 8, top: 6),
              child: Row(
                children: [
                  if (selected != null)
                    IconButton(
                      tooltip: '검색 결과로 돌아가기',
                      icon: const Icon(CupertinoIcons.chevron_back, size: 18),
                      onPressed: () => setState(() => _selected = null),
                    ),
                  Expanded(
                    child: Text(
                      selected?.title ?? '시 검색',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: '시 검색 닫기',
                    icon: const Icon(CupertinoIcons.xmark, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(child: selected == null ? _search() : _preview(selected)),
            if (selected != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, selected),
                    child: const Text('원문에 넣기'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _search() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextFormField(
          key: const ValueKey('poem-search-query'),
          initialValue: _query,
          onChanged: (text) => setState(() => _query = text),
          decoration: const InputDecoration(
            hintText: '시 제목, 시인, 기억나는 구절',
            prefixIcon: Icon(CupertinoIcons.search, size: 18),
          ),
        ),
      ),
      Expanded(
        child: FutureBuilder(
          future: _catalog,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: TextButton(
                  onPressed: () => setState(() => _catalog = _loadCatalog()),
                  child: const Text('시 목록을 읽지 못했어요 · 다시 시도'),
                ),
              );
            }
            final poems = snapshot.data;
            if (poems == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final matches = _matches(poems);
            return matches.isEmpty
                ? const Center(child: Text('시 모음에 일치하는 작품이 없어요.'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final poem = matches[index];
                      return ListTile(
                        title: Text(poem.title),
                        subtitle: Text(poem.poet),
                        onTap: () => setState(() => _selected = poem),
                      );
                    },
                  );
          },
        ),
      ),
    ],
  );

  Widget _preview(SourcePoem poem) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
    children: [
      Text(poem.poet, style: const TextStyle(color: muted)),
      const SizedBox(height: 12),
      Text(poem.text, style: const TextStyle(fontSize: 17, height: 1.7)),
      const SizedBox(height: 16),
      SelectableText(
        '위키문헌 · ${poem.source}',
        style: const TextStyle(fontSize: 12, color: muted),
      ),
    ],
  );
}
