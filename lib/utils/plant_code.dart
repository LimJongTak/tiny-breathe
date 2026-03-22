import 'dart:convert';
import '../models/plant.dart';
import 'package:flutter/painting.dart';

/// Encodes / decodes a [Plant]'s genetic identity as a compact URL-safe string.
///
/// Format (pipe-delimited, base64url-encoded):
///   species | hue | saturation | lightness | rarity
class PlantCode {
  PlantCode._();

  /// Returns a shareable code string for [plant].
  static String encode(Plant plant) {
    final parts = [
      plant.species,
      plant.color.hue.toStringAsFixed(1),
      plant.color.saturation.toStringAsFixed(3),
      plant.color.lightness.toStringAsFixed(3),
      plant.rarity.name,
    ].join('|');
    return base64Url.encode(utf8.encode(parts));
  }

  /// Decodes [code] back into a [Plant], or returns null on any error.
  static Plant? decode(String code) {
    try {
      final raw = utf8.decode(base64Url.decode(code.trim()));
      final parts = raw.split('|');
      if (parts.length != 5) return null;
      final rarity = PlantRarity.values.firstWhere(
        (r) => r.name == parts[4],
        orElse: () => PlantRarity.common,
      );
      return Plant(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        species: parts[0],
        color: HSLColor.fromAHSL(
          1.0,
          double.parse(parts[1]),
          double.parse(parts[2]),
          double.parse(parts[3]),
        ),
        rarity: rarity,
        createdAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }
}
