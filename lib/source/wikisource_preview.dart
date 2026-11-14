import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'source_intake.dart';

class WikisourcePoem {
  const WikisourcePoem(this.pageId, this.revisionId, this.title, this.author);

  // These editions carry a public domain notice on Korean Wikisource.
  // Page and revision IDs identify the specific transcription reviewed.
  static const reviewed = {
    1508: WikisourcePoem(1508, 430575, '진달래꽃', '김소월'),
    1515: WikisourcePoem(1515, 387685, '서시', '윤동주'),
    1866: WikisourcePoem(1866, 387769, '별 헤는 밤', '윤동주'),
    1879: WikisourcePoem(1879, 203679, '초혼', '김소월'),
  };

  final int pageId, revisionId;
  final String title, author;

  Uri get url =>
      Uri.https('ko.wikisource.org', '/w/index.php', {'oldid': '$revisionId'});

  String get citation => '$title · $author · 위키문헌 · $url';

  Future<List<String>> load(http.Client client) async {
    final response = await client
        .get(
          Uri.https('ko.wikisource.org', '/w/api.php', {
            'action': 'parse',
            'oldid': '$revisionId',
            'prop': 'text|revid|categories',
            'format': 'json',
            'formatversion': '2',
            'origin': '*',
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200 || response.bodyBytes.length > 500000) {
      throw const FormatException('Wikisource preview unavailable');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data
        case {
          'parse': {
            'pageid': final int page,
            'revid': final int revision,
            'text': final String markup,
            'categories': final List categories,
          },
        }
        when page == pageId &&
            revision == revisionId &&
            categories.any(
              (entry) => entry is Map && entry['category'] == 'PD-old-70',
            )) {
      final poems = html.parseFragment(markup).querySelectorAll('.poem');
      if (poems.isNotEmpty) {
        // The first column of this edition is the modern transcription.
        final blocks = pageId == 1508 ? poems.take(1) : poems;
        final text = blocks.map(_readPoem).join('\n');
        final stanzas = splitSourceParagraphs(text);
        if (stanzas.first == title) stanzas.removeAt(0);
        if (stanzas.isNotEmpty &&
            stanzas.first.isNotEmpty &&
            stanzas.join('\n\n').length <= sourceLengthLimit) {
          return stanzas;
        }
      }
    }
    throw const FormatException('Unexpected Wikisource edition');
  }
}

String _readPoem(Element poem) {
  final text = StringBuffer();
  void append(Node node) {
    if (node is Text) {
      text.write(node.data.replaceAll(RegExp(r'[\r\n\t]+'), ' '));
    } else if (node is Element) {
      if (node.localName == 'br') {
        text.writeln();
        return;
      }
      if (['script', 'style', 'sup'].contains(node.localName) ||
          node.attributes.containsKey('hidden') ||
          node.classes.contains('pagenum')) {
        return;
      }
      for (final child in node.nodes) {
        append(child);
      }
      if (node.localName == 'p') text.write('\n\n');
    }
  }

  append(poem);
  return text
      .toString()
      .split('\n')
      .map((line) => line.trim())
      .join('\n')
      .trim();
}
