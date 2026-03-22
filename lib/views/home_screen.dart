import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../effects/butterfly_painter.dart';
import '../models/game_level.dart';
import '../models/garden_plot.dart';
import '../models/plant.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/sync_service.dart';
import '../services/weather_service.dart';
import '../utils/share_helper.dart';
import '../viewmodels/garden_viewmodel.dart';
import '../widgets/plant_painter.dart';
import '../services/connectivity_service.dart';
import 'auth/login_screen.dart';
import 'collection_screen.dart';
import 'mini_game_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey _plantKey  = GlobalKey(); // individual plant share
  final GlobalKey _gardenKey = GlobalKey(); // full garden share
  late final AnimationController _animCtrl;
  late ButterflyFlock _flock;
  Size _lastSize = const Size(400, 800);

  @override
  void initState() {
    super.initState();
    _flock = ButterflyFlock(count: 4, size: _lastSize);
    _animCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 10))
          ..repeat();
    _animCtrl.addListener(_tick);
  }

  @override
  void dispose() {
    _animCtrl.removeListener(_tick);
    _animCtrl.dispose();
    super.dispose();
  }

  void _tick() {
    setState(() =>
        _flock.tick(_lastSize, Offset(_lastSize.width / 2, _lastSize.height * 0.35)));
  }

  // ── Seed picker ────────────────────────────────────────────────────────────

  void _showSeedPicker(String plotId) {
    final state = ref.read(gardenProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SeedPickerSheet(
        inventory: state.seedInventory,
        onSelect: (species) {
          final ok = ref.read(gardenProvider.notifier).plantFromInventory(plotId, species);
          if (!ok) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('씨앗이 부족합니다. 미니게임으로 씨앗을 모아보세요!')),
            );
          }
          Navigator.pop(context);
        },
        onGoMiniGame: () {
          Navigator.pop(context);
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const MiniGameScreen()));
        },
      ),
    );
  }

  // ── Breed ──────────────────────────────────────────────────────────────────

  void _breed(String plotId) {
    final rarity = ref.read(gardenProvider.notifier).breed(plotId);
    if (rarity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('\ube48 \ud654\ub2e8\uc774 \uc5c6\uac70\ub098 \ubaa8\uc885(2\ub2e8\uacc4) \uc774\uc0c1\uc774\uc5b4\uc57c \ud569\ub2c8\ub2e4.')));
      return;
    }
    _showRarityReveal(rarity);
  }

  void _showRarityReveal(PlantRarity rarity) {
    final (label, color) = switch (rarity) {
      PlantRarity.holographic => ('\u2728 \ud640\ub85c\uadf8\ub798\ud53d \ud0c4\uc0dd!', Colors.purple),
      PlantRarity.rare        => ('\u2b50 \ud76c\uadc0\uc885 \ud0c4\uc0dd!', Colors.orange),
      PlantRarity.uncommon    => ('\uD83C\uDF3F \ube44\ubc94\uc885 \ud0c4\uc0dd', Colors.teal),
      PlantRarity.common      => ('\uD83C\uDF31 \uc77c\ubc18\uc885 \ud0c4\uc0dd', Colors.green),
    };
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B2B1B),
        title: Text(label,
            style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        content: const Text('\uc0c8 \uad50\ubc30 \uc2dd\ubb3c\uc774 \ube48 \ud654\ub2e8\uc5d0 \uc2ec\uc5b4\uc84c\uc2b5\ub2c8\ub2e4! \uD83C\uDF38',
            style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('\ud655\uc778', style: TextStyle(color: Colors.greenAccent)))
        ],
      ),
    );
  }

  // ── Level-up dialog ────────────────────────────────────────────────────────

  void _onLevelUp(int newLevel) {
    final config = GameLevels.configFor(newLevel);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2E1A),
        title: Text('\uD83C\uDF89 \ub808\ubca8 \uc5c5!',
            style: const TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Lv.$newLevel  ${GameLevels.titleFor(newLevel)}',
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            _LevelRewardRow(icon: Icons.grid_view_rounded,
                text: '\ud654\ub2e8 ${config.plotCount}\uce78 \ud574\uae08'),
            const SizedBox(height: 6),
            _LevelRewardRow(icon: Icons.spa_rounded,
                text: '${GameLevels.availableFor(newLevel).length}\uc885 \uc528\uc557 \ud574\uae08'),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('\ud655\uc778', style: TextStyle(color: Colors.greenAccent)))
        ],
      ),
    );
  }

  // ── Rare event dialog ──────────────────────────────────────────────────────

  void _showEventDialog(SeedInfo seed) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2415),
        title: Text('${seed.emoji} \uc2e0\ube44\ub85c\uc6b4 \uc528\uc557 \ubc1c\uac2c!',
            style: const TextStyle(
                color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(seed.name,
                style: const TextStyle(
                    color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
                '\ud76c\uadc0\ud55c \uc528\uc557\uc774 \uc815\uc6d0\uc5d0 \ub098\ud0c0\ub0ac\uc2b5\ub2c8\ub2e4!\n\ube48 \ud654\ub2e8\uc5d0 \uc2ec\uaca0\uc2b5\ub2c8\uae4c?',
                style: TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              ref.read(gardenProvider.notifier).dismissEvent();
              Navigator.pop(context);
            },
            child: const Text('\ub2e4\uc74c\uc5d0',
                style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white),
            onPressed: () {
              ref.read(gardenProvider.notifier).claimEventSeed();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${seed.name} \uc2dc\uc2dc\ub429\ub2c8\ub2e4! \uD83C\uDF31')),
              );
            },
            child: const Text('\uc2dc\uc2dc\ub2e4!'),
          ),
        ],
      ),
    );
  }

  // ── Share ──────────────────────────────────────────────────────────────────

  Future<void> _sharePlant(GardenPlot plot) async {
    if (plot.plant == null) return;
    try {
      await ShareHelper.captureAndShare(
          repaintKey: _plantKey, plant: plot.plant!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('\uacf5\uc720 \uc2e4\ud328: $e')));
      }
    }
  }

  Future<void> _shareGarden() async {
    try {
      await ShareHelper.captureGarden(gardenKey: _gardenKey);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('\uc815\uc6d0 \uacf5\uc720 \uc2e4\ud328: $e')));
      }
    }
  }

  // ── Weather ────────────────────────────────────────────────────────────────

  Future<void> _refreshWeather() async {
    await ref.read(gardenProvider.notifier).refreshWeather();
    if (!mounted) return;
    final w = ref.read(gardenProvider).weather;
    final label = switch (w) {
      WeatherGameState.sunny  => '\ub9d1\uc74c \u2600',
      WeatherGameState.cloudy => '\ud750\ub9bc \u2601',
      WeatherGameState.rainy  => '\ube44 \uD83C\uDF27',
      WeatherGameState.stormy => '\ud3ed\ud48d \u26C8',
      WeatherGameState.night  => '\ubc24 \uD83C\uDF19',
    };
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('\ub0a0\uc528: $label'), duration: const Duration(seconds: 2)));
  }

  // ── Auth & Social ─────────────────────────────────────────────────────────

  void _openProfile() {
    final user = ref.read(authProvider);
    if (user == null) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  Future<void> _checkWeeklyReward(String uid) async {
    try {
      final reward = await FirestoreService.checkAndClaimWeeklyReward(uid);
      if (reward == null || !mounted) return;
      final rank = reward['rank'] as int;
      final coins = reward['coins'] as int;
      final seeds = reward['seeds'] as int;
      ref
          .read(gardenProvider.notifier)
          .addCoinsAndSeeds(coins, seeds);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1A2E1A),
          title: Text('🏆 지난 주 $rank위!',
              style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('주간 랭킹 보상을 받았어요!',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 16),
            Text('🪙 $coins 코인',
                style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Text('🌱 씨앗 $seeds개',
                style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ]),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context),
              child: const Text('받기!'),
            ),
          ],
        ),
      );
    } catch (_) {}
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    _lastSize = size;
    final anim = _animCtrl.value;

    // Level-up detection
    ref.listen<GardenState>(gardenProvider, (prev, next) {
      if (prev != null && next.playerLevel > prev.playerLevel) {
        _onLevelUp(next.playerLevel);
      }
      // In-app alert
      if (next.latestAlert != null &&
          (prev == null || next.latestAlert != prev.latestAlert)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.latestAlert!),
            backgroundColor: const Color(0xFF2E4028),
            duration: const Duration(seconds: 3),
          ),
        );
        ref.read(gardenProvider.notifier).clearAlert();
      }
      // Rare event seed
      if (next.eventSeed != null &&
          (prev == null || next.eventSeed?.name != prev.eventSeed?.name)) {
        _showEventDialog(next.eventSeed!);
      }
    });

    // Activate cloud sync (30-second debounce)
    ref.watch(gardenSyncProvider);

    // Auth state listener – load cloud data on login / navigate on logout
    ref.listen<AppUser?>(authProvider, (prev, next) async {
      if (next != null && prev == null) {
        await ref.read(gardenProvider.notifier).loadFromCloud(next.uid);
        if (!context.mounted) return;
        _checkWeeklyReward(next.uid);
      } else if (next == null && prev != null) {
        // 로그아웃 → 로그인 화면으로
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          );
        }
      }
    });

    final state = ref.watch(gardenProvider);
    final weatherIcon = switch (state.weather) {
      WeatherGameState.sunny  => Icons.wb_sunny_rounded,
      WeatherGameState.cloudy => Icons.cloud_rounded,
      WeatherGameState.rainy  => Icons.water_drop_rounded,
      WeatherGameState.stormy => Icons.thunderstorm_rounded,
      WeatherGameState.night  => Icons.nights_stay_rounded,
    };

    final isOnline = ref.watch(connectivityProvider).valueOrNull ?? true;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // 오프라인 배너
          if (!isOnline)
            Material(
              color: Colors.orange[800],
              child: const SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off_rounded,
                          color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text(
                        '오프라인 상태 — 저장된 데이터로 플레이 중',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: RepaintBoundary(
        key: _gardenKey,
        child: Stack(
          children: [
            // ── Background (season + day/night) ───────────────────────────
            _GardenBackground(weather: state.weather),

            // ── Butterflies ───────────────────────────────────────────────
            RepaintBoundary(
              key: _plantKey,
              child: CustomPaint(
                painter: ButterflyPainter(flock: _flock, animationValue: anim),
                size: size,
              ),
            ),

            // ── Main content ──────────────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  // Top bar
                  _TopBar(
                    level: state.playerLevel,
                    collectionCount: state.collection.length,
                    seedCount: state.totalSeeds,
                    coins: state.coins,
                    weatherIcon: weatherIcon,
                    hasEvent: state.eventSeed != null,
                    userInitial: (() {
                      final n = ref.watch(authProvider)?.displayName;
                      return (n != null && n.isNotEmpty) ? n[0] : null;
                    })(),
                    onWeather: _refreshWeather,
                    onShareGarden: _shareGarden,
                    onProfile: _openProfile,
                    onCollection: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CollectionScreen()),
                    ),
                    onMiniGame: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MiniGameScreen()),
                    ),
                    onShop: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ShopScreen()),
                    ),
                  ),

                  // XP / level bar
                  _XPBar(
                    level: state.playerLevel,
                    xp: state.playerXP,
                    progress: state.levelProgress,
                    nextXP: state.xpToNextLevel,
                    isMax: GameLevels.nextConfig(state.playerLevel) == null,
                    occupiedCount: state.occupiedPlots.length,
                    plotCount: state.plots.length,
                  ),

                  // Fence
                  const _Fence(),

                  // Garden grid (scrollable)
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.68,
                        ),
                        itemCount: state.plots.length,
                        itemBuilder: (_, i) {
                          final plot = state.plots[i];
                          final selected = plot.id == state.selectedPlotId;
                          final phaseAnim = (anim + i * 0.16) % 1.0;
                          return _PlotCard(
                            plot: plot,
                            isSelected: selected,
                            animValue: phaseAnim,
                            onTap: () {
                              ref.read(gardenProvider.notifier).selectPlot(plot.id);
                              if (plot.isEmpty) _showSeedPicker(plot.id);
                            },
                          );
                        },
                      ),
                    ),
                  ),

                  // Bottom panel
                  _BottomPanel(
                    selectedPlot: state.selectedPlot,
                    onWater:   (id) => ref.read(gardenProvider.notifier).water(id),
                    onBreed:   _breed,
                    onHarvest: (id) => ref.read(gardenProvider.notifier).harvest(id),
                    onRemove:  (id) => ref.read(gardenProvider.notifier).removePlant(id),
                    onShare:   _sharePlant,
                    onPlant:   _showSeedPicker,
                  ),
                ],
              ),
            ),
          ],
        ),
          ),  // RepaintBoundary
          ),  // Expanded
        ],    // outer Column children
      ),      // outer Column (body)
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Level-up reward row
// ─────────────────────────────────────────────────────────────────────────────
class _LevelRewardRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _LevelRewardRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: Colors.greenAccent, size: 16),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Background  (season-aware + day/night tint)
// ─────────────────────────────────────────────────────────────────────────────

