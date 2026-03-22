import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game_level.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../viewmodels/garden_viewmodel.dart';

class TapGame extends ConsumerStatefulWidget {
  const TapGame({super.key});

  @override
  ConsumerState<TapGame> createState() => _TapGameState();
}

class _TapGameState extends ConsumerState<TapGame>
    with TickerProviderStateMixin {
  static const _gameDuration = 30;

  late final AnimationController _loopCtrl;
  late final AnimationController _btnCtrl;
  Timer? _countdown;

  int _timeLeft = _gameDuration;
  bool _started = false;
  bool _over = false;
  double _gauge = 0.0; // 0.0 – 100.0
  int _seedsEarned = 0;
  Map<String, int> _rewards = {};

  final _rng = Random();

  // elapsed seconds (0→30)
  int get _elapsed => _gameDuration - _timeLeft;

  // Fill per tap: 5% at start → 2% at end
  double get _fillRate =>
      5.0 - (_elapsed / _gameDuration) * 3.0;

  // Decay per second: 2%/s at start → 14%/s at end
  double get _decayPerSec =>
      2.0 + (_elapsed / _gameDuration) * 12.0;

  // Stage 0=준비 1=집중! 2=전력!
  int get _stage => _elapsed < 10 ? 0 : _elapsed < 20 ? 1 : 2;

  static const _stageLabels = ['준비', '집중!', '전력!'];
  static const _stageColors = [
    Colors.greenAccent,
    Colors.orange,
    Colors.redAccent,
  ];

  @override
  void initState() {
    super.initState();
    _loopCtrl =
        AnimationController(vsync: this, duration: const Duration(minutes: 10))
          ..addListener(_frame);
    _btnCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
  }

  void _start() {
    setState(() {
      _started = true;
      _over = false;
      _timeLeft = _gameDuration;
      _gauge = 0.0;
      _seedsEarned = 0;
    });
    _loopCtrl.repeat();
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _timeLeft--;
        if (_timeLeft <= 0) _end();
      });
    });
  }

  double _lastT = 0;
  void _frame() {
    if (!_started || _over) return;
    final t = _loopCtrl.value;
    final dt = t - _lastT;
    _lastT = t;
    if (dt <= 0) return;

    setState(() {
      // Convert controller fraction to seconds (10-min controller → 1/600 per frame ≈ 0.0167s at 60fps)
      final dtSec = dt * 600.0;
      _gauge = (_gauge - _decayPerSec * dtSec).clamp(0.0, 100.0);
    });
  }

  void _onTap() {
    if (!_started || _over) return;
    HapticFeedback.lightImpact();
    _btnCtrl.forward(from: 0);
    setState(() {
      _gauge = (_gauge + _fillRate).clamp(0.0, 100.0);
      if (_gauge >= 100.0) {
        _gauge = 0.0;
        _seedsEarned++;
      }
    });
  }

  void _end() {
    _countdown?.cancel();
    _loopCtrl.stop();
    _rewards = _calcRewards();
    ref.read(gardenProvider.notifier).addSeedsToInventory(_rewards);
    _submitScore('tap', _seedsEarned * 100);
    setState(() => _over = true);
  }

  void _submitScore(String gameType, int score) {
    final user = ref.read(authProvider);
    if (user == null) return;
    FirestoreService.submitScore(
        user.uid, user.displayName, user.photoUrl, gameType, score);
  }

  Map<String, int> _calcRewards() {
    final count = _seedsEarned.clamp(0, 3);
    if (count == 0) return {};
    final level = ref.read(gardenProvider).playerLevel;
    final pool =
        GameLevels.seeds.where((s) => s.unlockLevel <= level).toList();
    if (pool.isEmpty) return {};
    final result = <String, int>{};
    for (int i = 0; i < count; i++) {
      final s = pool[_rng.nextInt(pool.length)].name;
      result[s] = (result[s] ?? 0) + 1;
    }
    return result;
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _loopCtrl.dispose();
    _btnCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A2C0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2C0A),
        foregroundColor: Colors.white,
        title: const Text('🌱 땅파기'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Stack(children: [
          if (_started && !_over) _buildGameUI(),
          if (!_started) _StartScreen(onStart: _start),
          if (_over)
            _ResultScreen(
              seedsEarned: _seedsEarned,
              rewards: _rewards,
              onRetry: _start,
              onBack: () => Navigator.pop(context),
            ),
        ]),
      ),
    );
  }

  Widget _buildGameUI() {
    final stageColor = _stageColors[_stage];
    final stageLabel = _stageLabels[_stage];
    final urgent = _timeLeft <= 5;

    return Column(children: [
      // ── HUD ──
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _HudPill('🌱 $_seedsEarned 개'),
            _HudPill('⏱ $_timeLeft 초', urgent: urgent),
            _HudPill(stageLabel, color: stageColor),
          ],
        ),
      ),
      const SizedBox(height: 8),
      // ── Main area: button + gauge ──
      Expanded(
        child: Row(children: [
          // Grass button area
          Expanded(
            child: Center(
              child: AnimatedBuilder(
                animation: _btnCtrl,
                builder: (_, child) {
                  final scale =
                      1.0 - _btnCtrl.value * 0.12;
                  return GestureDetector(
                    onTap: _onTap,
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              stageColor.withValues(alpha: 0.3),
                              const Color(0xFF2A4A10),
                            ],
                          ),
                          border: Border.all(
                              color: stageColor, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: stageColor.withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('🌿',
                              style: TextStyle(fontSize: 72)),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Gauge bar
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: _GaugeBar(
              fillPct: _gauge / 100.0,
              seedsEarned: _seedsEarned,
              stageColor: stageColor,
            ),
          ),
        ]),
      ),
      // Hint text
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          '🌿 탭하면 게이지가 채워져요!  게이지 가득 = 씨앗 1개',
          style: TextStyle(color: Colors.white38, fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ),
    ]);
  }
}

