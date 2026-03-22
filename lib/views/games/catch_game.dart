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

class CatchGame extends ConsumerStatefulWidget {
  const CatchGame({super.key});

  @override
  ConsumerState<CatchGame> createState() => _CatchGameState();
}

class _CatchGameState extends ConsumerState<CatchGame>
    with SingleTickerProviderStateMixin {
  static const _duration = 30;
  static const _playerSpeed = 230.0;
  static const _catchRadius = 44.0;
  static const _bugCount = 6;
  static const _bugEmojis = ['🦟', '🪲', '🐛', '🦗', '🪳'];

  late final AnimationController _ctrl;
  Timer? _countdown;

  int _score = 0;
  int _timeLeft = _duration;
  bool _started = false;
  bool _over = false;
  Map<String, int> _rewards = {};
  Offset _joyDir = Offset.zero;

  final _rng = Random();
  Size _size = const Size(400, 700);
  _PlayerEnt? _player;
  late List<_BugEnt> _bugs;
  DateTime? _lastFrame;

  double get _gameAreaH => _size.height - 180; // reserve bottom for joystick

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(minutes: 10))
      ..addListener(_frame)
      ..repeat();
  }

  void _initEntities() {
    _player = _PlayerEnt(
        pos: Offset(_size.width / 2, _gameAreaH * 0.5));
    _bugs = List.generate(_bugCount, (_) => _makeBug(80));
  }

  _BugEnt _makeBug(double baseSpeed) {
    return _BugEnt(
      pos: Offset(
        _rng.nextDouble() * (_size.width - 80) + 40,
        _rng.nextDouble() * (_gameAreaH - 80) + 40,
      ),
      vel: _randomVel(baseSpeed),
      emoji: _bugEmojis[_rng.nextInt(_bugEmojis.length)],
    );
  }

  Offset _randomVel(double speed) {
    final a = _rng.nextDouble() * 2 * pi;
    return Offset(cos(a), sin(a)) * speed;
  }

  void _start() {
    setState(() {
      _started = true;
      _over = false;
      _score = 0;
      _timeLeft = _duration;
    });
    _initEntities();
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _timeLeft--;
        if (_timeLeft <= 0) _end();
      });
    });
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

      // Elapsed for progressive difficulty
      final elapsed = _duration - _timeLeft;

      for (final bug in _bugs) {
        bug.pos += bug.vel * dt;

        // Bounce walls
        if (bug.pos.dx < 20 || bug.pos.dx > _size.width - 20) {
          bug.vel = Offset(-bug.vel.dx, bug.vel.dy);
          bug.pos = Offset(bug.pos.dx.clamp(20.0, _size.width - 20.0), bug.pos.dy);
        }
        if (bug.pos.dy < 20 || bug.pos.dy > _gameAreaH - 20) {
          bug.vel = Offset(bug.vel.dx, -bug.vel.dy);
          bug.pos = Offset(bug.pos.dx, bug.pos.dy.clamp(20.0, _gameAreaH - 20.0));
        }

        // Random direction change (faster over time)
        bug.dirTimer -= dt;
        if (bug.dirTimer <= 0) {
          bug.dirTimer = 0.8 + _rng.nextDouble() * 1.5;
          final speed = 80.0 + elapsed * 4.0; // speeds up over 30s
          bug.vel = _randomVel(speed);
        }

        // Catch detection
        if ((p.pos - bug.pos).distance < _catchRadius) {
          _score++;
          HapticFeedback.lightImpact();
          bug.pos = Offset(
            _rng.nextDouble() * (_size.width - 80) + 40,
            _rng.nextDouble() * (_gameAreaH - 80) + 40,
          );
          bug.emoji = _bugEmojis[_rng.nextInt(_bugEmojis.length)];
          final speed = 90.0 + elapsed * 4.0 + _rng.nextDouble() * 40;
          bug.vel = _randomVel(speed);
        }
      }
    });
  }

  Offset _clampPlayer(Offset p) => Offset(
        p.dx.clamp(22.0, _size.width - 22.0),
        p.dy.clamp(22.0, _gameAreaH - 22.0),
      );

  void _end() {
    _countdown?.cancel();
    _rewards = _calcRewards();
    ref.read(gardenProvider.notifier).addSeedsToInventory(_rewards);
    _submitScore('catch', _score);
    setState(() => _over = true);
  }

  void _submitScore(String gameType, int score) {
    final user = ref.read(authProvider);
    if (user == null) return;
    FirestoreService.submitScore(
        user.uid, user.displayName, user.photoUrl, gameType, score);
  }

  Map<String, int> _calcRewards() {
    final count = _score >= 15 ? 3 : _score >= 8 ? 2 : _score >= 3 ? 1 : 0;
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
      backgroundColor: const Color(0xFF0D1F0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1F0D),
        foregroundColor: Colors.white,
        title: const Text('🦟 벌레 퇴치'),
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
                colors: [Color(0xFF0D1F0D), Color(0xFF1A3010)],
              ),
            ),
          ),

          if (_started && !_over) ...[
            // Game area border
            Positioned(
              left: 0, right: 0,
              top: _gameAreaH,
              child: Container(height: 1.5, color: Colors.white12),
            ),

            // Bugs
            for (final bug in _bugs)
              Positioned(
                left: bug.pos.dx - 18,
                top: bug.pos.dy - 18,
                child: Text(bug.emoji,
                    style: const TextStyle(fontSize: 30)),
              ),

            // Player
            if (_player != null)
              Positioned(
                left: _player!.pos.dx - 22,
                top: _player!.pos.dy - 22,
                child: const Text('🧑‍🌾',
                    style: TextStyle(fontSize: 36)),
              ),

            // HUD
            Positioned(
              top: 8, left: 16, right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GameHudPill('🦟 $_score 마리'),
                  GameHudPill('⏱ $_timeLeft 초',
                      urgent: _timeLeft <= 5),
                  GameHudPill(
                      _score >= 15
                          ? '🔥 대박!'
                          : _score >= 8
                              ? '👍 잘함!'
                              : '열심히!'),
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
              emoji: '🦟',
              title: '벌레 퇴치',
              desc: '조이스틱으로 이동해서\n날아다니는 벌레를 잡으세요!',
              hint: '30초 동안 최대한 많이 잡아요  (목표: 8마리+)',
              accentColor: Colors.greenAccent,
              onStart: _start,
            ),

          if (_over)
            GameResultOverlay(
              scoreText: '잡은 벌레: $_score 마리',
              rewards: _rewards,
              accentColor: Colors.greenAccent,
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

class _BugEnt {
  Offset pos;
  Offset vel;
  String emoji;
  double dirTimer;
  _BugEnt({required this.pos, required this.vel, required this.emoji})
      : dirTimer = 1.0;
}
