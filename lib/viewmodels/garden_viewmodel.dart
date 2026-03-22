import 'dart:async';
import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/achievement.dart';
import '../models/daily_quest.dart';
import '../models/game_level.dart';
import '../models/garden_plot.dart';
import '../models/plant.dart';
import '../models/shop_item.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/weather_service.dart';

// ── State ────────────────────────────────────────────────────────────────────

class GardenState {
  final List<GardenPlot> plots;
  final String? selectedPlotId;
  final WeatherGameState weather;
  final int playerXP;
  final int playerLevel;
  final List<Plant> collection;
  final SeedInfo? eventSeed;
  final String? latestAlert;
  final Map<String, int> seedInventory; // species → count
  final int coins;
  final DateTime? lastBoxClaimedAt; // null = never claimed
  final Set<String> ownedEquipment;
  final Map<String, int> consumables; // consumable id → count
  final int gameTickets;            // 0–5, costs 1 per mini-game play
  final DateTime? lastTicketRegenAt; // when current 10-min regen cycle started
  final DateTime? lastDailyRewardAt;    // last daily attendance reward claim
  final DateTime? lastSeasonalClaimAt;  // last seasonal seed claim
  final List<DailyQuest> dailyQuests;
  final DateTime? lastQuestResetAt;     // when quests were last reset (daily)
  final List<Achievement> achievements;
  final int consecutiveDays;           // current login streak

  static const maxGameTickets = 5;
  static const _ticketRegenDuration = Duration(minutes: 10);

  /// True if today's daily reward hasn't been claimed yet.
  bool get canClaimDailyReward {
    if (lastDailyRewardAt == null) return true;
    final last = lastDailyRewardAt!;
    final now = DateTime.now();
    return now.year != last.year || now.month != last.month || now.day != last.day;
  }

  const GardenState({
    required this.plots,
    this.selectedPlotId,
    this.weather = WeatherGameState.sunny,
    this.playerXP = 0,
    this.playerLevel = 1,
    this.collection = const [],
    this.eventSeed,
    this.latestAlert,
    this.seedInventory = const {},
    this.coins = 0,
    this.lastBoxClaimedAt,
    this.ownedEquipment = const {},
    this.consumables = const {},
    this.gameTickets = maxGameTickets,
    this.lastTicketRegenAt,
    this.lastDailyRewardAt,
    this.lastSeasonalClaimAt,
    this.dailyQuests = const [],
    this.lastQuestResetAt,
    this.achievements = const [],
    this.consecutiveDays = 0,
  });

  /// True if this month's seasonal seed hasn't been claimed yet.
  bool get canClaimSeasonalSeed {
    if (lastSeasonalClaimAt == null) return true;
    final last = lastSeasonalClaimAt!;
    final now = DateTime.now();
    return now.year != last.year || now.month != last.month;
  }