class _GardenBackground extends StatelessWidget {
  final WeatherGameState weather;
  const _GardenBackground({required this.weather});

  static _Season _currentSeason() {
    final m = DateTime.now().month;
    if (m >= 3 && m <= 5) return _Season.spring;
    if (m >= 6 && m <= 8) return _Season.summer;
    if (m >= 9 && m <= 11) return _Season.fall;
    return _Season.winter;
  }

  static Color _timeOverlay() {
    final h = DateTime.now().hour;
    if (h >= 6 && h < 8)  return Colors.orange.withValues(alpha: 0.18); // dawn
    if (h >= 8 && h < 18) return Colors.transparent;                    // day
    if (h >= 18 && h < 20) return Colors.deepOrange.withValues(alpha: 0.18); // dusk
    return Colors.indigo.withValues(alpha: 0.30);                        // night
  }

  @override
  Widget build(BuildContext context) {
    final season = _currentSeason();

    final colors = switch (weather) {
      WeatherGameState.sunny  => _seasonSunny(season),
      WeatherGameState.cloudy => [const Color(0xFF78909C), const Color(0xFF388E3C)],
      WeatherGameState.rainy  => [const Color(0xFF37474F), const Color(0xFF1B5E20)],
      WeatherGameState.stormy => [const Color(0xFF212121), const Color(0xFF1A2E1A)],
      WeatherGameState.night  => [const Color(0xFF0D1B2A), const Color(0xFF0A1F0A)],
    };

    final overlay = _timeOverlay();

    return Stack(children: [
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ),
        ),
      ),
      if (overlay != Colors.transparent)
        Container(color: overlay),
    ]);
  }

  static List<Color> _seasonSunny(_Season s) => switch (s) {
    _Season.spring => [const Color(0xFF81C784), const Color(0xFF2E7D32)],
    _Season.summer => [const Color(0xFF4CAF50), const Color(0xFF1B5E20)],
    _Season.fall   => [const Color(0xFFBF8040), const Color(0xFF4E342E)],
    _Season.winter => [const Color(0xFF90A4AE), const Color(0xFF37474F)],
  };
}

