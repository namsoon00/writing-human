/// Local room state. It is deliberately separate from books and saved writing.
enum CafeSeat {
  window('창가 자리', '창밖을 보며 천천히 써요.'),
  shared('큰 책상', '넓은 책상에 책을 펼쳐요.'),
  quiet('안쪽 자리', '책장 곁에서 차분히 써요.'),
  windowMiddle('가운데 창가', '정원 가까이 책을 펼쳐요.'),
  windowRear('안쪽 창가', '조용한 창가에서 써요.'),
  garden('뜰의 책상', '나무와 연못 곁에서 천천히 써요.');

  const CafeSeat(this.label, this.description);
  final String label, description;
}

/// Real objects in the room, shared by ray picking and accessible exploration.
enum CafeTarget {
  window('창가 자리', '앉기'),
  shared('큰 책상', '앉기'),
  quiet('안쪽 자리', '앉기'),
  bookshelf('나의 책장', '펼칠 책 고르기'),
  recommendations('추천 서가', '문장 살펴보기'),
  stationery('펜과 노트', '쓰기 도구 살펴보기'),
  exit('출입문', '카페 나가기'),
  windowMiddle('가운데 창가', '앉기'),
  windowRear('안쪽 창가', '앉기'),
  courtyard('고요한 뜰', '뜰로 걷기'),
  pond('금붕어 연못', '가까이 바라보기'),
  bench('뜰의 벤치', '잠시 쉬기'),
  bell('작은 종', '한 번 울리기'),
  tea('차 한 잔', '차 따르기'),
  gardenDesk('뜰의 책상', '앉기'),
  cafeReturn('카페로', '카페로 돌아가기');

  const CafeTarget(this.label, this.action);
  final String label, action;
  CafeSeat? get seat => switch (this) {
    window => CafeSeat.window,
    shared => CafeSeat.shared,
    quiet => CafeSeat.quiet,
    windowMiddle => CafeSeat.windowMiddle,
    windowRear => CafeSeat.windowRear,
    gardenDesk => CafeSeat.garden,
    _ => null,
  };
  bool get inCourtyard =>
      const {pond, bench, bell, tea, gardenDesk, cafeReturn}.contains(this);
  static CafeTarget forSeat(CafeSeat seat) => switch (seat) {
    CafeSeat.window => window,
    CafeSeat.shared => shared,
    CafeSeat.quiet => quiet,
    CafeSeat.windowMiddle => windowMiddle,
    CafeSeat.windowRear => windowRear,
    CafeSeat.garden => gardenDesk,
  };
}
