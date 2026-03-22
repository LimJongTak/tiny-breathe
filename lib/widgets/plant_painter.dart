import 'dart:math';
import 'package:flutter/material.dart';
import '../models/plant.dart';

/// CustomPainter that renders a plant at growth stages 0–4.
/// No external assets required — pure Flutter canvas.
class PlantPainter extends CustomPainter {
  final Plant plant;
  final double animValue; // 0–1 looping (breathing)
  final bool isTouching;

  const PlantPainter({
    required this.plant,
    required this.animValue,
    this.isTouching = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final baseY = size.height * 0.87;

    // Gentle breathing sway — faster / wider on touch
    final sway = sin(animValue * 2 * pi) * (isTouching ? 0.07 : 0.025);

    // Droop factor: 0 = healthy, 1 = very wilted
    final droop = ((100 - plant.hydration) / 100).clamp(0.0, 0.6);

    _drawSoil(canvas, cx, baseY, size.width);

    switch (plant.growthStage) {
      case 0:
        _drawSeed(canvas, cx, baseY, sway);
      case 1:
        _drawPlant(canvas, cx, baseY, sway, droop, 55, 1);
      case 2:
        _drawPlant(canvas, cx, baseY, sway, droop, 95, 2);
      case 3:
        _drawPlant(canvas, cx, baseY, sway, droop, 130, 3);
      case 4:
        _drawPlant(canvas, cx, baseY, sway, droop, 155, 4);
        if (plant.rarity == PlantRarity.holographic) {
          _drawSparkles(canvas, cx, baseY - 155, animValue);
        }
    }
  }

  // ── Soil ────────────────────────────────────────────────────────────────
  void _drawSoil(Canvas canvas, double cx, double baseY, double w) {
    final dark = Paint()..color = const Color(0xFF4E342E);
    final mid = Paint()..color = const Color(0xFF6D4C41);
    final hi = Paint()..color = const Color(0xFF8D6E63);

    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, baseY + 4), width: w * 0.7, height: 22), dark);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, baseY), width: w * 0.55, height: 16), mid);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx - 8, baseY - 3), width: w * 0.25, height: 8), hi);
  }

  // ── Stage 0: Seed ────────────────────────────────────────────────────────
  void _drawSeed(Canvas canvas, double cx, double baseY, double sway) {
    // Seed
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, baseY - 6), width: 20, height: 14),
      Paint()..color = const Color(0xFF795548),
    );
    // Tiny sprout
    final sp = Paint()
      ..color = const Color(0xFF81C784)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(cx, baseY - 12)
      ..quadraticBezierTo(cx + sin(sway) * 8 - 6, baseY - 24, cx + sin(sway) * 6 - 2, baseY - 32);
    canvas.drawPath(path, sp);
  }

  // ── Stages 1–4 ──────────────────────────────────────────────────────────
  void _drawPlant(Canvas canvas, double cx, double baseY, double sway,
      double droop, double stemH, int stage) {
    final tipX = cx + sin(sway) * stemH * 0.14;
    final tipY = baseY - stemH;

    _drawStem(canvas, cx, baseY, tipX, tipY, stemH, sway);

    final lc = _leafColor();

    // Leaf pairs per stage
    final pairs = stage == 1 ? 1 : stage == 2 ? 2 : 3;
    final leafSizes = [32.0, 28.0, 22.0];
    final yRatios = stage == 1
        ? [0.55]
        : stage == 2
            ? [0.38, 0.68]
            : [0.28, 0.52, 0.75];

    for (int i = 0; i < pairs; i++) {
      final leafY = baseY - stemH * yRatios[i];
      final sz = leafSizes[i];
      final droopAngle = droop * 0.35 * (1 + i * 0.1);

      _drawLeaf(canvas, cx, leafY, sz,
          -pi * 0.30 - droopAngle + sway * 0.8, lc, false);
      _drawLeaf(canvas, cx, leafY, sz,
          pi * 0.30 + droopAngle + sway * 0.8, lc, true);
    }

    // Bud / flower
    if (stage == 3) _drawBud(canvas, tipX, tipY, plant.color.toColor());
    if (stage == 4) _drawFlower(canvas, tipX, tipY, plant.color.toColor(), animValue);
  }

  void _drawStem(Canvas canvas, double cx, double baseY, double tipX,
      double tipY, double h, double sway) {
    final paint = Paint()
      ..color = const Color(0xFF388E3C)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(cx, baseY - 5)
      ..cubicTo(
        cx + sin(sway * 0.4) * h * 0.06, baseY - h * 0.33,
        cx + sin(sway * 0.7) * h * 0.10, baseY - h * 0.66,
        tipX, tipY,
      );
    canvas.drawPath(path, paint);
  }

  void _drawLeaf(Canvas canvas, double stemX, double stemY, double sz,
      double angle, Color color, bool right) {
    canvas.save();
    canvas.translate(stemX, stemY);
    canvas.rotate(angle);

    final dir = right ? 1.0 : -1.0;
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(dir * sz * 0.45, -sz * 0.28, dir * sz, 0)
      ..quadraticBezierTo(dir * sz * 0.45, sz * 0.28, 0, 0);

    canvas.drawPath(path, Paint()..color = color);
    // Vein
    canvas.drawLine(
      Offset.zero, Offset(dir * sz * 0.78, 0),
      Paint()
        ..color = color.withValues(alpha: 0.45)
        ..strokeWidth = 0.9,
    );
    canvas.restore();
  }

  void _drawBud(Canvas canvas, double x, double y, Color color) {
    // Sepal
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y - 9), width: 11, height: 18),
      Paint()..color = const Color(0xFF2E7D32),
    );
    // Petal tips showing
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y - 14), width: 13, height: 10),
      Paint()..color = color,
    );
  }

  void _drawFlower(Canvas canvas, double cx, double cy, Color petal, double t) {
    const n = 6;
    const pLen = 17.0;
    const pW = 11.0;

    // Soft glow
    canvas.drawCircle(
      Offset(cx, cy),
      pLen + 8,
      Paint()
        ..color = petal.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // Petals
    final pp = Paint()..color = petal;
    for (int i = 0; i < n; i++) {
      final a = (i / n) * 2 * pi + t * pi * 0.04;
      canvas.save();
      canvas.translate(cx + cos(a) * pLen, cy + sin(a) * pLen);
      canvas.rotate(a + pi / 2);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: pW, height: pLen),
        pp,
      );
      canvas.restore();
    }

    // Center
    canvas.drawCircle(Offset(cx, cy), 8, Paint()..color = Colors.yellow.shade600);
    canvas.drawCircle(Offset(cx, cy), 4, Paint()..color = Colors.orange.shade700);
  }

  void _drawSparkles(Canvas canvas, double cx, double tipY, double t) {
    for (int i = 0; i < 6; i++) {
      final a = t * 2 * pi + (i / 6) * 2 * pi;
      final r = 28.0 + sin(t * pi * 4 + i) * 9;
      final hue = (i / 6 * 360 + t * 200) % 360;
      canvas.drawCircle(
        Offset(cx + cos(a) * r, tipY + sin(a) * r),
        2.5,
        Paint()
          ..color = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  // Blend plant hue toward green for a natural leaf colour
  Color _leafColor() {
    final h = plant.color.hue;
    const green = 120.0;
    final diff = ((green - h + 540) % 360) - 180;
    final leafH = (h + diff * 0.65) % 360;
    final vigor = (plant.hydration / 100).clamp(0.3, 1.0);
    return HSLColor.fromAHSL(1.0, leafH, 0.55, 0.27 + vigor * 0.18).toColor();
  }

  @override
  bool shouldRepaint(covariant PlantPainter old) =>
      old.animValue != animValue ||
      old.plant != plant ||
      old.isTouching != isTouching;
}
