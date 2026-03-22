import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game_level.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../viewmodels/garden_viewmodel.dart';

enum _CellType { empty, weed, flower }

class WeedGame extends ConsumerStatefulWidget {
  const WeedGame({super.key});

  @override
  ConsumerState<WeedGame> createState() => _WeedGameState();
}

class _WeedGameState extends ConsumerState<WeedGame> {
  static const _duration = 20;
  static const _cols = 3;
  static const _rows = 4;
  static const _cells = _cols * _rows;

  Timer? _countdown;
  Timer? _spawnTimer;

  int _score = 0;
  int _combo = 0;
  int _timeLeft = _duration;
  bool _started = false;
  bool _over = false;
  Map<String, int> _rewards = {};

  final _rng = Random();
  late List<_Cell> _grid;
  final List<_ScorePop> _pops = [];

  void _initGrid() {
    _grid = List.generate(_cells, (i) => _Cell());
  }

  void _start() {
    setState(() {
      _started = true;
      _over = false;
      _score = 0;
      _combo = 0;
      _timeLeft = _duration;
      _pops.clear();
      _spawnAcc = 0;
    });
    _initGrid();
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        // Age cells
        for (final c in _grid) {
          if (c.type != _CellType.empty) {
            c.age++;
            if (c.age >= c.maxAge) {
              if (c.type == _CellType.weed) _combo = 0; // miss weed
              c.reset();
            }
          }
        }
        _timeLeft--;
        if (_timeLeft <= 0) _end();
      });
    });
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      _trySpawn();
    });
  }

  double _spawnAcc = 0;

  // elapsed 0→20
  int get _elapsed => _duration - _timeLeft;

  // Spawn interval: 700ms → 300ms
  double get _spawnIntervalSec =>
      0.7 - (_elapsed / _duration) * 0.4;

  // Weed max age: 3 → 1 tick (3 before 7s, 2 before 14s, 1 after)
  int get _weedMaxAge =>
      _elapsed < 7 ? 3 : _elapsed < 14 ? 2 : 1;

  // Flower chance: 25% → 45%
  double get _flowerChance =>
      0.25 + (_elapsed / _duration) * 0.20;

  void _trySpawn() {
    _spawnAcc += 0.1; // 100ms tick
    if (_spawnAcc < _spawnIntervalSec) return;
    _spawnAcc = 0;
    _spawn();
  }

  void _spawn() {
    final empties = _grid.asMap().entries.where((e) => e.value.type == _CellType.empty).toList();
    if (empties.isEmpty) return;
    final idx = empties[_rng.nextInt(empties.length)].key;
    final isFlower = _rng.nextDouble() < _flowerChance;
    setState(() {
      _grid[idx].type = isFlower ? _CellType.flower : _CellType.weed;
      _grid[idx].age  = 0;
      _grid[idx].maxAge = isFlower ? 4 : _weedMaxAge;
    });
  }

  void _end() {
    _countdown?.cancel();
    _spawnTimer?.cancel();
    _rewards = _calcRewards();
    ref.read(gardenProvider.notifier).addSeedsToInventory(_rewards);
    _submitScore('weed', _score.clamp(0, 9999));
    setState(() => _over = true);
  }

  void _submitScore(String gameType, int score) {
    final user = ref.read(authProvider);
    if (user == null) return;
    FirestoreService.submitScore(
        user.uid, user.displayName, user.photoUrl, gameType, score);
  }

  Map<String, int> _calcRewards() {
    if (_score <= 0) return {};
    final level = ref.read(gardenProvider).playerLevel;
    final count = _score >= 25 ? 3 : _score >= 15 ? 2 : _score >= 5 ? 1 : 0;
    if (count == 0) return {};
    final pool  = GameLevels.seeds.where((s) => s.unlockLevel <= level).toList();
    if (pool.isEmpty) return {};
    final result = <String, int>{};
    for (int i = 0; i < count; i++) {
      final s = pool[_rng.nextInt(pool.length)].name;
      result[s] = (result[s] ?? 0) + 1;
    }
    return result;
  }

  void _onTap(int idx) {
    if (!_started || _over) return;
    final cell = _grid[idx];
    setState(() {
      if (cell.type == _CellType.weed) {
        _combo++;
        final points = _combo >= 3 ? 3 : 2;
        _score += points;
        _pops.add(_ScorePop(idx: idx, text: _combo >= 3 ? '+$points 콤보!' : '+$points'));
        cell.reset();
      } else if (cell.type == _CellType.flower) {
        _score = (_score - 2).clamp(0, 9999);
        _combo = 0;
        _pops.add(_ScorePop(idx: idx, text: '-2 꽃!'));
        cell.reset();
      }
      // Remove old pops
      _pops.removeWhere((p) => p.age > 12);
      for (final p in _pops) { p.age++; }
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _spawnTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF142814),
      appBar: AppBar(
        backgroundColor: const Color(0xFF142814),
        foregroundColor: Colors.white,
        title: const Text('🌿 잡초뽑기'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Stack(children: [
          // Main content
          if (_started && !_over)
            Column(children: [
              // HUD
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _HudPill('🌿 $_score 점'),
                    _HudPill('⏱ $_timeLeft 초', urgent: _timeLeft <= 5),
                    _HudPill(_combo >= 3 ? '🔥 $_combo 콤보!' : '콤보 $_combo'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('잡초🌿 탭!', style: TextStyle(color: Colors.lightGreen, fontSize: 12)),
                    SizedBox(width: 16),
                    Text('꽃🌸 조심!', style: TextStyle(color: Colors.pinkAccent, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _cols,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemCount: _cells,
                    itemBuilder: (_, i) {
                      final pop = _pops.where((p) => p.idx == i).lastOrNull;
                      return Stack(children: [
                        _CellWidget(
                          cell: _grid[i],
                          onTap: () => _onTap(i),
                        ),
                        if (pop != null)
                          Positioned(
                            top: 0, left: 0, right: 0,
                            child: Opacity(
                              opacity: (1 - pop.age / 12).clamp(0.0, 1.0),
                              child: Text(pop.text,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: pop.text.startsWith('+') ? Colors.lime : Colors.redAccent,
                                      fontSize: 14, fontWeight: FontWeight.bold,
                                      shadows: const [Shadow(color: Colors.black, blurRadius: 4)])),
                            ),
                          ),
                      ]);
                    },
                  ),
                ),
              ),
            ]),
          // Start / Over overlays
          if (!_started) _StartOverlay(onStart: _start),
          if (_over) _WeedResultOverlay(
            score: _score,
            rewards: _rewards,
            onRetry: _start,
            onBack: () => Navigator.pop(context),
          ),
        ]),
      ),
    );
  }
}