  /// Time until the next ticket is regenerated (zero if full or regen done).
  Duration get ticketRegenIn {
    if (gameTickets >= maxGameTickets || lastTicketRegenAt == null) {
      return Duration.zero;
    }
    final remaining = _ticketRegenDuration - DateTime.now().difference(lastTicketRegenAt!);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  GardenPlot? get selectedPlot =>
      plots.where((p) => p.id == selectedPlotId).firstOrNull;
  List<GardenPlot> get occupiedPlots => plots.where((p) => p.hasPlant).toList();
  List<GardenPlot> get emptyPlots    => plots.where((p) => p.isEmpty).toList();
  int get totalSeeds => seedInventory.values.fold(0, (a, b) => a + b);

  static const _boxCooldown = Duration(hours: 3);

  bool get canClaimBox {
    if (lastBoxClaimedAt == null) return true;
    return DateTime.now().difference(lastBoxClaimedAt!) >= _boxCooldown;
  }

  /// Time remaining until next claim (zero if already available).
  Duration get nextBoxIn {
    if (canClaimBox) return Duration.zero;
    final next = lastBoxClaimedAt!.add(_boxCooldown);
    final diff = next.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  int get xpToNextLevel {
    final next = GameLevels.nextConfig(playerLevel);
    return next != null ? next.xpRequired : GameLevels.configs.last.xpRequired;
  }

  double get levelProgress {
    final current = GameLevels.configFor(playerLevel).xpRequired;
    final next    = GameLevels.nextConfig(playerLevel);
    if (next == null) return 1.0;
    return ((playerXP - current) / (next.xpRequired - current)).clamp(0.0, 1.0);
  }

  // ── Cloud serialisation ────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'playerXP': playerXP,
        'playerLevel': playerLevel,
        'coins': coins,
        'seedInventory': seedInventory,
        'ownedEquipment': ownedEquipment.toList(),
        'consumables': consumables,
        'gameTickets': gameTickets,
        'lastBoxClaimedAt': lastBoxClaimedAt?.millisecondsSinceEpoch,
        'lastTicketRegenAt': lastTicketRegenAt?.millisecondsSinceEpoch,
        'lastDailyRewardAt': lastDailyRewardAt?.millisecondsSinceEpoch,
        'lastSeasonalClaimAt': lastSeasonalClaimAt?.millisecondsSinceEpoch,
        'collection': collection.map((p) => p.toJson()).toList(),
        'plots': plots.map((p) => p.toJson()).toList(),
        'dailyQuests': dailyQuests.map((q) => q.toJson()).toList(),
        'lastQuestResetAt': lastQuestResetAt?.millisecondsSinceEpoch,
        'achievements': Achievement.toSavedMap(achievements),
        'consecutiveDays': consecutiveDays,
      };

  factory GardenState.fromCloud(Map<String, dynamic> j) {
    final plotsJson = j['plots'] as List<dynamic>?;
    final collectionJson = j['collection'] as List<dynamic>?;
    return GardenState(
      playerXP: (j['playerXP'] as num?)?.toInt() ?? 0,
      playerLevel: (j['playerLevel'] as num?)?.toInt() ?? 1,
      coins: (j['coins'] as num?)?.toInt() ?? 0,
      seedInventory: (j['seedInventory'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toInt())) ??
          const {},
      ownedEquipment: (j['ownedEquipment'] as List<dynamic>?)
              ?.cast<String>()
              .toSet() ??
          const {},
      consumables: (j['consumables'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toInt())) ??
          const {},
      gameTickets:
          (j['gameTickets'] as num?)?.toInt() ?? GardenState.maxGameTickets,
      lastBoxClaimedAt: j['lastBoxClaimedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (j['lastBoxClaimedAt'] as num).toInt())
          : null,
      lastTicketRegenAt: j['lastTicketRegenAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (j['lastTicketRegenAt'] as num).toInt())
          : null,
      lastDailyRewardAt: j['lastDailyRewardAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (j['lastDailyRewardAt'] as num).toInt())
          : null,
      lastSeasonalClaimAt: j['lastSeasonalClaimAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (j['lastSeasonalClaimAt'] as num).toInt())
          : null,
      collection: collectionJson
              ?.map((p) => Plant.fromJson(p as Map<String, dynamic>))
              .toList() ??
          const [],
      plots: plotsJson
              ?.map((p) => GardenPlot.fromJson(p as Map<String, dynamic>))
              .toList() ??
          List.generate(2, (i) => GardenPlot(id: 'plot_$i', index: i)),
      dailyQuests: j['dailyQuests'] is List
          ? DailyQuest.fromSaved(j['dailyQuests'] as List)
          : DailyQuest.defaults(),
      lastQuestResetAt: j['lastQuestResetAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (j['lastQuestResetAt'] as num).toInt())
          : null,
      achievements: j['achievements'] is Map
          ? Achievement.fromSaved(
              (j['achievements'] as Map).cast<String, dynamic>())
          : Achievement.catalog(),
      consecutiveDays: (j['consecutiveDays'] as num?)?.toInt() ?? 0,
    );
  }

  GardenState copyWith({
    List<GardenPlot>? plots,
    String? selectedPlotId,
    bool clearSelection = false,
    WeatherGameState? weather,
    int? playerXP,
    int? playerLevel,
    List<Plant>? collection,
    SeedInfo? eventSeed,
    bool clearEventSeed = false,
    String? latestAlert,
    bool clearAlert = false,
    Map<String, int>? seedInventory,
    int? coins,
    DateTime? lastBoxClaimedAt,
    bool clearLastBoxClaim = false,
    Set<String>? ownedEquipment,
    Map<String, int>? consumables,
    int? gameTickets,
    DateTime? lastTicketRegenAt,
    bool clearTicketRegen = false,
    DateTime? lastDailyRewardAt,
    DateTime? lastSeasonalClaimAt,
    List<DailyQuest>? dailyQuests,
    DateTime? lastQuestResetAt,
    bool clearQuestReset = false,
    List<Achievement>? achievements,
    int? consecutiveDays,
  }) =>
      GardenState(
        plots: plots ?? this.plots,
        selectedPlotId:
            clearSelection ? null : (selectedPlotId ?? this.selectedPlotId),
        weather: weather ?? this.weather,
        playerXP: playerXP ?? this.playerXP,
        playerLevel: playerLevel ?? this.playerLevel,
        collection: collection ?? this.collection,
        eventSeed: clearEventSeed ? null : (eventSeed ?? this.eventSeed),
        latestAlert: clearAlert ? null : (latestAlert ?? this.latestAlert),
        seedInventory: seedInventory ?? this.seedInventory,
        coins: coins ?? this.coins,
        lastBoxClaimedAt: clearLastBoxClaim ? null : (lastBoxClaimedAt ?? this.lastBoxClaimedAt),
        ownedEquipment: ownedEquipment ?? this.ownedEquipment,
        consumables: consumables ?? this.consumables,
        gameTickets: gameTickets ?? this.gameTickets,
        lastTicketRegenAt: clearTicketRegen
            ? null
            : (lastTicketRegenAt ?? this.lastTicketRegenAt),
        lastDailyRewardAt: lastDailyRewardAt ?? this.lastDailyRewardAt,
        lastSeasonalClaimAt: lastSeasonalClaimAt ?? this.lastSeasonalClaimAt,
        dailyQuests: dailyQuests ?? this.dailyQuests,
        lastQuestResetAt: clearQuestReset
            ? null
            : (lastQuestResetAt ?? this.lastQuestResetAt),
        achievements: achievements ?? this.achievements,
        consecutiveDays: consecutiveDays ?? this.consecutiveDays,
      );
}

// ── Provider ─────────────────────────────────────────────────────────────────

final gardenProvider =
    StateNotifierProvider<GardenNotifier, GardenState>((ref) => GardenNotifier());

// ── Notifier ─────────────────────────────────────────────────────────────────

class GardenNotifier extends StateNotifier<GardenState> {
  Timer? _timer;
  final _rng = Random();
  final _alertedLowHydration = <String>{};

  GardenNotifier() : super(_initial()) {
    _startLoop();
    _ensureAchievementsInitialised();
    _resetQuestsIfNeeded();
  }

  static GardenState _initial() {
    final plots = List.generate(2, (i) => GardenPlot(id: 'plot_$i', index: i));
    final starter = Plant(
      id: 'starter',
      species: '민들레',
      color: const HSLColor.fromAHSL(1.0, 58, 0.85, 0.55),
      growthStage: 0,
      hydration: 70.0,
      rarity: PlantRarity.common,
      createdAt: DateTime.now(),
    );
    return GardenState(
      plots: [plots[0].withPlant(starter), plots[1]],
      selectedPlotId: 'plot_0',
      seedInventory: const {
        '민들레': 3,
        '장미': 2,
        '튤립': 2,
      },
    );
  }

  // ── Game loop ─────────────────────────────────────────────────────────────

  void _startLoop() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
  }

  // Plant dies after 30 minutes at 0% hydration
  static const _droughtDeathDuration = Duration(minutes: 30);

  void _tick() {
    int xpGained = 0;
    String? alert;
    final hydBonus  = _weatherHydBonus(state.weather);
    final careBonus = _weatherCareBonus(state.weather);

    var newPlots = state.plots.map((plot) {
      if (plot.isEmpty) return plot;
      final p = plot.plant!;
      final h = (p.hydration - 2.0 + hydBonus).clamp(0.0, 100.0);

      // ── Drought tracking ──────────────────────────────────────────────
      DateTime? droughtSince = p.droughtSince;
      if (h <= 0 && droughtSince == null) {
        droughtSince = DateTime.now();
      } else if (h > 0) {
        droughtSince = null;
      }

      // ── Death check ───────────────────────────────────────────────────
      if (droughtSince != null &&
          DateTime.now().difference(droughtSince) >= _droughtDeathDuration) {
        _alertedLowHydration.remove(plot.id);
        alert ??= '💀 ${p.displayName}이(가) 시들어 죽었어요...';
        NotificationService.showPlantDied(p.displayName);
        return plot.withPlant(null).withCare(0);
      }

      if (h < 20 && !_alertedLowHydration.contains(plot.id)) {
        _alertedLowHydration.add(plot.id);
        alert ??= '💧 ${p.displayName}이(가) 물이 부족해요!';
        NotificationService.showPlantThirsty(p.displayName);
      } else if (h >= 40) {
        _alertedLowHydration.remove(plot.id);
      }

      var care = plot.carePoints;
      if (h >= 50) {
        care = (care + 5 + careBonus).clamp(0, 100);
      } else if (h < 25) {
        care = (care - 3).clamp(0, 100);
      }

      var stage = p.growthStage;
      if (care >= 100 && stage < 4) {
        stage++;
        care = 0;
        if (stage == 4) {
          xpGained += 20;
          alert ??= '🌸 ${p.displayName}이(가) 만개했어요! 수확하세요';
        }
      }

      return plot
          .withPlant(p.copyWith(
            hydration: h,
            growthStage: stage,
            droughtSince: droughtSince,
            clearDroughtSince: droughtSince == null,
          ))
          .withCare(care);
    }).toList();

    // Game ticket regen (1 per 10 min when below max)
    if (state.gameTickets < GardenState.maxGameTickets &&
        state.lastTicketRegenAt != null) {
      final elapsed = DateTime.now().difference(state.lastTicketRegenAt!);
      if (elapsed >= GardenState._ticketRegenDuration) {
        final newTickets = (state.gameTickets + 1).clamp(0, GardenState.maxGameTickets);
        state = state.copyWith(
          gameTickets: newTickets,
          lastTicketRegenAt: newTickets < GardenState.maxGameTickets ? DateTime.now() : null,
          clearTicketRegen: newTickets >= GardenState.maxGameTickets,
        );
      }
    }

    // Auto-sprinkler equipment
    if (state.ownedEquipment.contains('auto_sprinkler')) {
      newPlots = newPlots.map((plot) {
        if (plot.isEmpty || plot.plant == null) return plot;
        if (plot.plant!.hydration < 30) {
          return plot.withPlant(plot.plant!.copyWith(
            hydration: (plot.plant!.hydration + 10).clamp(0.0, 100.0),
          ));
        }
        return plot;
      }).toList();
    }

    SeedInfo? eventSeed = state.eventSeed;
    if (eventSeed == null && _rng.nextDouble() < 0.004) {
      final locked = GameLevels.seeds
          .where((s) => s.unlockLevel > state.playerLevel)
          .toList();
      final pool = locked.isNotEmpty ? locked : GameLevels.seeds;
      eventSeed = pool[_rng.nextInt(pool.length)];
    }

    state = state.copyWith(
        plots: newPlots, eventSeed: eventSeed, latestAlert: alert);
    if (xpGained > 0) _gainXP(xpGained);
  }

  static double _weatherHydBonus(WeatherGameState w) => switch (w) {
        WeatherGameState.rainy  => 4.0,
        WeatherGameState.stormy => 2.0,
        WeatherGameState.cloudy => 1.0,
        _                       => 0.0,
      };

  static int _weatherCareBonus(WeatherGameState w) => switch (w) {
        WeatherGameState.sunny => 2,
        WeatherGameState.rainy => 1,
        _                      => 0,
      };

  // ── XP & levelling ────────────────────────────────────────────────────────

  void _gainXP(int amount, {List<Plant>? newCollection}) {
    final newXP    = state.playerXP + amount;
    final newLevel = GameLevels.levelFromXP(newXP);
    var plots = state.plots;

    if (newLevel > state.playerLevel) {
      final targetCount = GameLevels.configFor(newLevel).plotCount;
      if (targetCount > plots.length) {
        plots = [...plots];
        for (int i = plots.length; i < targetCount; i++) {
          plots.add(GardenPlot(id: 'plot_$i', index: i));
        }
      }
    }

    state = state.copyWith(
      playerXP: newXP,
      playerLevel: newLevel,
      plots: plots,
      collection: newCollection ?? state.collection,
    );
    if (newLevel >=  5) unlockAchievement('level_5');
    if (newLevel >= 10) unlockAchievement('level_10');
    if (newLevel >= 15) unlockAchievement('level_15');
    if (newLevel >= 20) unlockAchievement('level_20');
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void selectPlot(String plotId) =>
      state = state.copyWith(selectedPlotId: plotId);

  void plantSeed(String plotId, Plant seed) {
    _updatePlot(plotId, (p) => p.withPlant(seed).withCare(0));
    state = state.copyWith(selectedPlotId: plotId);
  }

  /// Plant from seed inventory — returns false if species not available.
  bool plantFromInventory(String plotId, String species) {
    final count = state.seedInventory[species] ?? 0;
    if (count <= 0) return false;

    final seedInfo = GameLevels.seeds.firstWhere(
      (s) => s.name == species,
      orElse: () => GameLevels.seeds.first,
    );
    final plant = Plant(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      species: species,
      color: seedInfo.hslColor,
      growthStage: 0,
      hydration: 70,
      rarity: PlantRarity.common,
      createdAt: DateTime.now(),
    );

    _updatePlot(plotId, (p) => p.withPlant(plant).withCare(0));
    state = state.copyWith(selectedPlotId: plotId);
    checkAchievements(planted: true);

    final newInv = Map<String, int>.from(state.seedInventory);
    if (count == 1) {
      newInv.remove(species);
    } else {
      newInv[species] = count - 1;
    }
    state = state.copyWith(seedInventory: newInv);
    return true;
  }

  /// Add seeds gained from mini-games to inventory.
  void addSeedsToInventory(Map<String, int> seeds) {
    final newInv = Map<String, int>.from(state.seedInventory);
    for (final entry in seeds.entries) {
      newInv[entry.key] = (newInv[entry.key] ?? 0) + entry.value;
    }
    state = state.copyWith(seedInventory: newInv);
  }

  void claimEventSeed() {
    final seed = state.eventSeed;
    if (seed == null) return;
    final emptyPlot = state.emptyPlots.firstOrNull;
    if (emptyPlot == null) {
      // Add to inventory instead
      addSeedsToInventory({seed.name: 1});
      state = state.copyWith(clearEventSeed: true);
      return;
    }
    final plant = Plant(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      species: seed.name,
      color: seed.hslColor,
      growthStage: 0,
      hydration: 80.0,
      rarity: PlantRarity.uncommon,
      createdAt: DateTime.now(),
    );
    _updatePlot(emptyPlot.id, (p) => p.withPlant(plant).withCare(0));
    state = state.copyWith(selectedPlotId: emptyPlot.id, clearEventSeed: true);
    _gainXP(15);
  }

  void dismissEvent() => state = state.copyWith(clearEventSeed: true);
  void clearAlert()   => state = state.copyWith(clearAlert: true);

  // ── Daily quests ──────────────────────────────────────────────────────────

  void _resetQuestsIfNeeded() {
    final last = state.lastQuestResetAt;
    final now = DateTime.now();
    if (last == null ||
        now.year != last.year ||
        now.month != last.month ||
        now.day != last.day) {
      state = state.copyWith(
        dailyQuests: DailyQuest.defaults(),
        lastQuestResetAt: now,
      );
    }
  }

  /// Progress a quest by type. Ignores if already completed.
  void progressQuest(QuestType type) {
    _resetQuestsIfNeeded();
    final quests = state.dailyQuests.map((q) {
      if (q.type != type || q.completed) return q;
      return q.copyWith(progress: q.progress + 1);
    }).toList();
    state = state.copyWith(dailyQuests: quests);
  }

  /// Claim reward for a completed quest. Returns {coins, seeds} or null.
  Map<String, int>? claimQuestReward(String questId) {
    final quest = state.dailyQuests.where((q) => q.id == questId).firstOrNull;
    if (quest == null || !quest.completed || quest.claimed) return null;

    final quests = state.dailyQuests
        .map((q) => q.id == questId ? q.copyWith(claimed: true) : q)
        .toList();

    if (quest.rewardSeeds > 0) {
      final pool = GameLevels.seeds
          .where((s) => s.unlockLevel <= state.playerLevel)
          .toList();
      if (pool.isNotEmpty) {
        final seedMap = <String, int>{};
        for (int i = 0; i < quest.rewardSeeds; i++) {
          final s = pool[_rng.nextInt(pool.length)].name;
          seedMap[s] = (seedMap[s] ?? 0) + 1;
        }
        addSeedsToInventory(seedMap);
      }
    }

    state = state.copyWith(
      dailyQuests: quests,
      coins: state.coins + quest.rewardCoins,
    );
    return {'coins': quest.rewardCoins, 'seeds': quest.rewardSeeds};
  }

  // ── Achievements ──────────────────────────────────────────────────────────

  void _ensureAchievementsInitialised() {
    if (state.achievements.isEmpty) {
      state = state.copyWith(achievements: Achievement.catalog());
    }
  }

  /// Unlock an achievement if not already unlocked. Returns true if newly unlocked.
  bool unlockAchievement(String id) {
    final achievements = state.achievements;
    final idx = achievements.indexWhere((a) => a.id == id);
    if (idx < 0 || achievements[idx].unlocked) return false;

    final updated = [...achievements];
    updated[idx] = achievements[idx].copyWithUnlocked();
    state = state.copyWith(
      achievements: updated,
      latestAlert: '🏅 업적 달성: ${updated[idx].title}!',
    );
    return true;
  }

  void checkAchievements({
    bool planted = false,
    bool harvested = false,
    bool bred = false,
  }) {
    if (planted) unlockAchievement('first_plant');
    if (harvested) {
      unlockAchievement('first_harvest');
      final species = state.collection.map((p) => p.species).toSet().length;
      if (species >= 5)  unlockAchievement('collection_5');
      if (species >= 10) unlockAchievement('collection_10');
      if (species >= 20) unlockAchievement('collection_20');
      if (species >= GameLevels.seeds.length) unlockAchievement('collection_all');
    }
    if (bred) unlockAchievement('first_breed');
  }

  void unlockFriendAchievement()       => unlockAchievement('first_friend');
  void unlockWaterGiftAchievement()   => unlockAchievement('water_gift');
  void unlockWeeklyTop3Achievement()  => unlockAchievement('weekly_top3');

  void water(String plotId) {
    final amount = state.ownedEquipment.contains('water_pro') ? 35.0 : 20.0;
    _updatePlot(plotId, (p) {
      if (p.isEmpty) return p;
      return p.withPlant(p.plant!
          .copyWith(hydration: (p.plant!.hydration + amount).clamp(0.0, 100.0)));
    });
    progressQuest(QuestType.waterPlants);
  }

  void harvest(String plotId) {
    final plot = _find(plotId);
    if (plot == null || plot.plant == null) return;
    final plant = plot.plant!;
    final newCollection = [...state.collection, plant];
    _updatePlot(plotId, (p) => p.withPlant(null).withCare(0));
    final xpGain = 30 + switch (plant.rarity) {
      PlantRarity.holographic => 50,
      PlantRarity.rare        => 20,
      PlantRarity.uncommon    => 10,
      PlantRarity.common      => 0,
    };
    _gainXP(xpGain, newCollection: newCollection);
    progressQuest(QuestType.harvestPlant);
    checkAchievements(harvested: true);
  }

  void removePlant(String plotId) {
    _updatePlot(plotId, (p) => p.withPlant(null).withCare(0));
  }

  void importToCollection(Plant plant) {
    state = state.copyWith(collection: [...state.collection, plant]);
  }

  PlantRarity? breed(String plotId) {
    final plot = _find(plotId);
    if (plot == null || plot.plant == null || plot.plant!.growthStage < 2) {
      return null;
    }
    final emptyPlot = state.emptyPlots.firstOrNull;
    if (emptyPlot == null) return null;
    final others = state.occupiedPlots.where((p) => p.id != plotId).toList();
    final partner = others.isNotEmpty
        ? others[_rng.nextInt(others.length)].plant!
        : _wildPlant();
    final offspring = Plant.crossBreed(plot.plant!, partner);
    _updatePlot(emptyPlot.id, (p) => p.withPlant(offspring).withCare(0));
    state = state.copyWith(selectedPlotId: emptyPlot.id);
    _gainXP(GameLevels.xpForBreed(offspring.rarity.name));
    checkAchievements(bred: true);
    return offspring.rarity;
  }

  // ── Game tickets ──────────────────────────────────────────────────────────

  /// Deduct 1 game ticket. Returns false if none left.
  bool deductTicket() {
    if (state.gameTickets <= 0) return false;
    final newTickets = state.gameTickets - 1;
    final startRegen = state.gameTickets >= GardenState.maxGameTickets;
    state = state.copyWith(
      gameTickets: newTickets,
      lastTicketRegenAt: startRegen ? DateTime.now() : state.lastTicketRegenAt,
    );
    return true;
  }

  // ── Shop & economy ────────────────────────────────────────────────────────

  /// Claim a free seed box (3-hour cooldown). Returns seeds gained, or null if on cooldown.
  Map<String, int>? claimDailyBox() {
    if (!state.canClaimBox) return null;

    final count = _rng.nextDouble() < 0.35 ? 2 : 1;
    final pool = GameLevels.seeds;
    final result = <String, int>{};
    for (int i = 0; i < count; i++) {
      final s = pool[_rng.nextInt(pool.length)].name;
      result[s] = (result[s] ?? 0) + 1;
    }
    addSeedsToInventory(result);
    state = state.copyWith(lastBoxClaimedAt: DateTime.now());
    return result;
  }

  /// Sell a plant from the collection for coins. Returns coins earned or 0.
  int sellPlantFromCollection(String plantId) {
    final plant = state.collection.where((p) => p.id == plantId).firstOrNull;
    if (plant == null) return 0;
    final earned = ShopCatalog.sellPrice(plant.rarity);
    state = state.copyWith(
      collection: state.collection.where((p) => p.id != plantId).toList(),
      coins: state.coins + earned,
    );
    return earned;
  }

  /// Purchase an item from the shop. Returns false if insufficient coins.
  bool buyItem(ShopItem item) {
    if (state.coins < item.price) return false;
    final newCoins = state.coins - item.price;
    switch (item.type) {
      case ShopItemType.equipment:
        if (state.ownedEquipment.contains(item.id)) return false;
        state = state.copyWith(
          coins: newCoins,
          ownedEquipment: {...state.ownedEquipment, item.id},
        );
      case ShopItemType.seed:
        final newInv = Map<String, int>.from(state.seedInventory);
        newInv[item.id] = (newInv[item.id] ?? 0) + 1;
        state = state.copyWith(coins: newCoins, seedInventory: newInv);
      case ShopItemType.consumable:
        final newCons = Map<String, int>.from(state.consumables);
        newCons[item.id] = (newCons[item.id] ?? 0) + 1;
        state = state.copyWith(coins: newCoins, consumables: newCons);
    }
    return true;
  }

  /// Use a consumable on a specific plot.
  void useConsumable(String consumableId, String plotId) {
    final count = state.consumables[consumableId] ?? 0;
    if (count <= 0) return;
    final newCons = Map<String, int>.from(state.consumables);
    if (count == 1) {
      newCons.remove(consumableId);
    } else {
      newCons[consumableId] = count - 1;
    }
    switch (consumableId) {
      case 'fertilizer':
        _updatePlot(plotId, (p) {
          if (p.isEmpty) return p;
          return p.withCare((p.carePoints + 30).clamp(0, 100));
        });
      case 'growth_boost':
        _updatePlot(plotId, (p) {
          if (p.isEmpty || p.plant == null) return p;
          final newStage = (p.plant!.growthStage + 1).clamp(0, 4);
          return p.withPlant(p.plant!.copyWith(growthStage: newStage));
        });
    }
    state = state.copyWith(consumables: newCons);
  }

  /// Daily attendance reward. Returns {coins: N, seeds: M} or null if already claimed today.
  Map<String, int>? claimDailyReward() {
    if (!state.canClaimDailyReward) return null;

    // Consecutive days tracking
    final last = state.lastDailyRewardAt;
    final now  = DateTime.now();
    int streak = state.consecutiveDays;
    if (last != null) {
      final yesterday = now.subtract(const Duration(days: 1));
      final wasYesterday = last.year == yesterday.year &&
          last.month == yesterday.month &&
          last.day == yesterday.day;
      streak = wasYesterday ? streak + 1 : 1;
    } else {
      streak = 1;
    }

    final coins = 20 + _rng.nextInt(31);  // 20–50
    final seedCount = 1 + _rng.nextInt(3); // 1–3

    final pool = GameLevels.seeds
        .where((s) => s.unlockLevel <= state.playerLevel)
        .toList();
    if (pool.isEmpty) {
      state = state.copyWith(
        coins: state.coins + coins,
        lastDailyRewardAt: DateTime.now(),
        consecutiveDays: streak,
      );
      _checkStreakAchievements(streak);
      return {'coins': coins, 'seeds': 0};
    }

    final seedMap = <String, int>{};
    for (int i = 0; i < seedCount; i++) {
      final s = pool[_rng.nextInt(pool.length)].name;
      seedMap[s] = (seedMap[s] ?? 0) + 1;
    }
    addSeedsToInventory(seedMap);
    state = state.copyWith(
      coins: state.coins + coins,
      lastDailyRewardAt: DateTime.now(),
      consecutiveDays: streak,
    );
    _checkStreakAchievements(streak);
    return {'coins': coins, 'seeds': seedCount};
  }

  void _checkStreakAchievements(int streak) {
    if (streak >= 3) unlockAchievement('streak_3');
    if (streak >= 7) unlockAchievement('streak_7');
  }

  /// Rename a plant in a specific plot.
  void renamePlant(String plotId, String name) {
    _updatePlot(plotId, (p) {
      if (p.plant == null) return p;
      return p.withPlant(p.plant!.copyWith(
        customName: name.isNotEmpty ? name : null,
        clearCustomName: name.isEmpty,
      ));
    });
  }

  /// Claim the monthly seasonal seed. Returns false if already claimed this month.
  bool claimSeasonalSeed(String seedName) {
    if (!state.canClaimSeasonalSeed) return false;
    final newInv = Map<String, int>.from(state.seedInventory);
    newInv[seedName] = (newInv[seedName] ?? 0) + 1;
    state = state.copyWith(
      seedInventory: newInv,
      lastSeasonalClaimAt: DateTime.now(),
    );
    return true;
  }

  /// Apply a received water gift — boosts the driest plant's hydration by 20.
  void applyWaterGift(String fromNickname) {
    final occupied = state.plots.where((p) => p.hasPlant).toList();
    if (occupied.isEmpty) return;
    occupied.sort((a, b) => a.plant!.hydration.compareTo(b.plant!.hydration));
    final driest = occupied.first;
    _updatePlot(driest.id, (p) => p.withPlant(
          p.plant!.copyWith(
              hydration: (p.plant!.hydration + 20).clamp(0.0, 100.0)),
        ));
    state = state.copyWith(
        latestAlert: '💧 ${fromNickname}님이 물을 선물했어요! +20%');
  }

  /// Add 1 ticket from watching an ad (max = maxGameTickets).
  void addAdTicket() {
    if (state.gameTickets >= GardenState.maxGameTickets) return;
    final newTickets = state.gameTickets + 1;
    state = state.copyWith(
      gameTickets: newTickets,
      clearTicketRegen: newTickets >= GardenState.maxGameTickets,
    );
  }

  /// Grant weekly reward coins + random seeds.
  void addCoinsAndSeeds(int coins, int seedCount) {
    final pool = GameLevels.seeds
        .where((s) => s.unlockLevel <= state.playerLevel)
        .toList();
    if (pool.isEmpty) {
      state = state.copyWith(coins: state.coins + coins);
      return;
    }
    final seedMap = <String, int>{};
    for (int i = 0; i < seedCount; i++) {
      final s = pool[_rng.nextInt(pool.length)].name;
      seedMap[s] = (seedMap[s] ?? 0) + 1;
    }
    addSeedsToInventory(seedMap);
    state = state.copyWith(coins: state.coins + coins);
  }

  // ── Cloud sync ────────────────────────────────────────────────────────────

  /// Load state from Firestore after login.
  Future<void> loadFromCloud(String uid) async {
    final data = await FirestoreService.loadGarden(uid);
    if (data != null) state = GardenState.fromCloud(data);
    _ensureAchievementsInitialised();
    _resetQuestsIfNeeded();
  }

  /// Force-save current state to Firestore.
  Future<void> saveToCloud(String uid) async {
    try {
      await FirestoreService.saveGarden(uid, state.toJson());
    } catch (_) {}
  }

  Future<void> refreshWeather() async {
    final data = await WeatherService().fetchGameWeather();
    state = state.copyWith(weather: data.gameState);
  }

  GardenPlot? _find(String id) =>
      state.plots.where((p) => p.id == id).firstOrNull;

  void _updatePlot(String id, GardenPlot Function(GardenPlot) fn) {
    state = state.copyWith(
        plots: state.plots.map((p) => p.id == id ? fn(p) : p).toList());
  }

  Plant _wildPlant() {
    // Pick from early-game species so wild plants feel discoverable
    const species = [
      '장미', '튤립', '해바라기', '라벤더', '벚꽃', '국화',
      '수선화', '백합', '달리아', '금잔화', '팬지', '제비꽃',
    ];
    return Plant(
      id: 'wild_${DateTime.now().microsecondsSinceEpoch}',
      species: species[_rng.nextInt(species.length)],
      color: HSLColor.fromAHSL(1.0, _rng.nextDouble() * 360,
          0.55 + _rng.nextDouble() * 0.35, 0.40 + _rng.nextDouble() * 0.20),
      growthStage: 1 + _rng.nextInt(3),
      hydration: 60,
      rarity: PlantRarity.common,
      createdAt: DateTime.now(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
