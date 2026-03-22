import 'dart:math';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Boid data model
// ---------------------------------------------------------------------------

class Boid {
  Offset position;
  Offset velocity;
  final Color color;

  Boid({
    required this.position,
    required this.velocity,
    required this.color,
  });

  double get speed => velocity.distance;
  double get angle => atan2(velocity.dy, velocity.dx);
}

// ---------------------------------------------------------------------------
// Flock (Boids algorithm: Separation · Alignment · Cohesion)
// ---------------------------------------------------------------------------

/// Manages a flock of butterfly boids.
///
/// Call [tick] once per animation frame to advance the simulation.
class ButterflyFlock {
  final List<Boid> boids;
  final Random _rng = Random();

  // ---- Boids tuning constants ----
  static const double _maxSpeed = 2.5;
  static const double _minSpeed = 0.8;
  static const double _separationRadius = 30.0;
  static const double _alignmentRadius = 70.0;
  static const double _cohesionRadius = 90.0;
  static const double _separationWeight = 1.6;
  static const double _alignmentWeight = 1.0;
  static const double _cohesionWeight = 0.7;
  // Soft pull toward the plant (anchor); activates beyond [_attractThreshold].
  static const double _attractWeight = 0.35;
  static const double _attractThreshold = 180.0;

  ButterflyFlock({required int count, required Size size})
      : boids = List.generate(count, (i) {
          final rng = Random(i * 31 + 7);
          return Boid(
            position: Offset(
              rng.nextDouble() * size.width,
              rng.nextDouble() * size.height,
            ),
            velocity: Offset(
              rng.nextDouble() * 2 - 1,
              rng.nextDouble() * 2 - 1,
            ),
            color: HSVColor.fromAHSV(
              0.82,
              rng.nextDouble() * 60 + 240, // blue-violet palette
              0.45 + rng.nextDouble() * 0.45,
              0.80 + rng.nextDouble() * 0.20,
            ).toColor(),
          );
        });

  /// Advance the flock one frame.
  ///
  /// [anchor] should be the plant's screen-center so butterflies orbit it.
  void tick(Size size, Offset anchor) {
    for (final boid in boids) {
      Offset sep = Offset.zero;
      Offset ali = Offset.zero;
      Offset coh = Offset.zero;
      int aliN = 0, cohN = 0;

      for (final other in boids) {
        if (identical(boid, other)) continue;
        final d = (other.position - boid.position).distance;

        // --- Separation: steer away from nearby boids ---
        if (d < _separationRadius && d > 0) {
          sep -= (other.position - boid.position) * (1 / d);
        }

        // --- Alignment: match average velocity of neighbours ---
        if (d < _alignmentRadius) {
          ali += other.velocity;
          aliN++;
        }

        // --- Cohesion: move toward centre of local flock ---
        if (d < _cohesionRadius) {
          coh += other.position;
          cohN++;
        }
      }

      if (aliN > 0) ali = ali / aliN.toDouble();
      if (cohN > 0) coh = (coh / cohN.toDouble()) - boid.position;

      // --- Attraction toward anchor (plant centre) ---
      final toAnchor = anchor - boid.position;
      final attract =
          toAnchor.distance > _attractThreshold ? toAnchor / toAnchor.distance : Offset.zero;

      // --- Brownian noise for organic feel ---
      final noise = Offset(
        _rng.nextDouble() * 0.4 - 0.2,
        _rng.nextDouble() * 0.4 - 0.2,
      );

      // --- Combine forces ---
      boid.velocity = boid.velocity +
          sep * _separationWeight +
          ali * _alignmentWeight +
          coh * _cohesionWeight +
          attract * _attractWeight +
          noise;

      // --- Clamp speed ---
      final spd = boid.velocity.distance.clamp(_minSpeed, _maxSpeed);
      if (boid.velocity.distance > 0) {
        boid.velocity = boid.velocity / boid.velocity.distance * spd;
      }

      // --- Move ---
      boid.position += boid.velocity;

      // --- Screen wrapping ---
      final dx = boid.position.dx % size.width;
      final dy = boid.position.dy % size.height;
      boid.position = Offset(
        dx < 0 ? dx + size.width : dx,
        dy < 0 ? dy + size.height : dy,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

/// Renders the [ButterflyFlock] onto a canvas with wing-flap animation.
class ButterflyPainter extends CustomPainter {
  final ButterflyFlock flock;
  final double animationValue; // 0.0 – 1.0 (looping)

  const ButterflyPainter({
    required this.flock,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..style = PaintingStyle.fill;

    for (final boid in flock.boids) {
      // Each boid flaps at its own phase offset for a natural look.
      final phase = (boid.hashCode % 100) / 100.0;
      final flap = sin((animationValue + phase) * pi * 6) * 0.55 + 0.85;

      canvas.save();
      canvas.translate(boid.position.dx, boid.position.dy);
      // Rotate so nose points in the direction of travel.
      canvas.rotate(boid.angle + pi / 2);

      // Body
      fill.color = boid.color.withValues(alpha: 0.90);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 3, height: 8),
        fill,
      );

      // Upper wings
      fill.color = boid.color.withValues(alpha: 0.75);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(-5.5 * flap, -3), width: 11 * flap, height: 8),
        fill,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(5.5 * flap, -3), width: 11 * flap, height: 8),
        fill,
      );

      // Lower wings (smaller, lighter)
      fill.color = boid.color.withValues(alpha: 0.50);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(-4 * flap, 3.5), width: 7 * flap, height: 6),
        fill,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(4 * flap, 3.5), width: 7 * flap, height: 6),
        fill,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ButterflyPainter old) => true;
}
