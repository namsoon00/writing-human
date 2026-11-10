import 'package:flutter/material.dart';
import '../data/book_detail_style.dart';
import 'paper_palette.dart';

/// Shared design vocabulary, with a separate palette and silhouettes per item.
class BookDetailDesign {
  const BookDetailDesign(
    this.title,
    this.description,
    this.variants,
    this.tones,
    this.colors,
  );
  final String title, description;
  final List<String> variants, tones;
  final List<Color> colors;
  static BookDetailDesign of(BookDetailKind kind) => switch (kind) {
    BookDetailKind.ribbon => const BookDetailDesign(
      '천 책갈피',
      '지금 이어 쓰는 위치에 남기는 천 한 조각',
      ['사선 끝', '제비꼬리', '둥근 끝'],
      ['포도', '올리브', '브라운', '회청'],
      [burgundy, green, brandInk, Color(0xff4c607a)],
    ),
    BookDetailKind.bookplate => const BookDetailDesign(
      '장서표',
      '책의 주인 이름을 담는 작은 인쇄물',
      ['이중 테두리', '모서리 장식', '잉크 표식'],
      ['브라운', '포도', '올리브', '회청'],
      [brandInk, burgundy, green, Color(0xff4c607a)],
    ),
    BookDetailKind.sourceSlip => const BookDetailDesign(
      '원문 쪽지',
      '책 사이에 끼워두는 원문 메모',
      ['가장자리 선', '종이 클립', '접힌 귀퉁이'],
      ['미색', '백색', '살구', '회백'],
      [
        Color(0xfffcf8ed),
        Color(0xfffdfcf7),
        Color(0xfff6e6d9),
        Color(0xffedece6),
      ],
    ),
    BookDetailKind.pencil => const BookDetailDesign(
      '연필 흔적',
      '마음이 머문 구절에 남기는 가는 선',
      ['가는 밑줄', '겹밑줄', '점선'],
      ['연필', '브라운', '회청', '올리브'],
      [Color(0xff82796d), brandInk, Color(0xff4c607a), green],
    ),
    BookDetailKind.ornament => const BookDetailDesign(
      '판면 장식',
      '쪽수 양옆에 숨을 두는 작은 문양',
      ['선과 점', '마름모', '작은 잎'],
      ['브라운', '포도', '올리브', '회청'],
      [brandInk, burgundy, green, Color(0xff4c607a)],
    ),
    BookDetailKind.binding => const BookDetailDesign(
      '제본 흔적',
      '책 안쪽을 따라 드러나는 실과 천의 결',
      ['직조 띠', '실 제본', '천 책등'],
      ['브라운', '포도', '올리브', '회청'],
      [brandInk, burgundy, green, Color(0xff4c607a)],
    ),
    BookDetailKind.dateStamp => const BookDetailDesign(
      '날짜인',
      '기록을 시작한 날을 남기는 작은 인장',
      ['사각 인장', '타원 인장', '날짜 활자'],
      ['브라운', '포도', '올리브', '회청'],
      [brandInk, burgundy, green, Color(0xff4c607a)],
    ),
    BookDetailKind.indexTab => const BookDetailDesign(
      '색인 탭',
      '보관함에서 책을 바로 여는 작은 표식',
      ['종이 탭', '천 탭', '반달 탭'],
      ['올리브', '포도', '브라운', '회청'],
      [green, burgundy, brandInk, Color(0xff4c607a)],
    ),
    BookDetailKind.recordDivider => const BookDetailDesign(
      '문장 구분표',
      '필사 기록과 기록 사이에 두는 작은 쉼',
      ['세 점', '짧은 선', '작은 꽃'],
      ['브라운', '포도', '올리브', '회청'],
      [brandInk, burgundy, green, Color(0xff4c607a)],
    ),
    BookDetailKind.pressedFlower => const BookDetailDesign(
      '압화 장식',
      '표지와 장서표 모서리에 남기는 식물 한 조각',
      ['작은 잎', '들꽃', '고사리'],
      ['올리브', '포도', '브라운', '회청'],
      [green, burgundy, brandInk, Color(0xff4c607a)],
    ),
  };
  static Color color(BookDetailKind kind, BookDetailChoice choice) =>
      of(kind).colors[choice.tone];
}