class _Cell {
  _CellType type = _CellType.empty;
  int age = 0;
  int maxAge = 3;
  void reset() { type = _CellType.empty; age = 0; }
}

class _ScorePop { int idx; String text; int age; _ScorePop({required this.idx, required this.text}) : age = 0; }

class _CellWidget extends StatelessWidget {
  final _Cell cell;
  final VoidCallback onTap;
  const _CellWidget({required this.cell, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color bg;
    String emoji;
    Color border;

    switch (cell.type) {
      case _CellType.weed:
        bg = const Color(0xFF1A3A10);
        emoji = '🌿';
        border = Colors.lightGreen;
      case _CellType.flower:
        bg = const Color(0xFF3A1A2A);
        emoji = '🌸';
        border = Colors.pinkAccent;
      case _CellType.empty:
        bg = const Color(0xFF2A1E0A);
        emoji = '';
        border = const Color(0xFF3E2C10);
    }

    // Urgency animation: flicker when about to expire
    final urgent = cell.type != _CellType.empty && cell.age >= cell.maxAge - 1;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: urgent ? Colors.yellow : border, width: urgent ? 2.5 : 1.5),
          boxShadow: cell.type != _CellType.empty
              ? [BoxShadow(color: border.withValues(alpha: 0.35), blurRadius: 8, spreadRadius: 1)]
              : null,
        ),
        child: Center(
          child: AnimatedScale(
            scale: cell.type != _CellType.empty ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.elasticOut,
            child: Text(emoji, style: const TextStyle(fontSize: 40)),
          ),
        ),
      ),
    );
  }
}

class _HudPill extends StatelessWidget {
  final String label;
  final bool urgent;
  const _HudPill(this.label, {this.urgent = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: urgent ? Border.all(color: Colors.red) : null,
      ),
      child: Text(label,
          style: TextStyle(color: urgent ? Colors.red : Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }
}

class _StartOverlay extends StatelessWidget {
  final VoidCallback onStart;
  const _StartOverlay({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🌿', style: TextStyle(fontSize: 72)),
          const SizedBox(height: 16),
          const Text('잡초뽑기', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('잡초🌿만 탭하세요!\n꽃🌸를 뽑으면 -2점 패널티',
              style: TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text('3연속 콤보 시 보너스!',
              style: TextStyle(color: Colors.amber, fontSize: 13)),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: onStart,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              minimumSize: const Size(160, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            ),
            child: const Text('시작!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }
}

class _WeedResultOverlay extends StatelessWidget {
  final int score;
  final Map<String, int> rewards;
  final VoidCallback onRetry, onBack;
  const _WeedResultOverlay({required this.score, required this.rewards, required this.onRetry, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.82),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF142814),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🎉 결과!',
                style: TextStyle(color: Colors.greenAccent, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('점수: $score점', style: const TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 16),
            if (rewards.isEmpty)
              const Text('씨앗을 얻지 못했어요 😢', style: TextStyle(color: Colors.white54))
            else ...[
              const Text('획득한 씨앗 🌱', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              ...rewards.entries.map((e) {
                final info = GameLevels.seeds.where((s) => s.name == e.key).firstOrNull;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('${info?.emoji ?? "🌱"} ${e.key}  x${e.value}',
                      style: const TextStyle(color: Colors.amber, fontSize: 15, fontWeight: FontWeight.bold)),
                );
              }),
            ],
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              OutlinedButton(
                onPressed: onBack,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white54),
                child: const Text('돌아가기'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700], foregroundColor: Colors.white),
                child: const Text('다시 하기'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
