/// Stable names are persisted; the independent choices never share mutable state.
enum BookDetailKind {
  ribbon,
  bookplate,
  sourceSlip,
  pencil,
  ornament,
  binding,
  dateStamp,
  indexTab,
  recordDivider,
  pressedFlower,
}

class BookDetailChoice {
  const BookDetailChoice({
    this.enabled = true,
    this.variant = 0,
    this.tone = 0,
    this.placement = 0,
  });
  final bool enabled;
  final int variant, tone, placement;
  BookDetailChoice copy({
    bool? enabled,
    int? variant,
    int? tone,
    int? placement,
  }) => BookDetailChoice(
    enabled: enabled ?? this.enabled,
    variant: variant ?? this.variant,
    tone: tone ?? this.tone,
    placement: placement ?? this.placement,
  );
  void validate() {
    if (variant < 0 ||
        variant > 2 ||
        tone < 0 ||
        tone > 3 ||
        placement < 0 ||
        placement > 2) {
      throw const FormatException('책의 디테일 설정을 확인할 수 없습니다.');
    }
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'variant': variant,
    'tone': tone,
    if (placement != 0) 'placement': placement,
  };
  factory BookDetailChoice.fromJson(Map<String, dynamic> json) {
    if (json.keys.any(
          (key) => !['enabled', 'variant', 'tone', 'placement'].contains(key),
        ) ||
        (json.containsKey('enabled') && json['enabled'] is! bool) ||
        (json.containsKey('variant') && json['variant'] is! int) ||
        (json.containsKey('tone') && json['tone'] is! int) ||
        (json.containsKey('placement') && json['placement'] is! int)) {
      throw const FormatException('책의 디테일 설정을 확인할 수 없습니다.');
    }
    final value = BookDetailChoice(
      enabled: json['enabled'] as bool? ?? true,
      variant: json['variant'] as int? ?? 0,
      tone: json['tone'] as int? ?? 0,
      placement: json['placement'] as int? ?? 0,
    );
    value.validate();
    return value;
  }
}

class BookDetailsStyle {
  const BookDetailsStyle({
    this.ribbon = const BookDetailChoice(),
    this.bookplate = const BookDetailChoice(),
    this.sourceSlip = const BookDetailChoice(),
    this.pencil = const BookDetailChoice(),
    this.ornament = const BookDetailChoice(),
    this.binding = const BookDetailChoice(),
    this.dateStamp = const BookDetailChoice(),
    this.indexTab = const BookDetailChoice(),
    this.recordDivider = const BookDetailChoice(),
    this.pressedFlower = const BookDetailChoice(),
  });
  final BookDetailChoice ribbon,
      bookplate,
      sourceSlip,
      pencil,
      ornament,
      binding,
      dateStamp,
      indexTab,
      recordDivider,
      pressedFlower;
  BookDetailChoice choice(BookDetailKind kind) => switch (kind) {
    BookDetailKind.ribbon => ribbon,
    BookDetailKind.bookplate => bookplate,
    BookDetailKind.sourceSlip => sourceSlip,
    BookDetailKind.pencil => pencil,
    BookDetailKind.ornament => ornament,
    BookDetailKind.binding => binding,
    BookDetailKind.dateStamp => dateStamp,
    BookDetailKind.indexTab => indexTab,
    BookDetailKind.recordDivider => recordDivider,
    BookDetailKind.pressedFlower => pressedFlower,
  };
  BookDetailsStyle withChoice(
    BookDetailKind kind,
    BookDetailChoice value,
  ) => BookDetailsStyle(
    ribbon: kind == BookDetailKind.ribbon ? value : ribbon,
    bookplate: kind == BookDetailKind.bookplate ? value : bookplate,
    sourceSlip: kind == BookDetailKind.sourceSlip ? value : sourceSlip,
    pencil: kind == BookDetailKind.pencil ? value : pencil,
    ornament: kind == BookDetailKind.ornament ? value : ornament,
    binding: kind == BookDetailKind.binding ? value : binding,
    dateStamp: kind == BookDetailKind.dateStamp ? value : dateStamp,
    indexTab: kind == BookDetailKind.indexTab ? value : indexTab,
    recordDivider: kind == BookDetailKind.recordDivider ? value : recordDivider,
    pressedFlower: kind == BookDetailKind.pressedFlower ? value : pressedFlower,
  );
  void validate() {
    for (final kind in BookDetailKind.values) {
      choice(kind).validate();
    }
  }

  Map<String, dynamic> toJson() => {
    for (final kind in BookDetailKind.values) kind.name: choice(kind).toJson(),
  };
  factory BookDetailsStyle.fromJson(Map<String, dynamic> json) {
    if (json.keys.any(
      (key) => !BookDetailKind.values.any((kind) => kind.name == key),
    )) {
      throw const FormatException('알 수 없는 책의 디테일입니다.');
    }
    var value = const BookDetailsStyle();
    for (final kind in BookDetailKind.values) {
      if (json.containsKey(kind.name)) {
        value = value.withChoice(
          kind,
          BookDetailChoice.fromJson(json[kind.name] as Map<String, dynamic>),
        );
      }
    }
    return value;
  }
}