enum _Season { spring, summer, fall, winter }

// ─────────────────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final int level, collectionCount, seedCount, coins;
  final IconData weatherIcon;
  final bool hasEvent;
  final String? userInitial;
  final VoidCallback onWeather, onCollection, onShareGarden, onMiniGame,
      onShop, onProfile;

  const _TopBar({
    required this.level,
    required this.collectionCount,
    required this.seedCount,
    required this.coins,
    required this.weatherIcon,
    required this.hasEvent,
    required this.userInitial,
    required this.onWeather,
    required this.onCollection,
    required this.onShareGarden,
    required this.onMiniGame,
    required this.onShop,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
      child: Row(
        children: [
          const Text('\uD83C\uDF3F \ub098\ub9cc\uc758 \uc815\uc6d0',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(color: Colors.black38, blurRadius: 6)])),
          const Spacer(),
          // Coins (tapping goes to shop)
          _CoinChip(coins: coins, onTap: onShop),
          const SizedBox(width: 6),
          // Mini-game
          _IconBtn(
            icon: Icons.sports_esports_rounded,
            badge: seedCount > 0 ? '$seedCount' : null,
            onTap: onMiniGame,
          ),
          const SizedBox(width: 6),
          // Collection
          _IconBtn(
            icon: Icons.collections_bookmark_rounded,
            badge: collectionCount > 0 ? '$collectionCount' : null,
            onTap: onCollection,
          ),
          const SizedBox(width: 6),
          // Share garden
          _IconBtn(icon: Icons.share_rounded, onTap: onShareGarden),
          const SizedBox(width: 6),
          // Weather
          _IconBtn(
            icon: weatherIcon,
            badge: hasEvent ? '!' : null,
            onTap: onWeather,
          ),
          const SizedBox(width: 6),
          // Profile / Login
          GestureDetector(
            onTap: onProfile,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.green[700],
              child: userInitial != null
                  ? Text(userInitial!,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold))
                  : const Icon(Icons.person_rounded,
                      color: Colors.white70, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinChip extends StatelessWidget {
  final int coins;
  final VoidCallback onTap;
  const _CoinChip({required this.coins, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.5))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('🪙', style: TextStyle(fontSize: 11)),
          const SizedBox(width: 3),
          Text('$coins',
              style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String? badge;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20)),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          if (badge != null)
            Positioned(
              right: -2, top: -2,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                    color: Colors.redAccent, shape: BoxShape.circle),
                child: Text(badge!,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// XP bar
// ─────────────────────────────────────────────────────────────────────────────

class _XPBar extends StatelessWidget {
  final int level, xp, nextXP, occupiedCount, plotCount;
  final double progress;
  final bool isMax;

  const _XPBar({
    required this.level,
    required this.xp,
    required this.progress,
    required this.nextXP,
    required this.isMax,
    required this.occupiedCount,
    required this.plotCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFFFB300), Color(0xFFFF6F00)]),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.4), blurRadius: 6)
              ],
            ),
            child: Text('Lv.$level',
                style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(GameLevels.titleFor(level),
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: Colors.white12,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isMax ? 'MAX' : '$xp / $nextXP XP',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
              Text(
                '🌿 $occupiedCount / $plotCount',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fence
// ─────────────────────────────────────────────────────────────────────────────

class _Fence extends StatelessWidget {
  const _Fence();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Row(
        children: List.generate(
          22,
          (i) => Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              decoration: BoxDecoration(
                  color: const Color(0xFF8D6E63),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plot card
// ─────────────────────────────────────────────────────────────────────────────

class _PlotCard extends StatelessWidget {
  final GardenPlot plot;
  final bool isSelected;
  final double animValue;
  final VoidCallback onTap;

  const _PlotCard({
    required this.plot,
    required this.isSelected,
    required this.animValue,
    required this.onTap,
  });

  static const _stageLabels = ['\uc528\uc557', '\uc0c8\uc2f9', '\ubaa8\uc885', '\uccad\ub144', '\ub9cc\uac1c \uD83C\uDF38'];
  static const Map<PlantRarity, Color> _rc = {
    PlantRarity.holographic: Color(0xFFCE93D8),
    PlantRarity.rare:        Color(0xFFFFAB91),
    PlantRarity.uncommon:    Color(0xFF80CBC4),
    PlantRarity.common:      Color(0xFFA5D6A7),
  };

  @override
  Widget build(BuildContext context) {
    final plant = plot.plant;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF6D4C41), Color(0xFF4E342E)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.greenAccent : const Color(0xFF3E2723),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? Colors.greenAccent.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.4),
              blurRadius: isSelected ? 12 : 5,
              spreadRadius: isSelected ? 2 : 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Column(
            children: [
              if (plant != null && plant.growthStage == 4)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  color: Colors.amber.withValues(alpha: 0.85),
                  child: const Text('\u2728 \uc218\ud655 \uac00\ub2a5',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.black87,
                          fontSize: 9,
                          fontWeight: FontWeight.bold)),
                ),
              Expanded(
                flex: 5,
                child: plant != null
                    ? CustomPaint(
                        painter: PlantPainter(
                            plant: plant, animValue: animValue),
                        size: Size.infinite)
                    : const _EmptyPlot(),
              ),
              if (plant != null)
                _PlotFooter(
                  plant: plant,
                  carePoints: plot.carePoints,
                  rarityColors: _rc,
                  stageLabels: _stageLabels,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPlot extends StatelessWidget {
  const _EmptyPlot();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 1.5)),
          child: const Icon(Icons.add, color: Colors.white38, size: 24),
        ),
        const SizedBox(height: 6),
        const Text('\ube48 \ud654\ub2e8', style: TextStyle(color: Colors.white30, fontSize: 11)),
        Text('\ud0ed\ud558\uc5ec \uc2ec\uae30',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.12), fontSize: 9)),
      ],
    );
  }
}