// ── Gauge Bar ──────────────────────────────────────────────────────────────────

class _GaugeBar extends StatelessWidget {
  final double fillPct; // 0.0–1.0
  final int seedsEarned;
  final Color stageColor;

  const _GaugeBar({
    required this.fillPct,
    required this.seedsEarned,
    required this.stageColor,
  });

  @override
  Widget build(BuildContext context) {
    const barH = 280.0;
    const barW = 48.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$seedsEarned 🌱',
            style: const TextStyle(
                color: Colors.amber,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Container(
          width: barW,
          height: barH,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: stageColor.withValues(alpha: 0.6)),
          ),
          child: Stack(alignment: Alignment.bottomCenter, children: [
            // Fill
            AnimatedContainer(
              duration: const Duration(milliseconds: 50),
              width: barW,
              height: barH * fillPct,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    stageColor.withValues(alpha: 0.9),
                    stageColor.withValues(alpha: 0.5),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            // Tick marks at 25%, 50%, 75%
            for (final pct in [0.25, 0.5, 0.75])
              Positioned(
                bottom: barH * pct - 1,
                left: 0,
                right: 0,
                child: Container(
                  height: 1.5,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
            // Percentage text
            Center(
              child: Text(
                '${(fillPct * 100).toInt()}%',
                style: TextStyle(
                  color: fillPct > 0.5 ? Colors.black87 : Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

// ── HUD Pill ───────────────────────────────────────────────────────────────────

class _HudPill extends StatelessWidget {
  final String label;
  final bool urgent;
  final Color? color;
  const _HudPill(this.label, {this.urgent = false, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? (urgent ? Colors.red : Colors.white);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: urgent ? Border.all(color: Colors.red) : null,
      ),
      child: Text(label,
          style: TextStyle(
              color: c,
              fontSize: 13,
              fontWeight: FontWeight.bold)),
    );
  }
}

// ── Start Screen ───────────────────────────────────────────────────────────────

class _StartScreen extends StatelessWidget {
  final VoidCallback onStart;
  const _StartScreen({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🌿', style: TextStyle(fontSize: 72)),
          const SizedBox(height: 16),
          const Text('땅파기',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            '잔디 버튼을 빠르게 탭해서\n게이지를 가득 채우세요!\n가득 채울 때마다 씨앗 1개 획득',
            style: TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text('시간이 지날수록 게이지가 빨리 줄어요!',
              style: TextStyle(color: Colors.amber, fontSize: 13)),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: onStart,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              minimumSize: const Size(160, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25)),
            ),
            child: const Text('시작!',
                style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }
}

// ── Result Screen ──────────────────────────────────────────────────────────────

class _ResultScreen extends StatelessWidget {
  final int seedsEarned;
  final Map<String, int> rewards;
  final VoidCallback onRetry, onBack;
  const _ResultScreen({
    required this.seedsEarned,
    required this.rewards,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.82),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2E1A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: Colors.greenAccent.withValues(alpha: 0.4)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🎉 결과!',
                style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('게이지 채우기: $seedsEarned 회',
                style:
                    const TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 16),
            if (rewards.isEmpty)
              const Text('씨앗을 얻지 못했어요 😢',
                  style: TextStyle(color: Colors.white54))
            else ...[
              const Text('획득한 씨앗 🌱',
                  style:
                      TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              ...rewards.entries.map((e) {
                final info = GameLevels.seeds
                    .where((s) => s.name == e.key)
                    .firstOrNull;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                      '${info?.emoji ?? "🌱"} ${e.key}  x${e.value}',
                      style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                );
              }),
            ],
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              OutlinedButton(
                onPressed: onBack,
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54),
                child: const Text('돌아가기'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white),
                child: const Text('다시 하기'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
