import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'source_intake.dart';

part 'wikisource_catalog.dart';
part 'wikisource_catalog_info.dart';

enum WikisourceGenre {
  poem('시'),
  fiction('소설'),
  essay('수필'),
  other('기타');

  const WikisourceGenre(this.label);

  final String label;
}

class WikisourceWorkInfo {
  const WikisourceWorkInfo(this.genre, this.characters, this.excerpt);

  final WikisourceGenre genre;
  final int characters;
  final String excerpt;
}

class WikisourceWork {
  const WikisourceWork(
    this.pageId,
    this.revisionId,
    this.title,
    this.author, {
    this.editionIndex,
    this.prose = false,
    this.licenseCategory = 'PD-old-70',
    this.licensedCollection,
  });

  // Page and revision IDs identify the specific transcription checked.
  static const reviewed = {
    1508: WikisourceWork(1508, 430575, '진달래꽃', '김소월', editionIndex: 0),
    1515: WikisourceWork(1515, 387685, '서시', '윤동주'),
    1866: WikisourceWork(1866, 387769, '별 헤는 밤', '윤동주'),
    1879: WikisourceWork(1879, 203679, '초혼', '김소월'),
    1513: WikisourceWork(
      1513,
      430576,
      "님의 침묵",
      "한용운",
      editionIndex: 1,
      licensedCollection: _hanYongunCollection,
    ),
    1923: WikisourceWork(1923, 465103, "동백꽃", "김유정", prose: true),
    2370: WikisourceWork(
      2370,
      468924,
      "운수 좋은 날",
      "현진건",
      prose: true,
      licenseCategory: 'PD-old-50',
    ),
    1517: WikisourceWork(
      1517,
      202488,
      "청포도",
      "이육사",
      licenseCategory: 'PD-old-50',
    ),
    2921: WikisourceWork(2921, 389127, "모란이 피기까지는", "김영랑"),
    2584: WikisourceWork(2584, 426852, "메밀꽃 필 무렵", "이효석", prose: true),
    1861: WikisourceWork(1861, 387749, '자화상', '윤동주'),
    2718: WikisourceWork(2718, 387750, '소년', '윤동주'),
    2719: WikisourceWork(2719, 387751, '눈 오는 지도', '윤동주'),
    19215: WikisourceWork(19215, 387752, '돌아와 보는 밤', '윤동주'),
    19216: WikisourceWork(19216, 387756, '새로운 길', '윤동주'),
    19217: WikisourceWork(19217, 387757, '간판 없는 거리', '윤동주'),
    19218: WikisourceWork(19218, 387758, '태초의 아침', '윤동주'),
    19219: WikisourceWork(19219, 387759, '또 태초의 아침', '윤동주'),
    19220: WikisourceWork(19220, 387760, '새벽이 올 때까지', '윤동주'),
    19221: WikisourceWork(19221, 387761, '무서운 시간', '윤동주'),
    1862: WikisourceWork(1862, 387762, '십자가', '윤동주'),
    1863: WikisourceWork(1863, 387763, '바람이 불어', '윤동주'),
    19222: WikisourceWork(19222, 387764, '슬픈 족속', '윤동주'),
    1864: WikisourceWork(1864, 387767, '또 다른 고향', '윤동주'),
    10238: WikisourceWork(10238, 387768, '길', '윤동주'),
    1867: WikisourceWork(1867, 387804, '참회록', '윤동주'),
    1522: WikisourceWork(1522, 430577, '산유화', '김소월', editionIndex: 0),
    1521: WikisourceWork(1521, 203761, '엄마야 누나야', '김소월'),
    1878: WikisourceWork(1878, 203584, '못 잊어', '김소월'),
    34903: WikisourceWork(34903, 430975, '접동새', '김소월', editionIndex: 0),
    1970: WikisourceWork(1970, 203684, '가는 길', '김소월'),
    1717: WikisourceWork(1717, 203585, '예전엔 미처 몰랐어요', '김소월'),
    1519: WikisourceWork(1519, 204518, '금잔디', '김소월'),
    1523: WikisourceWork(1523, 203685, '왕십리', '김소월'),
    1877: WikisourceWork(1877, 430584, '먼 후일', '김소월', editionIndex: 0),
    3609: WikisourceWork(3609, 203568, '풀 따기', '김소월'),
    1937: WikisourceWork(1937, 430586, '봄 밤', '김소월', editionIndex: 0),
    3619: WikisourceWork(3619, 203690, '삭주구성', '김소월'),
    3548: WikisourceWork(3548, 430599, '달맞이', '김소월', editionIndex: 0),
    3044: WikisourceWork(
      3044,
      430592,
      '빼앗긴 들에도 봄은 오는가',
      '이상화',
      editionIndex: 1,
    ),
    3045: WikisourceWork(3045, 381039, '나의 침실로', '이상화'),
    ..._additionalWorks,
  };

