/// Personal room choices. These are independent of manuscripts and editor state.
class CafeHome {
  const CafeHome({
    this.mood = 0,
    this.topic = 0,
    this.seat,
    this.chair,
    this.pinned,
  });
  final int mood, topic;
  final String? seat, chair, pinned;
  CafeHome copy({
    int? mood,
    int? topic,
    String? seat,
    String? chair,
    String? pinned,
    bool clearChair = false,
    bool clearPinned = false,
  }) => CafeHome(
    mood: mood ?? this.mood,
    topic: topic ?? this.topic,
    seat: seat ?? this.seat,
    chair: clearChair ? null : chair ?? this.chair,
    pinned: clearPinned ? null : pinned ?? this.pinned,
  );
  Map<String, dynamic> toJson() => {
    'mood': mood,
    'topic': topic,
    'seat': seat,
    'chair': chair,
    'pinned': pinned,
  };
  factory CafeHome.read(dynamic value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid cafe home');
    }
    for (final key in ['mood', 'topic']) {
      if (value[key] is! int || value[key] < 0 || value[key] > 2) {
        throw const FormatException('Invalid cafe atmosphere');
      }
    }
    final seat = value['seat'],
        chair = value['chair'],
        pinned = value['pinned'];
    if (seat != null &&
        !const {
          'window',
          'windowMiddle',
          'windowRear',
          'shared',
          'quiet',
          'garden',
        }.contains(seat)) {
      throw const FormatException('Invalid favorite seat');
    }
    if (chair != null &&
        (chair is! String ||
            chair.length > 100 ||
            !RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(chair))) {
      throw const FormatException('Invalid favorite chair');
    }
    if (pinned != null &&
        (pinned is! String || pinned.trim().isEmpty || pinned.length > 320)) {
      throw const FormatException('Invalid personal sentence');
    }
    return CafeHome(
      mood: value['mood'],
      topic: value['topic'],
      seat: seat,
      chair: chair,
      pinned: pinned,
    );
  }
}

class CafeSentence {
  const CafeSentence(this.id, this.topic, this.text);
  final String id, topic, text;
  String get citation => '쓰는 인간 · $topic';
}

/// Original editorial copy for this app, not attributed quotations or a live feed.
class CafeEditorial {
  static const topics = ['지친 날', '다시 시작하는 날', '그냥 좋은 날'];
  static const sentences = [
    CafeSentence('rest-0', '지친 날', '오늘 다 하지 못한 일은\n오늘의 나를\n다 말해 주지 않는다.'),
    CafeSentence('rest-1', '지친 날', '잠깐 멈춘 자리에도\n내가 지나온 시간이\n조용히 쌓여 있다.'),
    CafeSentence('begin-0', '다시 시작하는 날', '다음 문장은\n지금의 내가 골라도\n좋다.'),
    CafeSentence('begin-1', '다시 시작하는 날', '오래 덮어 둔 책도\n펼친 자리에서\n다시 시작된다.'),
    CafeSentence('ordinary-0', '그냥 좋은 날', '빛이 머문 자리에서\n평범한 하루의 모서리가\n반짝였다.'),
    CafeSentence('ordinary-1', '그냥 좋은 날', '좋아하는 문장 곁에\n오늘의 나를 잠시\n놓아두었다.'),
  ];
  static int day(DateTime date) => DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(2026)).inDays;
  static CafeSentence today(DateTime date, int topic) =>
      sentences[topic * 2 + day(date) % 2];
  static const letters = [
    '오늘의 쪽지\n\n아무것도 끝내지 않아도 이 자리에 앉아 있어도 좋아요.\n창밖을 잠깐 바라보다가 마음에 남는 한 줄이 있다면 그때 노트를 펼쳐요.',
    '다시 펼친 자리\n\n오래 자리를 비워도 쓰던 쪽은 기다릴 수 있어요.\n지난 문장부터 천천히 읽어 보세요. 이어질 말은 서두르지 않아도 괜찮아요.',
    '평범한 날의 문장\n\n큰일이 없던 하루에도 적어 둘 장면은 있어요.\n차의 온도, 창가의 빛, 잠깐 웃었던 순간처럼 작은 것을 한 줄 남겨 보세요.',
    '남겨 둔 여백\n\n종이의 빈 곳에도 머물 수 있어요.\n내일의 내가 쉬어 갈 자리로 남겨 두어도 좋아요.',
  ];
  static String letter(DateTime date) =>
      letters[(day(date) ~/ 7) % letters.length];
}
