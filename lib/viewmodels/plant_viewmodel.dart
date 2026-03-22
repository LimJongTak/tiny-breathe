import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/painting.dart';
import '../models/plant.dart';

/// Riverpod provider — exposes [PlantNotifier] for the active plant.
final plantProvider =
    StateNotifierProvider<PlantNotifier, Plant>((ref) => PlantNotifier());

class PlantNotifier extends StateNotifier<Plant> {
  PlantNotifier()
      : super(Plant(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          species: 'Fernleaf',
          color: const HSLColor.fromAHSL(1.0, 120, 0.60, 0.45),
          hydration: 45.0,
          growthStage: 1,
          rarity: PlantRarity.common,
          createdAt: DateTime.now(),
        ));

  /// Add [amount] water (clamped to 0–100).
  void water([double amount = 10]) {
    state = state.copyWith(
      hydration: (state.hydration + amount).clamp(0.0, 100.0),
    );
  }

  /// Advance growth by one stage (max 4).
  void grow() {
    if (state.growthStage < 4) {
      state = state.copyWith(growthStage: state.growthStage + 1);
    }
  }

  /// Replace active plant with a hybrid of [state] and [other].
  void breed(Plant other) {
    state = Plant.crossBreed(state, other);
  }

  /// Apply passive weather hydration.
  void applyWeatherHydration(double amount) => water(amount);
}