class _PlotFooter extends StatelessWidget {
  final Plant plant;
  final int carePoints;
  final Map<PlantRarity, Color> rarityColors;
  final List<String> stageLabels;

  const _PlotFooter({
    required this.plant,
    required this.carePoints,
    required this.rarityColors,
    required this.stageLabels,
  });

  @override
  Widget build(BuildContext context) {
    final rc = rarityColors[plant.rarity]!;
    final h = plant.hydration;
    final hc = h > 50 ? Colors.lightBlue : h > 25 ? Colors.orange : Colors.red;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 7),
      color: Colors.black.withValues(alpha: 0.45),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(plant.species,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (plant.isHybrid)
              const Text('\uD83E\uDDEC',
                  style: TextStyle(fontSize: 9)),
            const SizedBox(width: 3),
            Text(stageLabels[plant.growthStage],
                style: TextStyle(color: rc, fontSize: 9)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.water_drop, color: hc, size: 9),
            const SizedBox(width: 3),
            Expanded(child: _MiniBar(value: h / 100, color: hc)),
          ]),
          const SizedBox(height: 3),
          Row(children: [
            Icon(Icons.auto_awesome, color: Colors.amber.shade300, size: 9),
            const SizedBox(width: 3),
            Expanded(
                child: _MiniBar(
                    value: plant.growthStage < 4 ? carePoints / 100 : 1.0,
                    color: Colors.amber.shade300)),
          ]),
        ],
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  final double value;
  final Color color;
  const _MiniBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          minHeight: 4,
          backgroundColor: Colors.white12,
          color: color),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom panel
