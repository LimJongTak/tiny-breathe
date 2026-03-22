import 'package:flutter/painting.dart';

/// Configuration for one player level.
class LevelConfig {
  final int level;
  final int xpRequired; // cumulative total XP to reach this level
  final int plotCount;  // how many garden plots are available

  const LevelConfig({
    required this.level,
    required this.xpRequired,
    required this.plotCount,
  });
}

/// Information about a plantable seed species.
class SeedInfo {
  final String name;
  final double hue, saturation, lightness;
  final String emoji;
  final int unlockLevel;

  const SeedInfo({
    required this.name,
    required this.hue,
    required this.saturation,
    required this.lightness,
    required this.emoji,
    required this.unlockLevel,
  });

  HSLColor get hslColor =>
      HSLColor.fromAHSL(1.0, hue, saturation, lightness);
}

/// One-per-season limited seed event.
abstract final class SeasonalSeeds {
  static SeedInfo current() {
    final m = DateTime.now().month;
    if (m >= 3 && m <= 5) {
      return const SeedInfo(name: '봄 벚꽃',      hue: 350, saturation: 0.70, lightness: 0.80, emoji: '🌸', unlockLevel: 1);
    } else if (m >= 6 && m <= 8) {
      return const SeedInfo(name: '여름 수국',    hue: 250, saturation: 0.65, lightness: 0.72, emoji: '💜', unlockLevel: 1);
    } else if (m >= 9 && m <= 11) {
      return const SeedInfo(name: '가을 코스모스', hue: 330, saturation: 0.70, lightness: 0.65, emoji: '🌺', unlockLevel: 1);
    } else {
      return const SeedInfo(name: '겨울 설화',    hue: 210, saturation: 0.40, lightness: 0.85, emoji: '❄️', unlockLevel: 1);
    }
  }

  static String seasonLabel() {
    final m = DateTime.now().month;
    if (m >= 3 && m <= 5)  return '🌸 봄 한정';
    if (m >= 6 && m <= 8)  return '☀️ 여름 한정';
    if (m >= 9 && m <= 11) return '🍂 가을 한정';
    return '❄️ 겨울 한정';
  }
}

/// Static game balance tables.
abstract final class GameLevels {

  // ── Level progression (20 levels) ─────────────────────────────────────────
  //
  //  Lv  │  XP needed │ Plots │ Tier
  // ─────┼────────────┼───────┼──────────────────
  //   1  │        0   │   2   │ 입문
  //   2  │       60   │   3   │ 입문
  //   3  │      160   │   4   │ 초급
  //   4  │      320   │   5   │ 초급
  //   5  │      550   │   6   │ 초급
  //   6  │      850   │   7   │ 중급
  //   7  │    1,220   │   8   │ 중급
  //   8  │    1,680   │   9   │ 중급
  //   9  │    2,250   │  10   │ 상급
  //  10  │    2,940   │  10   │ 상급
  //  11  │    3,760   │  11   │ 상급
  //  12  │    4,730   │  11   │ 전문
  //  13  │    5,870   │  12   │ 전문
  //  14  │    7,200   │  12   │ 전문
  //  15  │    8,740   │  13   │ 마스터
  //  16  │   10,510   │  13   │ 마스터
  //  17  │   12,530   │  14   │ 마스터
  //  18  │   14,820   │  14   │ 전설
  //  19  │   17,400   │  15   │ 전설
  //  20  │   20,290   │  16   │ 전설

  static const List<LevelConfig> configs = [
    LevelConfig(level:  1, xpRequired:      0, plotCount:  2),
    LevelConfig(level:  2, xpRequired:     60, plotCount:  3),
    LevelConfig(level:  3, xpRequired:    160, plotCount:  4),
    LevelConfig(level:  4, xpRequired:    320, plotCount:  5),
    LevelConfig(level:  5, xpRequired:    550, plotCount:  6),
    LevelConfig(level:  6, xpRequired:    850, plotCount:  7),
    LevelConfig(level:  7, xpRequired:  1_220, plotCount:  8),
    LevelConfig(level:  8, xpRequired:  1_680, plotCount:  9),
    LevelConfig(level:  9, xpRequired:  2_250, plotCount: 10),
    LevelConfig(level: 10, xpRequired:  2_940, plotCount: 10),
    LevelConfig(level: 11, xpRequired:  3_760, plotCount: 11),
    LevelConfig(level: 12, xpRequired:  4_730, plotCount: 11),
    LevelConfig(level: 13, xpRequired:  5_870, plotCount: 12),
    LevelConfig(level: 14, xpRequired:  7_200, plotCount: 12),
    LevelConfig(level: 15, xpRequired:  8_740, plotCount: 13),
    LevelConfig(level: 16, xpRequired: 10_510, plotCount: 13),
    LevelConfig(level: 17, xpRequired: 12_530, plotCount: 14),
    LevelConfig(level: 18, xpRequired: 14_820, plotCount: 14),
    LevelConfig(level: 19, xpRequired: 17_400, plotCount: 15),
    LevelConfig(level: 20, xpRequired: 20_290, plotCount: 16),
  ];

