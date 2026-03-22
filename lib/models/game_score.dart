class GameScores {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final int weekKey;
  final Map<String, int> scores; // 'tap' | 'drop' | 'weed' | 'catch' | 'dodge' → score

  const GameScores({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    required this.weekKey,
    this.scores = const {},
  });

  int get total => scores.values.fold(0, (a, b) => a + b);

  static const gameNames = {
    'tap':   '땅파기',
    'drop':  '물방울 잡기',
    'weed':  '잡초뽑기',
    'catch': '벌레 퇴치',
    'dodge': '벌 피하기',
  };

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'weekKey': weekKey,
        'scores': scores,
        'total': total,
      };

  factory GameScores.fromJson(Map<String, dynamic> j) => GameScores(
        uid: j['uid'] as String? ?? '',
        displayName: j['displayName'] as String? ?? '사용자',
        photoUrl: j['photoUrl'] as String?,
        weekKey: (j['weekKey'] as num?)?.toInt() ?? 0,
        scores: (j['scores'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, (v as num).toInt())) ??
            const {},
      );
}
