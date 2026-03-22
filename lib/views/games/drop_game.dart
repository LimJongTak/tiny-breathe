import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game_level.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../viewmodels/garden_viewmodel.dart';

class DropGame extends ConsumerStatefulWidget {
  const DropGame({super.key});

  @override
  ConsumerState<DropGame> createState() => _DropGameState();
}

class _DropGameState extends ConsumerState<DropGame>
    with SingleTickerProviderStateMixin {
  static const _duration = 20;
  static const _catchRadius = 42.0;

  late final AnimationController _ctrl;
  Timer? _countdown;
  Timer? _spawnTimer;

  int _caught = 0;
  int _missed = 0;
  int _timeLeft = _duration;
  bool _started = false;
  bool _over = false;
  Map<String, int> _rewards = {};

  final _rng = Random();
  Size _size = const Size(400, 700);
  final List<_Drop> _drops = [];
  final List<_Splash> _splashes = [];
  double _spawnInterval = 1.4; // seconds (speeds up over time)
  double _spawnAcc = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(minutes: 2))
      ..addListener(_frame);
  }

  void _start() {
    setState(() {
      _started = true;
      _over = false;
      _caught = 0;
      _missed = 0;
      _timeLeft = _duration;
      _drops.clear();
      _splashes.clear();
      _spawnInterval = 1.4;
      _spawnAcc = 0;
    });
    _ctrl.repeat();
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _timeLeft--;
        // Spawn interval: 0.9s → 0.25s over 20 seconds
        final elapsed = _duration - _timeLeft;
        _spawnInterval = (0.9 - elapsed * 0.0325).clamp(0.25, 0.9);
        if (_timeLeft <= 0) _end();
      });
    });
  }

  void _end() {
    _countdown?.cancel();
    _spawnTimer?.cancel();
    _ctrl.stop();
    _rewards = _calcRewards();
    ref.read(gardenProvider.notifier).addSeedsToInventory(_rewards);
    _submitScore('drop', _caught);
    setState(() => _over = true);
  }

  void _submitScore(String gameType, int score) {
    final user = ref.read(authProvider);
    if (user == null) return;
    FirestoreService.submitScore(
        user.uid, user.displayName, user.photoUrl, gameType, score);
  }

  Map<String, int> _calcRewards() {
    final total = _caught + _missed;
    if (total == 0) return {};
    final ratio = _caught / total;
    final level = ref.read(gardenProvider).playerLevel;
    final count = ratio >= 0.85 ? 3 : ratio >= 0.65 ? 2 : ratio >= 0.40 ? 1 : 0;
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

  void _frame() {
    if (!_started || _over) return;
    const dt = 1 / 60;
    setState(() {
      // Spawn drops
      _spawnAcc += dt;
      if (_spawnAcc >= _spawnInterval) {
        _spawnAcc = 0;
        final elapsed = _duration - _timeLeft;
        final baseSpeed = 220.0 + elapsed * 16.0; // 220→540 px/s
        _drops.add(_Drop(
          x: _rng.nextDouble() * (_size.width - 60) + 30,
          speed: baseSpeed + _rng.nextDouble() * 80,
        ));
      }
      // Move drops
      for (final d in _drops) {
        if (!d.caught) d.y += d.speed * dt;
      }
      // Catch animation
      for (final d in _drops) {
        if (d.caught) d.fadeT += dt * 3;
      }
      // Miss detection
      final missed = _drops.where((d) => !d.caught && d.y > _size.height + 30).toList();
      if (missed.isNotEmpty) {
        _missed += missed.length;
        for (final d in missed) {
          _splashes.add(_Splash(x: d.x, y: _size.height - 10));
        }
      }
      _drops.removeWhere((d) => (!d.caught && d.y > _size.height + 30) || (d.caught && d.fadeT >= 1));
      // Update splashes
      for (final s in _splashes) { s.t += dt * 2; }
      _splashes.removeWhere((s) => s.t >= 1.0);
    });
  }

  void _onTap(TapDownDetails d) {
    if (!_started || _over) return;
    final pos = d.localPosition;
    for (final drop in _drops) {
      if (!drop.caught && (pos - Offset(drop.x, drop.y)).distance <= _catchRadius) {
        drop.caught = true;
        drop.fadeT  = 0;
        setState(() => _caught++);
        break;
      }
    }
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _spawnTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        foregroundColor: Colors.white,
        title: const Text('💧 물방울 잡기'),
        elevation: 0,
      ),
      body: LayoutBuilder(builder: (ctx, box) {
        _size = Size(box.maxWidth, box.maxHeight);
        return GestureDetector(
          onTapDown: _onTap,
          child: Stack(children: [
            // Background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0A1628), Color(0xFF1A3A2A)],
                ),
              ),
            ),
            // Drops
            for (final d in _drops)
              Positioned(
                left: d.x - 20,
                top: d.y - 30,
                child: d.caught
                    ? Opacity(
                        opacity: (1 - d.fadeT).clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 1 + d.fadeT,
                          child: const Text('✨', style: TextStyle(fontSize: 32)),
                        ),
                      )
                    : const _DropWidget(),
              ),
            // Splashes
            for (final s in _splashes)
              Positioned(
                left: s.x - 24,
                top: s.y - 12,
                child: Opacity(
                  opacity: (1 - s.t).clamp(0.0, 1.0),
                  child: const Text('💦', style: TextStyle(fontSize: 20)),
                ),
              ),
            // HUD
            if (_started && !_over)
              Positioned(
                top: 12, left: 0, right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _HudChip(label: '✅ $_caught 잡음'),
                    _HudChip(label: '⏱ $_timeLeft 초', urgent: _timeLeft <= 5),
                    _HudChip(label: '❌ $_missed 놓침'),
                  ],
                ),
              ),
            if (!_started) _StartScreen(
              title: '💧 물방울 잡기',
              desc: '20초 동안 하늘에서 떨어지는\n물방울을 탭해서 잡으세요!',
              onStart: _start,
            ),
            if (_over) _ResultScreen(
              title: '잡은 물방울: $_caught / ${_caught + _missed}',
              rewards: _rewards,
              onRetry: _start,
              onBack: () => Navigator.pop(context),
            ),
          ]),
        );
      }),
    );
  }
}