  // ── Level titles ───────────────────────────────────────────────────────────
  static const List<String> titles = [
    '',               // 0 (unused)
    '새싹 원예사',    // 1
    '견습 원예사',    // 2
    '원예사',         // 3
    '숙련 원예사',    // 4
    '베테랑 원예사',  // 5
    '전문 원예사',    // 6
    '정원 관리사',    // 7
    '정원 감정사',    // 8
    '식물학자',       // 9
    '수석 식물학자',  // 10
    '원예 연구원',    // 11
    '정원의 마법사',  // 12
    '화훼 전문가',    // 13
    '자연의 친구',    // 14
    '정원의 현자',    // 15
    '식물 대가',      // 16
    '화원의 달인',    // 17
    '전설의 원예사',  // 18
    '정원의 신',      // 19
    '꽃의 황제',      // 20
  ];

  // ── Seed catalog (40 species) ──────────────────────────────────────────────
  //
  //  색상 가이드  hue: 색조(0-360), saturation: 채도(0-1), lightness: 명도(0-1)
  //  일반 원칙: lightness 0.45~0.65 → 선명한 꽃, 0.70~0.85 → 파스텔

  static const List<SeedInfo> seeds = [

    // ── Lv 1 · 입문 (3종) ────────────────────────────────────────────────────
    SeedInfo(name: '민들레',    hue:  58, saturation: 0.85, lightness: 0.55, emoji: '🌼', unlockLevel:  1),
    SeedInfo(name: '장미',      hue: 355, saturation: 0.80, lightness: 0.50, emoji: '🌹', unlockLevel:  1),
    SeedInfo(name: '튤립',      hue: 340, saturation: 0.75, lightness: 0.60, emoji: '🌷', unlockLevel:  1),

    // ── Lv 2 · 입문 (3종) ────────────────────────────────────────────────────
    SeedInfo(name: '해바라기',  hue:  42, saturation: 0.90, lightness: 0.55, emoji: '🌻', unlockLevel:  2),
    SeedInfo(name: '라벤더',    hue: 270, saturation: 0.65, lightness: 0.58, emoji: '💜', unlockLevel:  2),
    SeedInfo(name: '데이지',    hue:  48, saturation: 0.30, lightness: 0.88, emoji: '🌸', unlockLevel:  2),

    // ── Lv 3 · 초급 (3종) ────────────────────────────────────────────────────
    SeedInfo(name: '국화',      hue: 200, saturation: 0.55, lightness: 0.62, emoji: '🌾', unlockLevel:  3),
    SeedInfo(name: '벚꽃',      hue: 350, saturation: 0.60, lightness: 0.75, emoji: '🌸', unlockLevel:  3),
    SeedInfo(name: '팬지',      hue: 285, saturation: 0.72, lightness: 0.48, emoji: '🌺', unlockLevel:  3),

    // ── Lv 4 · 초급 (3종) ────────────────────────────────────────────────────
    SeedInfo(name: '수선화',    hue:  50, saturation: 0.88, lightness: 0.58, emoji: '🌼', unlockLevel:  4),
    SeedInfo(name: '백합',      hue:  30, saturation: 0.70, lightness: 0.62, emoji: '🌺', unlockLevel:  4),
    SeedInfo(name: '수레국화',  hue: 215, saturation: 0.75, lightness: 0.55, emoji: '💙', unlockLevel:  4),

    // ── Lv 5 · 초급 (3종) ────────────────────────────────────────────────────
    SeedInfo(name: '연꽃',      hue: 310, saturation: 0.65, lightness: 0.65, emoji: '🪷', unlockLevel:  5),
    SeedInfo(name: '카네이션',  hue: 345, saturation: 0.75, lightness: 0.65, emoji: '💐', unlockLevel:  5),
    SeedInfo(name: '아이리스',  hue: 255, saturation: 0.70, lightness: 0.55, emoji: '💜', unlockLevel:  5),

    // ── Lv 6 · 중급 (3종) ────────────────────────────────────────────────────
    SeedInfo(name: '블루로즈',  hue: 220, saturation: 0.60, lightness: 0.58, emoji: '💙', unlockLevel:  6),
    SeedInfo(name: '달리아',    hue: 325, saturation: 0.80, lightness: 0.52, emoji: '🌸', unlockLevel:  6),
    SeedInfo(name: '작약',      hue: 348, saturation: 0.70, lightness: 0.68, emoji: '🌺', unlockLevel:  6),

    // ── Lv 7 · 중급 (3종) ────────────────────────────────────────────────────
    SeedInfo(name: '금잔화',    hue:  35, saturation: 0.90, lightness: 0.55, emoji: '🌼', unlockLevel:  7),
    SeedInfo(name: '제비꽃',    hue: 272, saturation: 0.80, lightness: 0.44, emoji: '💜', unlockLevel:  7),
    SeedInfo(name: '칼라',      hue:  55, saturation: 0.10, lightness: 0.90, emoji: '🤍', unlockLevel:  7),

    // ── Lv 8 · 중급 (3종) ────────────────────────────────────────────────────
    SeedInfo(name: '글라디올러스', hue: 335, saturation: 0.75, lightness: 0.62, emoji: '🌷', unlockLevel:  8),
    SeedInfo(name: '용담',      hue: 230, saturation: 0.72, lightness: 0.50, emoji: '💙', unlockLevel:  8),
    SeedInfo(name: '해당화',    hue:  10, saturation: 0.85, lightness: 0.52, emoji: '🌹', unlockLevel:  8),

    // ── Lv 9 · 상급 (3종) ────────────────────────────────────────────────────
    SeedInfo(name: '클레마티스', hue: 292, saturation: 0.65, lightness: 0.52, emoji: '💜', unlockLevel:  9),
    SeedInfo(name: '에키나세아', hue: 338, saturation: 0.78, lightness: 0.58, emoji: '🌺', unlockLevel:  9),
    SeedInfo(name: '옥잠화',    hue: 145, saturation: 0.25, lightness: 0.72, emoji: '🌿', unlockLevel:  9),

    // ── Lv 10 · 상급 (3종) ───────────────────────────────────────────────────
    SeedInfo(name: '히비스커스', hue:   5, saturation: 0.90, lightness: 0.50, emoji: '🌺', unlockLevel: 10),
    SeedInfo(name: '플루메리아', hue: 355, saturation: 0.65, lightness: 0.75, emoji: '🌸', unlockLevel: 10),
    SeedInfo(name: '극락조화',  hue:  28, saturation: 0.95, lightness: 0.52, emoji: '🌟', unlockLevel: 10),

    // ── Lv 11 · 상급 (2종) ───────────────────────────────────────────────────
    SeedInfo(name: '안개꽃',    hue: 300, saturation: 0.20, lightness: 0.85, emoji: '☁️', unlockLevel: 11),
    SeedInfo(name: '스위트피',  hue: 320, saturation: 0.65, lightness: 0.70, emoji: '🌸', unlockLevel: 11),

    // ── Lv 12 · 전문 (3종) ───────────────────────────────────────────────────
    SeedInfo(name: '파란 양귀비', hue: 210, saturation: 0.80, lightness: 0.52, emoji: '💙', unlockLevel: 12),
    SeedInfo(name: '황금 국화', hue:  45, saturation: 0.95, lightness: 0.52, emoji: '✨', unlockLevel: 12),
    SeedInfo(name: '검은 장미', hue: 350, saturation: 0.35, lightness: 0.18, emoji: '🖤', unlockLevel: 12),

    // ── Lv 14 · 전문 (3종) ───────────────────────────────────────────────────
    SeedInfo(name: '에델바이스', hue: 120, saturation: 0.15, lightness: 0.88, emoji: '🤍', unlockLevel: 14),
    SeedInfo(name: '아마릴리스', hue:   5, saturation: 0.95, lightness: 0.45, emoji: '❤️', unlockLevel: 14),
    SeedInfo(name: '무지개 프리지아', hue: 60, saturation: 0.85, lightness: 0.62, emoji: '🌈', unlockLevel: 14),

    // ── Lv 16 · 마스터 (2종) ─────────────────────────────────────────────────
    SeedInfo(name: '달빛 수선화', hue: 220, saturation: 0.50, lightness: 0.80, emoji: '🌙', unlockLevel: 16),
    SeedInfo(name: '신기루 블루벨', hue: 200, saturation: 0.85, lightness: 0.58, emoji: '💎', unlockLevel: 16),

    // ── Lv 18 · 전설 (2종) ───────────────────────────────────────────────────
    SeedInfo(name: '무지개 연꽃', hue: 280, saturation: 0.72, lightness: 0.62, emoji: '🌈', unlockLevel: 18),
    SeedInfo(name: '황금 벚꽃',  hue:  42, saturation: 0.85, lightness: 0.68, emoji: '✨', unlockLevel: 18),

    // ── Lv 20 · 황제 (1종) ───────────────────────────────────────────────────
    SeedInfo(name: '천상의 백합', hue:  60, saturation: 0.20, lightness: 0.93, emoji: '👑', unlockLevel: 20),
  ];

  // ── Helpers ────────────────────────────────────────────────────────────────

  static int levelFromXP(int xp) {
    for (int i = configs.length - 1; i >= 0; i--) {
      if (xp >= configs[i].xpRequired) return configs[i].level;
    }
    return 1;
  }

  static LevelConfig configFor(int level) =>
      configs.firstWhere((c) => c.level == level, orElse: () => configs.last);

  static LevelConfig? nextConfig(int currentLevel) {
    final idx = configs.indexWhere((c) => c.level == currentLevel);
    if (idx < 0 || idx >= configs.length - 1) return null;
    return configs[idx + 1];
  }

  static String titleFor(int level) =>
      level < titles.length ? titles[level] : titles.last;

  static List<SeedInfo> availableFor(int level) =>
      seeds.where((s) => s.unlockLevel <= level).toList();

  static Set<String> get allSpeciesNames => seeds.map((s) => s.name).toSet();

  static int xpForBreed(String rarityName) => switch (rarityName) {
        'holographic' => 50,
        'rare'        => 20,
        'uncommon'    => 10,
        _             => 5,
      };
}
