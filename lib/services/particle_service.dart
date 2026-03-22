import 'dart:math';
import 'package:flutter/material.dart';

class Butterfly {
  Offset position;
  Offset velocity;
  double angle;
  final Color color;

  Butterfly({
    required this.position,
    required this.velocity,
    required this.angle,
    required this.color,
  });

  void update(Size size) {
    // 1. Basic Movement
    position += velocity;
    
    // 2. Wrap around screen
    if (position.dx < 0) position = Offset(size.width, position.dy);
    if (position.dx > size.width) position = Offset(0, position.dy);
    if (position.dy < 0) position = Offset(position.dx, size.height);
    if (position.dy > size.height) position = Offset(position.dx, 0);

    // 3. Small random course corrections (Brownian-ish)
    final random = Random();
    velocity = Offset(
      velocity.dx + (random.nextDouble() * 0.2 - 0.1),
      velocity.dy + (random.nextDouble() * 0.2 - 0.1),
    ).scale(0.98, 0.98); // Simple drag to limit speed
  }
}

class ButterflyPainter extends CustomPainter {
  final List<Butterfly> butterflies;
  final double animationValue;

  ButterflyPainter({required this.butterflies, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    for (var butterfly in butterflies) {
      paint.color = butterfly.color;
      
      // Wing flap animation
      double flap = sin(animationValue * 15) * 0.5 + 1.0;
      
      canvas.save();
      canvas.translate(butterfly.position.dx, butterfly.position.dy);
      canvas.rotate(butterfly.angle);
      
      // Draw left wing
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(-4, 0), width: 8 * flap, height: 12),
        paint,
      );
      // Draw right wing
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(4, 0), width: 8 * flap, height: 12),
        paint,
      );
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ButterflyPainter oldDelegate) => true;
}