// ─────────────────────────────────────────────────────────────────────────────

class _BottomPanel extends StatelessWidget {
  final GardenPlot? selectedPlot;
  final void Function(String) onWater;
  final void Function(String) onBreed;
  final void Function(String) onHarvest;
  final void Function(String) onRemove;
  final Future<void> Function(GardenPlot) onShare;
  final void Function(String) onPlant;

  const _BottomPanel({
    required this.selectedPlot,
    required this.onWater,
    required this.onBreed,
    required this.onHarvest,
    required this.onRemove,
    required this.onShare,
    required this.onPlant,
  });

  static const _stageNames = ['\uc528\uc557', '\uc0c8\uc2f9', '\ubaa8\uc885', '\uccad\ub144', '\ub9cc\uac1c \uD83C\uDF38'];
  static const Map<PlantRarity, Color> _rc = {
    PlantRarity.holographic: Color(0xFFAB47BC),
    PlantRarity.rare:        Color(0xFFFF7043),
    PlantRarity.uncommon:    Color(0xFF26A69A),
    PlantRarity.common:      Color(0xFF66BB6A),
  };
  static const Map<PlantRarity, String> _rl = {
    PlantRarity.holographic: '\u2728 \ud640\ub85c\uadf8\ub798\ud53d',
    PlantRarity.rare:        '\u2b50 \ud76c\uadc0\uc885',
    PlantRarity.uncommon:    '\uD83C\uDF3F \ube44\ubc94\uc885',
    PlantRarity.common:      '\uD83C\uDF31 \uc77c\ubc18\uc885',
  };

