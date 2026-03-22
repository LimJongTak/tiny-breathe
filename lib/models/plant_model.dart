import 'dart:math';
import 'package:flutter/painting.dart';

class Plant {
  final String species;
  final HSLColor color;
  final int growthStage; // 0-4
  final double hydration; // 0-100

  Plant({
    required this.species,
    required this.color,
    this.growthStage = 0,
    this.hydration = 50.0,
  });

  /// Cross-breeds this plant with another, returning a new hybrid.
  /// Uses HSL mid-point for color with a small random mutation.
  Plant crossBreed(Plant other) {
    final Random random = Random();

    // Calculate midpoint hue with wrapping support
    double h1 = color.hue;
    double h2 = other.color.hue;
    if ((h1 - h2).abs() > 180) {
      if (h1 < h2) { h1 += 360; } else { h2 += 360; }
    }
    double newHue = ((h1 + h2) / 2 + (random.nextDouble() * 20 - 10)) % 360;

    double newSaturation = ((color.saturation + other.color.saturation) / 2).clamp(0.2, 1.0);
    double newLightness = ((color.lightness + other.color.lightness) / 2).clamp(0.3, 0.8);

    return Plant(
      species: '${species.substring(0, species.length ~/ 2)}${other.species.substring(other.species.length ~/ 2)}',
      color: HSLColor.fromAHSL(1.0, newHue, newSaturation, newLightness),
      growthStage: 0,
      hydration: 70.0,
    );
  }

  Plant copyWith({
    String? species,
    HSLColor? color,
    int? growthStage,
    double? hydration,
  }) {
    return Plant(
      species: species ?? this.species,
      color: color ?? this.color,
      growthStage: growthStage ?? this.growthStage,
      hydration: hydration ?? this.hydration,
    );
  }
}
