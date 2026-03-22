import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game_level.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../viewmodels/garden_viewmodel.dart';
import 'game_widgets.dart';

class DodgeGame extends ConsumerStatefulWidget {
  const DodgeGame({super.key});

  @override
  ConsumerState<DodgeGame> createState() => _DodgeGameState();
}

class _DodgeGameState extends ConsumerState<DodgeGame>
    with SingleTickerProviderStateMixin {
  static const _duration = 30;
  static const _playerSpeed = 240.0;
  static const _maxLives = 3;
  static const _hitRadius = 32.0;
  static const _invincibleDur = 1.5; // seconds after getting hit

  late final AnimationController _ctrl;
  Timer? _countdown;

  int _timeLeft = _duration;
  int _lives = _maxLives;
  int _dodged = 0;
  bool _started = false;
  bool _over = false;
  double _invincible = 0; // countdown seconds
  double _spawnAcc = 0;   // spawn accumulator
  Map<String, int> _rewards = {};
  Offset _joyDir = Offset.zero;

  final _rng = Random();
  Size _size = const Size(400, 700);
  _PlayerEnt? _player;
  final List<_BeeEnt> _bees = [];
  DateTime? _lastFrame;

  double get _gameAreaH => _size.height - 180;

  // elapsed 0→30
  int get _elapsed => _duration - _timeLeft;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(minutes: 10))
      ..addListener(_frame)
      ..repeat();
  }

  void _start() {
    _bees.clear();
    setState(() {
      _started = true;
      _over = false;
      _lives = _maxLives;
      _dodged = 0;
      _timeLeft = _duration;
      _invincible = 0;
    });
    _spawnAcc = 0;
    _player = _PlayerEnt(pos: Offset(_size.width / 2, _gameAreaH * 0.5));
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _timeLeft--;
        if (_timeLeft <= 0) _end(survived: true);
      });
    });
  }

  void _spawnBeeInner(Offset playerPos) {
    // Spawn from a random edge
    final edge = _rng.nextInt(4); // 0=top 1=right 2=bottom 3=left
    Offset pos;
    switch (edge) {
      case 0:  pos = Offset(_rng.nextDouble() * _size.width, -20); break;
      case 1:  pos = Offset(_size.width + 20, _rng.nextDouble() * _gameAreaH); break;
      case 2:  pos = Offset(_rng.nextDouble() * _size.width, _gameAreaH + 20); break;
      default: pos = Offset(-20, _rng.nextDouble() * _gameAreaH);
    }
    // Speed increases over time
    final speed = 100.0 + _elapsed * 5.0 + _rng.nextDouble() * 50;
    _bees.add(_BeeEnt(pos: pos, speed: speed));
  }

  void _frame() {
    if (!_started || _over) return;
    final now = DateTime.now();
    final rawDt = _lastFrame != null
        ? now.difference(_lastFrame!).inMilliseconds / 1000.0
        : 1 / 60.0;
    _lastFrame = now;
    final dt = rawDt.clamp(0.0, 0.05);

    setState(() {
      final p = _player!;

      // Move player
      if (_joyDir != Offset.zero) {
        p.pos = _clampPlayer(p.pos + _joyDir * _playerSpeed * dt);
      }

      // Invincibility countdown
      if (_invincible > 0) _invincible -= dt;

      // Spawn bees via accumulator (2.0s → 0.6s interval over 30s)
      final spawnInterval = (2.0 - _elapsed * 0.046).clamp(0.6, 2.0);
      _spawnAcc += dt;
      while (_spawnAcc >= spawnInterval) {
        _spawnAcc -= spawnInterval;
        _spawnBeeInner(p.pos);
      }

      // Move bees toward player
      for (final bee in _bees) {
        final toPlayer = p.pos - bee.pos;
        final dist = toPlayer.distance;
        if (dist > 0) {
          bee.pos += (toPlayer / dist) * bee.speed * dt;
        }

        // Hit check
        if (_invincible <= 0 && dist < _hitRadius) {
          _lives--;
          _invincible = _invincibleDur;
          HapticFeedback.mediumImpact();
          if (_lives <= 0) {
            _end(survived: false);
            return;
          }
          bee.pos = Offset( // push bee away after hit
            _rng.nextDouble() * _size.width,
            _rng.nextDouble() < 0.5 ? -30 : _gameAreaH + 30,
          );
        }
      }

      // Remove bees that went far past the player (counted as dodged)
      _bees.removeWhere((bee) {
        final offscreen = bee.pos.dx < -60 || bee.pos.dx > _size.width + 60 ||
            bee.pos.dy < -60 || bee.pos.dy > _gameAreaH + 60;
        if (offscreen) _dodged++;
        return offscreen;
      });
    });
  }

  Offset _clampPlayer(Offset p) => Offset(
        p.dx.clamp(22.0, _size.width - 22.0),
        p.dy.clamp(22.0, _gameAreaH - 22.0),
      );

  void _end({required bool survived}) {
    _countdown?.cancel();
    final survivalTime = _duration - _timeLeft;
    _rewards = _calcRewards(survived, survivalTime);
    ref.read(gardenProvider.notifier).addSeedsToInventory(_rewards);
    _submitScore('dodge', survivalTime * 3 + _dodged * 5);
    setState(() => _over = true);
  }

  void _submitScore(String gameType, int score) {
    final user = ref.read(authProvider);
    if (user == null) return;
    FirestoreService.submitScore(
        user.uid, user.displayName, user.photoUrl, gameType, score);
  }

  Map<String, int> _calcRewards(bool survived, int survivalTime) {
    final count = survived ? 3 : survivalTime >= 20 ? 2 : survivalTime >= 10 ? 1 : 0;
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
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1400),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1400),
        foregroundColor: Colors.white,
        title: const Text('🐝 벌 피하기'),
        elevation: 0,
      ),
      body: LayoutBuilder(builder: (ctx, box) {
        _size = Size(box.maxWidth, box.maxHeight);
        return Stack(children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A1400), Color(0xFF2A2000)],
              ),
            ),
          ),

          if (_started && !_over) ...[
            // Game area border
            Positioned(
              left: 0, right: 0, top: _gameAreaH,
              child: Container(height: 1.5, color: Colors.white12),
            ),

            // Bees
            for (final bee in _bees)
              Positioned(
                left: bee.pos.dx - 18,
                top: bee.pos.dy - 18,
                child: const Text('🐝', style: TextStyle(fontSize: 30)),
              ),

            // Player (flash when invincible)
            if (_player != null)
              Positioned(
                left: _player!.pos.dx - 22,
                top: _player!.pos.dy - 22,
                child: Opacity(
                  opacity: _invincible > 0
                      ? ((_invincible * 6).toInt().isEven ? 0.3 : 1.0)
                      : 1.0,
                  child: const Text('🧑‍🌾',
                      style: TextStyle(fontSize: 36)),
                ),
              ),

            // HUD
            Positioned(
              top: 8, left: 16, right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GameHudPill(
                    List.generate(_maxLives, (i) => i < _lives ? '❤️' : '🖤').join(),
                  ),
                  GameHudPill('⏱ $_timeLeft 초',
                      urgent: _timeLeft <= 5),
                  GameHudPill('✅ $_dodged'),
                ],
              ),
            ),

            // Joystick
            Positioned(
              bottom: 24,
              left: 0, right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('조이스틱',
                      style: TextStyle(color: Colors.white24, fontSize: 11)),
                  const SizedBox(height: 4),
                  GameJoystick(
                    onChanged: (dir) => setState(() => _joyDir = dir),
                  ),
                ],
              ),
            ),
          ],

          if (!_started)
            GameStartOverlay(
              emoji: '🐝',
              title: '벌 피하기',
              desc: '조이스틱으로 이동해서\n날아오는 벌을 피하세요!',
              hint: '❤️ 3번 맞으면 게임오버  |  30초 생존하면 보너스',
              accentColor: Colors.amber,
              onStart: _start,
            ),

          if (_over)
            GameResultOverlay(
              scoreText: _lives > 0
                  ? '🎉 생존 성공!  회피: $_dodged 회'
                  : '💀 게임오버  생존: ${_duration - _timeLeft}초',
              rewards: _rewards,
              accentColor: Colors.amber,
              onRetry: _start,
              onBack: () => Navigator.pop(context),
            ),
        ]);
      }),
    );
  }
}

class _PlayerEnt {
  Offset pos;
  _PlayerEnt({required this.pos});
}

class _BeeEnt {
  Offset pos;
  double speed;
  _BeeEnt({required this.pos, required this.speed});
}