  @override
  Widget build(BuildContext context) {
    final plot  = selectedPlot;
    final plant = plot?.plant;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, anim) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(anim),
        child: child,
      ),
      child: plot == null
          ? const SizedBox.shrink()
          : Container(
              key: ValueKey(plot.id + (plant?.id ?? '')),
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2E1A).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: plant != null
                      ? _rc[plant.rarity]!.withValues(alpha: 0.5)
                      : Colors.white12,
                  width: 1.5,
                ),
              ),
              child: plant != null
                  ? _OccupiedPanel(
                      plot: plot,
                      plant: plant,
                      rarityColors: _rc,
                      rarityLabels: _rl,
                      stageNames: _stageNames,
                      onWater: () => onWater(plot.id),
                      onBreed: plant.growthStage >= 2 ? () => onBreed(plot.id) : null,
                      onHarvest: plant.growthStage == 4 ? () => onHarvest(plot.id) : null,
                      onRemove: plant.growthStage < 4 ? () => onRemove(plot.id) : null,
                      onShare: () => onShare(plot),
                    )
                  : _EmptyPanel(onPlant: () => onPlant(plot.id)),
            ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final VoidCallback onPlant;
  const _EmptyPanel({required this.onPlant});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.grass, color: Colors.white38, size: 28),
        const SizedBox(width: 12),
        const Expanded(
          child: Text('\ube48 \ud654\ub2e8\uc785\ub2c8\ub2e4.\n\uc528\uc557\uc744 \uc2ec\uc5b4\ubcf4\uc138\uc694!',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
        ),
        ElevatedButton.icon(
          onPressed: onPlant,
          icon: const Icon(Icons.spa, size: 16),
          label: const Text('\uc528\uc557 \uc2ec\uae30'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[700],
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _OccupiedPanel extends StatelessWidget {
  final GardenPlot plot;
  final Plant plant;
  final Map<PlantRarity, Color> rarityColors;
  final Map<PlantRarity, String> rarityLabels;
  final List<String> stageNames;
  final VoidCallback onWater;
  final VoidCallback? onBreed;
  final VoidCallback? onHarvest;
  final VoidCallback? onRemove;
  final VoidCallback onShare;

  const _OccupiedPanel({
    required this.plot,
    required this.plant,
    required this.rarityColors,
    required this.rarityLabels,
    required this.stageNames,
    required this.onWater,
    required this.onBreed,
    required this.onHarvest,
    required this.onRemove,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final rc = rarityColors[plant.rarity]!;
    final h = plant.hydration;
    final hc = h > 50 ? Colors.lightBlue : h > 25 ? Colors.orange : Colors.red;
    final canHarvest = onHarvest != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(plant.species,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  if (plant.isHybrid) ...[
                    const SizedBox(width: 6),
                    const Text('\uD83E\uDDEC',
                        style: TextStyle(fontSize: 14)),
                  ],
                ]),
                Text('${stageNames[plant.growthStage]}  \u2022  \ud654\ub2e8 ${plot.index + 1}\ubc88',
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          if (canHarvest)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber),
              ),
              child: const Text('\uc218\ud655 \uac00\ub2a5',
                  style: TextStyle(color: Colors.amber, fontSize: 11)),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: rc.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: rc),
              ),
              child: Text(rarityLabels[plant.rarity]!,
                  style: TextStyle(color: rc, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
        ]),
        const SizedBox(height: 10),
        _PanelBar(icon: Icons.water_drop, color: hc, value: h / 100,
            label: '\uc218\ubd84 ${h.toInt()}%'),
        const SizedBox(height: 5),
        _PanelBar(
            icon: Icons.auto_awesome,
            color: Colors.amber,
            value: plant.growthStage < 4 ? plot.carePoints / 100 : 1.0,
            label: plant.growthStage < 4
                ? '\uc131\uc7a5 ${plot.carePoints}/100'
                : '\uD83C\uDF38 \ub9cc\uac1c \uc644\uc131!'),
        const SizedBox(height: 14),
        Row(children: [
          _PanelBtn(icon: Icons.water_drop_rounded, label: '\ubb3c\uc8fc\uae30',
              color: Colors.lightBlue, onTap: onWater),
          const SizedBox(width: 7),
          _PanelBtn(icon: Icons.join_full_rounded, label: '\uad50\ubc30',
              color: onBreed != null ? Colors.purple : Colors.grey,
              onTap: onBreed,
              sub: onBreed == null ? '${plant.growthStage}/2\ub2e8\uacc4' : null),
          const SizedBox(width: 7),
          _PanelBtn(icon: Icons.camera_alt_rounded, label: '\uacf5\uc720',
              color: Colors.teal, onTap: onShare),
          const SizedBox(width: 7),
          if (canHarvest)
            _PanelBtn(icon: Icons.agriculture_rounded, label: '\uc218\ud655',
                color: Colors.amber, onTap: onHarvest)
          else
            _PanelBtn(icon: Icons.delete_outline_rounded, label: '\uc81c\uac70',
                color: Colors.red.shade300, onTap: onRemove),
        ]),
      ],
    );
  }
}

