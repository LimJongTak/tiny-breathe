import 'package:flutter/material.dart';

import '../models/plant.dart';
import 'plant_painter.dart';

/// Animated, touch-responsive plant widget.
/// Draws entirely with [PlantPainter] — no .riv file required.
class InteractivePlant extends StatefulWidget {
  final Plant plant;

  const InteractivePlant({super.key, required this.plant});

  @override
  State<InteractivePlant> createState() => _InteractivePlantState();
}

class _InteractivePlantState extends State<InteractivePlant>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _isTouching = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanDown: (_) => setState(() => _isTouching = true),
      onPanEnd: (_) => setState(() => _isTouching = false),
      onPanCancel: () => setState(() => _isTouching = false),
      onTapDown: (_) => setState(() => _isTouching = true),
      onTapUp: (_) => setState(() => _isTouching = false),
      onTapCancel: () => setState(() => _isTouching = false),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => CustomPaint(
          painter: PlantPainter(
            plant: widget.plant,
            animValue: _ctrl.value,
            isTouching: _isTouching,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}
