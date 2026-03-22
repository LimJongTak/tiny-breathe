class Achievement {
  final String id;
  final String title;
  final String emoji;
  final String description;
  final bool unlocked;
  final DateTime? unlockedAt;

  const Achievement({
    required this.id,
    required this.title,
    required this.emoji,
    required this.description,
    this.unlocked = false,
    this.unlockedAt,
  });

  Achievement copyWithUnlocked() => Achievement(
        id: id,
        title: title,
        emoji: emoji,
        description: description,
        unlocked: true,
        unlockedAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'unlocked': unlocked,
        'unlockedAt': unlockedAt?.millisecondsSinceEpoch,
      };

  // ── Static catalog ─────────────────────────────────────────────────────────

  static const _catalog = [
    Achievement(
      id: 'first_plant',
      title: '첫 씨앗',
      emoji: '🌱',
      description: '처음으로 씨앗을 심었어요',
    ),
    Achievement(
      id: 'first_harvest',
      title: '첫 수확',
      emoji: '🌸',
      description: '처음으로 식물을 수확했어요',
    ),
    Achievement(
      id: 'collection_5',
      title: '식물 수집가',
      emoji: '🌿',
      description: '5종류의 식물을 수집했어요',
    ),
    Achievement(
      id: 'collection_10',
      title: '식물 연구가',
      emoji: '🔬',
      description: '10종류의 식물을 수집했어요',
    ),
    Achievement(
      id: 'collection_20',
      title: '식물 전문가',
      emoji: '🌺',
      description: '20종류의 식물을 수집했어요',
    ),
    Achievement(
      id: 'collection_all',
      title: '식물 박사',
      emoji: '🏅',
      description: '모든 40종의 식물을 수집했어요',
    ),
    Achievement(
      id: 'streak_3',
      title: '3일 연속',
      emoji: '📅',
      description: '3일 연속으로 출석했어요',
    ),
    Achievement(
      id: 'streak_7',
      title: '7일 연속',
      emoji: '🔥',
      description: '7일 연속으로 출석했어요',
    ),
    Achievement(
      id: 'level_5',
      title: '레벨 5 달성',
      emoji: '⭐',
      description: '레벨 5에 도달했어요',
    ),
    Achievement(
      id: 'level_10',
      title: '레벨 10 달성',
      emoji: '🌟',
      description: '레벨 10에 도달했어요',
    ),
    Achievement(
      id: 'level_15',
      title: '레벨 15 달성',
      emoji: '💫',
      description: '레벨 15에 도달했어요',
    ),
    Achievement(
      id: 'level_20',
      title: '꽃의 황제',
      emoji: '👑',
      description: '최고 레벨 20에 도달했어요!',
    ),
    Achievement(
      id: 'first_breed',
      title: '첫 교배',
      emoji: '🧬',
      description: '처음으로 식물을 교배했어요',
    ),
    Achievement(
      id: 'first_friend',
      title: '첫 친구',
      emoji: '👥',
      description: '처음으로 친구를 사귀었어요',
    ),
    Achievement(
      id: 'water_gift',
      title: '물 선물',
      emoji: '💧',
      description: '친구에게 물을 선물했어요',
    ),
    Achievement(
      id: 'weekly_top3',
      title: '주간 TOP 3',
      emoji: '🏆',
      description: '주간 랭킹 TOP 3에 들었어요',
    ),
  ];

  static List<Achievement> catalog() => List.unmodifiable(_catalog);

  /// Build list from saved unlock data (Set of unlocked ids + timestamps).
  static List<Achievement> fromSaved(Map<String, dynamic> saved) {
    return _catalog.map((a) {
      final data = saved[a.id] as Map<String, dynamic>?;
      if (data == null || data['unlocked'] != true) return a;
      final ts = data['unlockedAt'] as int?;
      return Achievement(
        id: a.id,
        title: a.title,
        emoji: a.emoji,
        description: a.description,
        unlocked: true,
        unlockedAt:
            ts != null ? DateTime.fromMillisecondsSinceEpoch(ts) : null,
      );
    }).toList();
  }

  static Map<String, dynamic> toSavedMap(List<Achievement> list) {
    return {
      for (final a in list)
        a.id: {'unlocked': a.unlocked, 'unlockedAt': a.unlockedAt?.millisecondsSinceEpoch}
    };
  }
}