class _Drop {
  double x, y, speed;
  bool caught;
  double fadeT;
  _Drop({required this.x, required this.speed}) : y = -30, caught = false, fadeT = 0;
}

class _Splash { double x, y, t; _Splash({required this.x, required this.y}) : t = 0; }

class _DropWidget extends StatelessWidget {
  const _DropWidget();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DropPainter(), size: const Size(40, 60));
  }
}

class _DropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF80D4FF), Color(0xFF1A8FD1)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..quadraticBezierTo(size.width, size.height * 0.6, size.width / 2, size.height)
      ..quadraticBezierTo(0, size.height * 0.6, size.width / 2, 0);
    canvas.drawPath(path, paint);

    // Highlight
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.width * 0.35, size.height * 0.35), width: 8, height: 12),
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _HudChip extends StatelessWidget {
  final String label;
  final bool urgent;
  const _HudChip({required this.label, this.urgent = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: urgent ? Border.all(color: Colors.red) : null,
      ),
      child: Text(label,
          style: TextStyle(
              color: urgent ? Colors.red : Colors.white,
              fontSize: 14, fontWeight: FontWeight.bold)),
    );
  }
}

class _StartScreen extends StatelessWidget {
  final String title, desc;
  final VoidCallback onStart;
  const _StartScreen({required this.title, required this.desc, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title.split(' ').first, style: const TextStyle(fontSize: 72)),
          const SizedBox(height: 16),
          Text(title.split(' ').skip(1).join(' '),
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(desc,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: onStart,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
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

class _ResultScreen extends StatelessWidget {
  final String title;
  final Map<String, int> rewards;
  final VoidCallback onRetry, onBack;
  const _ResultScreen({required this.title, required this.rewards, required this.onRetry, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.82),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1B2E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🎉 결과!',
                style: TextStyle(color: Colors.lightBlue, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 16),
            if (rewards.isEmpty)
              const Text('씨앗을 얻지 못했어요 😢', style: TextStyle(color: Colors.white54))
            else ...[
              const Text('획득한 씨앗 🌱',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
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
                    backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
                child: const Text('다시 하기'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