  final int pageId, revisionId;
  final String title, author;
  final bool prose;
  final String licenseCategory;
  final WikisourceWork? licensedCollection;

  WikisourceWorkInfo? get catalogInfo => _editionInfo[revisionId];

  // Parallel transcriptions are alternatives. Unset means the blocks follow
  // each other, for example when the poem spans several scanned pages.
  final int? editionIndex;

  Uri get url =>
      Uri.https('ko.wikisource.org', '/w/index.php', {'oldid': '$revisionId'});

  String get citation => '$title · $author · 위키문헌 · $url';

  Future<Map> _parse(http.Client client, {required String properties}) async {
    final response = await client
        .get(
          Uri.https('ko.wikisource.org', '/w/api.php', {
            'action': 'parse',
            'oldid': '$revisionId',
            'prop': properties,
            'format': 'json',
            'formatversion': '2',
            'origin': '*',
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200 && response.bodyBytes.length <= 500000) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data case {
        'parse': final Map page,
      } when page['pageid'] == pageId && page['revid'] == revisionId) {
        return page;
      }
    }
    throw const FormatException('Unexpected Wikisource edition');
  }

  bool _hasLicense(Map page) {
    final categories = page['categories'];
    return categories is List &&
        categories.any(
          (entry) => entry is Map && entry['category'] == licenseCategory,
        );
  }

  Future<List<String>> load(http.Client client) async {
    final page = await _parse(client, properties: 'text|revid|categories');
    final collection = licensedCollection;
    final licensed = collection == null
        ? _hasLicense(page)
        : page['title'] is String &&
              (page['title'] as String).startsWith('${collection.title}/') &&
              collection._hasLicense(
                await collection._parse(client, properties: 'revid|categories'),
              );
    if (!licensed || page['text'] is! String) {
      throw const FormatException('Wikisource source unavailable');
    }

    final document = html.parseFragment(page['text'] as String);
    final blocks = document.querySelectorAll(
      prose ? '.mw-parser-output > p, .prp-pages-output > p' : '.poem',
    );
    final index = editionIndex;
    if (blocks.isEmpty || (index != null && index >= blocks.length)) {
      throw const FormatException('Unexpected Wikisource transcription');
    }
    final selected = index == null ? blocks : [blocks[index]];
    final text = selected
        .map((block) => _readBlock(block, title))
        .join(prose ? '\n\n' : '\n');
    final paragraphs = splitSourceParagraphs(text);
    if (paragraphs.first.isEmpty ||
        paragraphs.join('\n\n').length > sourceLengthLimit) {
      throw const FormatException('Invalid Wikisource transcription');
    }
    return paragraphs;
  }
}

String _readBlock(Element block, String title) {
  final text = StringBuffer();
  void append(Node node) {
    if (node is Text) {
      text.write(node.data.replaceAll(RegExp(r'[\r\n\t]+'), ' '));
    } else if (node is Element) {
      if (node.localName == 'br') {
        text.writeln();
        return;
      }
      if (node.localName == 'big' &&
          _withoutPunctuation(node.text) == _withoutPunctuation(title)) {
        return;
      }
      if (['script', 'style', 'sup'].contains(node.localName) ||
          node.attributes.containsKey('hidden') ||
          node.classes.contains('pagenum') ||
          node.classes.contains('ws-noexport')) {
        return;
      }
      for (final child in node.nodes) {
        append(child);
      }
      if (node.localName == 'p') text.write('\n\n');
    }
  }

  append(block);
  return text
      .toString()
      .split('\n')
      .map((line) => line.trim())
      .join('\n')
      .trim();
}

String _withoutPunctuation(String text) =>
    text.replaceAll(RegExp(r'[\s,?.!]+'), '');
