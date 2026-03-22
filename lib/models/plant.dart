import 'dart:math';
import 'package:flutter/painting.dart';

/// Rarity tier of a plant, determined at cross-breeding time.
enum PlantRarity {
  common,     // 55% — standard offspring
  uncommon,   // 25% — slightly shifted hue
  rare,       // 15% — high saturation boost
  holographic // 5%  — iridescent shimmer effect
}

/// Core data model for a plant in the Tiny Breathe garden.
///
/// Immutable — all mutations return a new [Plant] via [copyWith].
class Plant {
  final String id;
  final String species;
  final HSLColor color;
  final int growthStage;  // 0 (seed) → 4 (full bloom)
  final double hydration; // 0.0 – 100.0
  final PlantRarity rarity;
  final DateTime createdAt;
  final List<String> parentIds; // [] for starters, [p1.id, p2.id] for hybrids

  const Plant({
    required this.id,
    required this.species,
    required this.color,
    this.growthStage = 0,
    this.hydration = 50.0,
    this.rarity = PlantRarity.common,
    required this.createdAt,
    this.parentIds = const [],
  });

  bool get isHybrid => parentIds.length >= 2;

  // ---------------------------------------------------------------------------
  // Factory: genetic cross-breeding
  // ---------------------------------------------------------------------------

  static Plant crossBreed(Plant parent1, Plant parent2) {
    final rng = Random();
    double h1 = parent1.color.hue;
    double h2 = parent2.color.hue;
    if ((h1 - h2).abs() > 180) {
      if (h1 < h2) {
        h1 += 360;
      } else {
        h2 += 360;
      }
    }
    final newHue = ((h1 + h2) / 2 + (rng.nextDouble() * 20 - 10)) % 360;

    final baseSat = (parent1.color.saturation + parent2.color.saturation) / 2;
    final baseLit = (parent1.color.lightness  + parent2.color.lightness)  / 2;

    final roll = rng.nextDouble();
    final PlantRarity rarity;
    final double satMultiplier;

    if (roll < 0.05) {
      rarity = PlantRarity.holographic;
      satMultiplier = 1.0;
    } else if (roll < 0.20) {
      rarity = PlantRarity.rare;
      satMultiplier = 0.95;
    } else if (roll < 0.45) {
      rarity = PlantRarity.uncommon;
      satMultiplier = 0.90;
    } else {
      rarity = PlantRarity.common;
      satMultiplier = 0.85;
    }

    final newSat = (baseSat * satMultiplier).clamp(0.2, 1.0);
    final newLit = baseLit.clamp(0.3, 0.8);

    final mid1 = parent1.species.length ~/ 2;
    final mid2 = parent2.species.length - parent2.species.length ~/ 2;
    final hybridName =
        '${parent1.species.substring(0, mid1)}${parent2.species.substring(parent2.species.length - mid2)}';

    return Plant(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      species: hybridName,
      color: HSLColor.fromAHSL(1.0, newHue, newSat, newLit),
      growthStage: 0,
      hydration: 70.0,
      rarity: rarity,
      createdAt: DateTime.now(),
      parentIds: [parent1.id, parent2.id],
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Plant copyWith({
    String? id,
    String? species,
    HSLColor? color,
    int? growthStage,
    double? hydration,
    PlantRarity? rarity,
    DateTime? createdAt,
    List<String>? parentIds,
  }) {
    return Plant(
      id: id ?? this.id,
      species: species ?? this.species,
      color: color ?? this.color,
      growthStage: growthStage ?? this.growthStage,
      hydration: hydration ?? this.hydration,
      rarity: rarity ?? this.rarity,
      createdAt: createdAt ?? this.createdAt,
      parentIds: parentIds ?? this.parentIds,
    );
  }

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'species': species,
        'colorH': color.hue,
        'colorS': color.saturation,
        'colorL': color.lightness,
        'growthStage': growthStage,
        'hydration': hydration,
        'rarity': rarity.name,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'parentIds': parentIds,
      };

  factory Plant.fromJson(Map<String, dynamic> j) => Plant(
        id: j['id'] as String,
        species: j['species'] as String,
        color: HSLColor.fromAHSL(
          1.0,
          (j['colorH'] as num).toDouble(),
          (j['colorS'] as num).toDouble(),
          (j['colorL'] as num).toDouble(),
        ),
        growthStage: (j['growthStage'] as num).toInt(),
        hydration: (j['hydration'] as num).toDouble(),
        rarity: PlantRarity.values.firstWhere(
          (r) => r.name == j['rarity'],
          orElse: () => PlantRarity.common,
        ),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (j['createdAt'] as num).toInt()),
        parentIds:
            (j['parentIds'] as List?)?.cast<String>() ?? const [],
      );

  @override
  String toString() =>
      'Plant($species, stage: $growthStage, hydration: ${hydration.toStringAsFixed(1)}, rarity: ${rarity.name})';
}
