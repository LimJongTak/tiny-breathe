import 'package:flutter/material.dart';

import '../../models/game_level.dart';

// ── Virtual joystick ──────────────────────────────────────────────────────────

class GameJoystick extends StatefulWidget {
  final double size;
  final void Function(Offset direction) onChanged;
  const GameJoystick({super.key, this.size = 130, required this.onChanged});

  @override
  State<GameJoystick> createState() => _GameJoystickState();
}

class _GameJoystickState extends State<GameJoystick> {
  Offset _stick = Offset.zero;
  double get _maxR => widget.size * 0.28;

  void _update(Offset local) {
    final center = Offset(widget.size / 2, widget.size / 2);
    var delta = local - center;
    if (delta.distance > _maxR) delta = delta / delta.distance * _maxR;
    setState(() => _stick = delta);
    widget.onChanged(_maxR > 0 ? delta / _maxR : Offset.zero);
  }

  void _reset() {
    setState(() => _stick = Offset.zero);
    widget.onChanged(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart:  (d) => _update(d.localPosition),
      onPanUpdate: (d) => _update(d.localPosition),
      onPanEnd:    (_) => _reset(),
      onPanCancel: _reset,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _JoystickPainter(
            stick: _stick,
            baseR: widget.size / 2,
            thumbR: widget.size * 0.18,
          ),
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  final Offset stick;
  final double baseR, thumbR;
  _JoystickPainter({required this.stick, required this.baseR, required this.thumbR});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(c, baseR - 4,
        Paint()..color = Colors.white.withValues(alpha: 0.10));
    canvas.drawCircle(c, baseR - 4,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    // Cross guides
    final gp = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(c.dx, c.dy - baseR + 8), Offset(c.dx, c.dy + baseR - 8), gp);
    canvas.drawLine(Offset(c.dx - baseR + 8, c.dy), Offset(c.dx + baseR - 8, c.dy), gp);
    // Thumb
    canvas.drawCircle(c + stick, thumbR,
        Paint()..color = Colors.white.withValues(alpha: 0.55));
    canvas.drawCircle(c + stick, thumbR,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.90)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_JoystickPainter old) => old.stick != stick;
}

// ── Shared HUD pill ───────────────────────────────────────────────────────────

class GameHudPill extends StatelessWidget {
  final String label;
  final bool urgent;
  final Color? color;
  const GameHudPill(this.label, {this.urgent = false, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? (urgent ? Colors.red : Colors.white);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: urgent ? Border.all(color: Colors.red) : null,
      ),
      child: Text(label,
          style: TextStyle(
              color: c, fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }
}

// ── Shared start overlay ──────────────────────────────────────────────────────

class GameStartOverlay extends StatelessWidget {
  final String emoji, title, desc, hint;
  final Color accentColor;
  final VoidCallback onStart;
  const GameStartOverlay({
    required this.emoji,
    required this.title,
    required this.desc,
    required this.hint,
    required this.accentColor,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 72)),
          const SizedBox(height: 16),
          Text(title,
              style: TextStyle(
                  color: accentColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(desc,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(hint,
              style: const TextStyle(color: Colors.amber, fontSize: 13),
              textAlign: TextAlign.center),
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
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }
}

// ── Shared result overlay ─────────────────────────────────────────────────────

class GameResultOverlay extends StatelessWidget {
  final String scoreText;
  final Map<String, int> rewards;
  final Color accentColor;
  final VoidCallback onRetry, onBack;
  const GameResultOverlay({
    required this.scoreText,
    required this.rewards,
    required this.accentColor,
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
            border: Border.all(color: accentColor.withValues(alpha: 0.4)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('🎉 결과!',
                style: TextStyle(
                    color: accentColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(scoreText,
                style: const TextStyle(color: Colors.white, fontSize: 17)),
            const SizedBox(height: 16),
            if (rewards.isEmpty)
              const Text('씨앗을 얻지 못했어요 😢',
                  style: TextStyle(color: Colors.white54))
            else ...[
              const Text('획득한 씨앗 🌱',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              ...rewards.entries.map((e) {
                final info = GameLevels.seeds
                    .where((s) => s.name == e.key)
                    .firstOrNull;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('${info?.emoji ?? "🌱"} ${e.key}  x${e.value}',
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
