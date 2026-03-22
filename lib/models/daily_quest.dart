enum QuestType { waterPlants, visitFriend, harvestPlant, playMiniGame }

class DailyQuest {
  final String id;
  final String title;
  final String emoji;
  final String description;
  final QuestType type;
  final int target;
  final int progress;
  final bool claimed;
  final int rewardCoins;
  final int rewardSeeds;

  const DailyQuest({
    required this.id,
    required this.title,
    required this.emoji,
    required this.description,
    required this.type,
    required this.target,
    this.progress = 0,
    this.claimed = false,
    this.rewardCoins = 0,
    this.rewardSeeds = 0,
  });

  bool get completed => progress >= target;
  double get fraction => (progress / target).clamp(0.0, 1.0);

  DailyQuest copyWith({int? progress, bool? claimed}) => DailyQuest(
        id: id,
        title: title,
        emoji: emoji,
        description: description,
        type: type,
        target: target,
        rewardCoins: rewardCoins,
        rewardSeeds: rewardSeeds,
        progress: progress ?? this.progress,
        claimed: claimed ?? this.claimed,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'progress': progress,
        'claimed': claimed,
      };

  // ── Static definitions ─────────────────────────────────────────────────────

  static const _defs = [
    DailyQuest(
      id: 'water_3',
      title: '물 주기',
      emoji: '💧',
      description: '식물에 물을 3번 주세요',
      type: QuestType.waterPlants,
      target: 3,
      rewardCoins: 30,
    ),
    DailyQuest(
      id: 'visit_friend',
      title: '친구 방문',
      emoji: '👥',
      description: '친구 정원을 방문하세요',
      type: QuestType.visitFriend,
      target: 1,
      rewardCoins: 20,
      rewardSeeds: 1,
    ),
    DailyQuest(
      id: 'harvest',
      title: '수확하기',
      emoji: '🌸',
      description: '만개한 식물을 수확하세요',
      type: QuestType.harvestPlant,
      target: 1,
      rewardCoins: 50,
    ),
    DailyQuest(
      id: 'play_game',
      title: '미니게임',
      emoji: '🎮',
      description: '미니게임을 1판 플레이하세요',
      type: QuestType.playMiniGame,
      target: 1,
      rewardCoins: 30,
      rewardSeeds: 1,
    ),
  ];

  static List<DailyQuest> defaults() => List.unmodifiable(_defs);

  static List<DailyQuest> fromSaved(List<dynamic> saved) {
    return _defs.map((def) {
      try {
        final s = saved.firstWhere((m) => (m as Map)['id'] == def.id,
            orElse: () => null);
        if (s == null) return def;
        final m = s as Map<String, dynamic>;
        return def.copyWith(
          progress: (m['progress'] as num?)?.toInt() ?? 0,
          claimed: m['claimed'] as bool? ?? false,
        );
      } catch (_) {
        return def;
      }
    }).toList();
  }
}