class _PanelBar extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double value;
  final String label;
  const _PanelBar({required this.icon, required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 6),
      Expanded(
          child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                  value: value.clamp(0.0, 1.0),
                  minHeight: 7,
                  backgroundColor: Colors.white12,
                  color: color))),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
    ]);
  }
}

class _PanelBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final String? sub;
  const _PanelBtn({required this.icon, required this.label, required this.color, required this.onTap, this.sub});

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: on
                ? color.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: on ? color.withValues(alpha: 0.55) : Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: on ? color : Colors.white24, size: 20),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      color: on ? Colors.white : Colors.white24,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
              if (sub != null)
                Text(sub!,
                    style: const TextStyle(color: Colors.white30, fontSize: 8)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Seed picker sheet
// ─────────────────────────────────────────────────────────────────────────────

class _SeedPickerSheet extends StatelessWidget {
  final Map<String, int> inventory;
  final void Function(String species) onSelect;
  final VoidCallback onGoMiniGame;

  const _SeedPickerSheet({
    required this.inventory,
    required this.onSelect,
    required this.onGoMiniGame,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF1A2E1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('씨앗 보관함',
                  style: TextStyle(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: onGoMiniGame,
                icon: const Icon(Icons.sports_esports_rounded,
                    color: Colors.greenAccent, size: 16),
                label: const Text('씨앗 얻기',
                    style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(inventory.isEmpty ? '보관함이 비었어요! 미니게임으로 씨앗을 모아보세요.' : '씨앗을 탭해서 심어보세요',
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 16),
          if (inventory.isEmpty)
            _EmptyInventoryPrompt(onGoMiniGame: onGoMiniGame)
          else
            _InventoryGrid(inventory: inventory, onSelect: onSelect),
        ],
      ),
    );
  }
}

class _EmptyInventoryPrompt extends StatelessWidget {
  final VoidCallback onGoMiniGame;
  const _EmptyInventoryPrompt({required this.onGoMiniGame});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('🌱', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: onGoMiniGame,
          icon: const Icon(Icons.sports_esports_rounded),
          label: const Text('미니게임 하러가기'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[700],
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ],
    );
  }
}

class _InventoryGrid extends StatelessWidget {
  final Map<String, int> inventory;
  final void Function(String) onSelect;
  const _InventoryGrid({required this.inventory, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final entries = inventory.entries.toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final species = entries[i].key;
        final count   = entries[i].value;
        final info    = GameLevels.seeds.firstWhere(
          (s) => s.name == species,
          orElse: () => GameLevels.seeds.first,
        );
        return GestureDetector(
          onTap: () => onSelect(species),
          child: Container(
            decoration: BoxDecoration(
              color: info.hslColor.toColor().withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: info.hslColor.toColor().withValues(alpha: 0.55)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(info.emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(height: 4),
                Text(species,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('x$count',
                      style: const TextStyle(
                          color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
