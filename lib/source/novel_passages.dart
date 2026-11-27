import 'dart:math' as math;

part 'translated_novel_passages.dart';

class NovelPassage {
  const NovelPassage(this.label, this.text);

  final String label, text;
}

class TranslatedNovel {
  const TranslatedNovel(this.id, this.title, this.author, this.passages);

  final int id;
  final String title, author;
  final List<NovelPassage> passages;

  Uri get url => Uri.https('lib.txid.uk', '/book/$id');

  String get citation =>
      '$title · $author · Dao Consulting (lib.txid.uk) 한국어판 · 발췌 · $url · '
      'CC BY 4.0 https://creativecommons.org/licenses/by/4.0/';
}

const _readingPoints = <int, List<(String, String)>>{
  1884: [('칠성문 밖 빈민굴', '이 세상의 모든 비극과 활극'), ('왕 서방과 복녀의 남편', '왕 서방이 눈만 멀찐멀찐')],
  1889: [('삼룡이의 소개', '삼룡(三龍)이라는'), ('불길 속으로', '주인을업어다가')],
  2036: [
    ('삼 년 일곱 달', '돈 한 푼 안 받고 일하기를'),
    ('논에서 벌어진 일', '배가 좀 아파서유'),
    ('장인님과 실랑이', '헷손질을 하며 솔개미에'),
  ],
  2369: [
    ('사감이 싫어하는 편지', '싫어하고 미워하는 것은 소위'),
    ('기숙사의 면회', '기숙생을 남자가 면회하러'),
    ('한밤중의 웃음소리', '괴상한 소리는 땍대굴'),
  ],
  4474: [
    ('잠에서 깨는 순이', '열 다섯 살밖에 안 된 순이'),
    ('하루가 저물다', '그럭저럭 하루 해는 저물어'),
    ('부뚜막 위의 성냥', '부뚜막에 얹힌 성냥'),
  ],
  4486: [('밤사이 그친 비', '어제 일로 심신이 피곤'), ('아내를 끌어안다', '아내의 허리를 잡아 내 가슴에')],
  17174: [
    ('백성수의 이야기', '이야기의 주인공 되는 백성수'),
    ('예배당 문이 열리다', '덜컥덜컥 하는 소리'),
    ('화염 속에서 들린 음악', '화염! 화염!'),
  ],
  17185: [
    ('우리 아저씨 말이지요', '우리 아저씨 말이지요?'),
    ('아주머니가 돌보던 날들', '아주머니는 불철주'),
    ('경제와 사회에 관한 글', '아저씨가 여기다가 경제'),
  ],
  1923: [
    ('또 닭싸움이 벌어졌다', '오늘도 또 우리 수탉이'),
    ('점순이가 내민 감자', '봄 감자가 맛있단다'),
    ('고추장을 먹인 수탉', '고추장을 먹이면'),
    ('동백꽃 사이로', '노란 동백꽃이 소보록하니'),
    ('꽃 속으로', '노란 동백꽃 속으로'),
  ],
  2370: [
    ('비가 내리는 아침', '새침하게 흐린 품'),
    ('김 첨지의 운수 좋은 날', '김 첨지에게는 오래간만'),
    ('설렁탕을 사줄 수도 있다', '인제 설렁탕을 사줄 수도 있다'),
    ('선술집에서 만난 치삼', '길가 선술집에서'),
    ('설렁탕을 들고 집으로', '취중에도 설렁탕을'),
    ('괴상하게도 오늘은', '설렁탕을 사다놓았는데'),
  ],
  2584: [
    ('봉평의 여름장', '여름장이란 애시당초'),
    ('나귀와 함께한 세월', '반평생을 같이 지내온 짐승'),
    ('달빛 아래 메밀밭', '짐승 같은 달의 숨소리'),
    ('다음 장날의 기억', '다음 장도막에는 벌써'),
    ('동이의 왼손', '동이의 채찍은 왼손'),
  ],
};

final _sentenceBoundary = RegExp(r'''[.!?。！？…]+[”’"'」』)]*(?:\s+|$)''');

/// Extract complete paragraphs or sentences in the original order.
List<NovelPassage> novelPassages(int pageId, List<String> paragraphs) {
  const limit = 6;
  final blocks = <String>[
    for (final paragraph in paragraphs) ..._shortBlocks(paragraph),
  ];
  final passages = <int, NovelPassage>{};
  final used = <String>{};
  void add(int index, {String label = ''}) {
    if (index < 0 || index >= blocks.length || passages.containsKey(index)) {
      return;
    }
    final text = blocks[index];
    if (used.add(text)) passages[index] = NovelPassage(label, text);
  }

  for (final (label, anchor)
      in _readingPoints[pageId] ?? const <(String, String)>[]) {
    final index = blocks.indexWhere((block) => block.contains(anchor));
    add(index, label: label);
  }
  final seen = {...used};
  final remaining = [
    for (var index = 0; index < blocks.length; index++)
      if (blocks[index].length >= 48 && seen.add(blocks[index])) index,
  ];
  final count = math.min(limit - passages.length, remaining.length);
  for (var i = 0; i < count; i++) {
    final rank = ((i + .5) * remaining.length / count).floor();
    add(remaining[rank]);
  }
  // Brief works can consist entirely of short lines of dialogue.
  for (var i = 0; i < blocks.length && passages.length < 2; i++) {
    add(i);
  }
  final indices = passages.keys.toList()..sort();
  return [for (final index in indices) passages[index]!];
}

Iterable<String> _shortBlocks(String paragraph) sync* {
  const preferredLength = 380;
  var rest = paragraph.trim();
  while (rest.length > preferredLength) {
    final sentenceEnds = _sentenceBoundary
        .allMatches(rest)
        .map((match) => match.end)
        .takeWhile((end) => end <= preferredLength)
        .toList();
    final split = sentenceEnds.isNotEmpty && sentenceEnds.last >= 100
        ? sentenceEnds.last
        : rest.lastIndexOf(RegExp(r'\s'), preferredLength);
    if (split <= 0) break;
    yield rest.substring(0, split).trim();
    rest = rest.substring(split).trimLeft();
  }
  if (rest.isNotEmpty) yield rest;
}
