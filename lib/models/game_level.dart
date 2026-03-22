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
  final int unlockLevel; // minimum player level required

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

/// Static game balance tables.
abstract final class GameLevels {
  // ── Level progression ──────────────────────────────────────────────────
  static const List<LevelConfig> configs = [
    LevelConfig(level: 1, xpRequired: 0,   plotCount: 2),
    LevelConfig(level: 2, xpRequired: 60,  plotCount: 3),
    LevelConfig(level: 3, xpRequired: 160, plotCount: 4),
    LevelConfig(level: 4, xpRequired: 320, plotCount: 6),
    LevelConfig(level: 5, xpRequired: 540, plotCount: 8),
    LevelConfig(level: 6, xpRequired: 840, plotCount: 9),
  ];

  // ── Level titles ────────────────────────────────────────────────────────
  static const List<String> titles = [
    '',
    '초보 원예사',
    '견습 원예사',
    '원예사',
    '숙련 원예사',
    '마스터 원예사',
    '전설의 원예사',
  ];

  // ── Seed catalog (12 species, unlocked progressively) ──────────────────
  static const List<SeedInfo> seeds = [
    // Lv 1 ─ 3 species
    SeedInfo(name: '민들레',  hue: 58,  saturation: 0.85, lightness: 0.55, emoji: '🌼', unlockLevel: 1),
    SeedInfo(name: '장미',    hue: 355, saturation: 0.80, lightness: 0.50, emoji: '🌹', unlockLevel: 1),
    SeedInfo(name: '튤립',    hue: 340, saturation: 0.75, lightness: 0.60, emoji: '🌷', unlockLevel: 1),
    // Lv 2 ─ +2 species
    SeedInfo(name: '해바라기', hue: 42,  saturation: 0.90, lightness: 0.55, emoji: '🌻', unlockLevel: 2),
    SeedInfo(name: '라벤더',  hue: 270, saturation: 0.65, lightness: 0.58, emoji: '💜', unlockLevel: 2),
    // Lv 3 ─ +2 species
    SeedInfo(name: '국화',    hue: 200, saturation: 0.55, lightness: 0.62, emoji: '🌾', unlockLevel: 3),
    SeedInfo(name: '벚꽃',    hue: 350, saturation: 0.60, lightness: 0.75, emoji: '🌸', unlockLevel: 3),
    // Lv 4 ─ +2 species
    SeedInfo(name: '수선화',  hue: 50,  saturation: 0.88, lightness: 0.58, emoji: '🌼', unlockLevel: 4),
    SeedInfo(name: '백합',    hue: 30,  saturation: 0.70, lightness: 0.62, emoji: '🌺', unlockLevel: 4),
    // Lv 5 ─ +2 species
    SeedInfo(name: '연꽃',    hue: 310, saturation: 0.65, lightness: 0.65, emoji: '🪷', unlockLevel: 5),
    SeedInfo(name: '카네이션', hue: 345, saturation: 0.75, lightness: 0.65, emoji: '💐', unlockLevel: 5),
    // Lv 6 ─ +1 species (final unlock)
    SeedInfo(name: '블루로즈', hue: 220, saturation: 0.60, lightness: 0.58, emoji: '💙', unlockLevel: 6),
  ];

  // ── Helpers ────────────────────────────────────────────────────────────

  /// Returns the level a player is at based on cumulative [xp].
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

  /// Seeds available to a player of [level].
  static List<SeedInfo> availableFor(int level) =>
      seeds.where((s) => s.unlockLevel <= level).toList();

  /// XP granted when a plant is harvested (based on its rarity).
  static int xpForBreed(String rarityName) => switch (rarityName) {
        'holographic' => 50,
        'rare'        => 20,
        'uncommon'    => 10,
        _             => 5,
      };
}
