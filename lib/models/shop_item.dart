import 'game_level.dart';
import 'plant.dart';

enum ShopItemType { equipment, seed, consumable }

class ShopItem {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final int price;
  final ShopItemType type;

  const ShopItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.price,
    required this.type,
  });
}

abstract final class ShopCatalog {
  // ── Equipment (permanent upgrades) ────────────────────────────────────────
  static const equipment = <ShopItem>[
    ShopItem(
      id: 'water_pro',
      name: '황금 물뿌리개',
      emoji: '🪣',
      description: '물주기 효과 +35\n(기본 +20)',
      price: 600,
      type: ShopItemType.equipment,
    ),
    ShopItem(
      id: 'auto_sprinkler',
      name: '자동 분무기',
      emoji: '💦',
      description: '수분 30% 이하 식물을\n자동으로 급수',
      price: 1200,
      type: ShopItemType.equipment,
    ),
  ];

  // ── Consumables ────────────────────────────────────────────────────────────
  static const consumables = <ShopItem>[
    ShopItem(
      id: 'fertilizer',
      name: '영양제',
      emoji: '🧪',
      description: '선택 화단 성장 포인트\n즉시 +30',
      price: 150,
      type: ShopItemType.consumable,
    ),
    ShopItem(
      id: 'growth_boost',
      name: '성장촉진제',
      emoji: '⚡',
      description: '선택 화단 성장 단계\n즉시 +1',
      price: 280,
      type: ShopItemType.consumable,
    ),
  ];

  // ── Seed prices (by unlock level) ──────────────────────────────────────────
  static int seedPrice(SeedInfo seed) => switch (seed.unlockLevel) {
        1 => 80,
        2 => 150,
        3 => 200,
        4 => 300,
        5 => 400,
        _ => 500,
      };

  // ── Plant sell prices ──────────────────────────────────────────────────────
  static int sellPrice(PlantRarity rarity) => switch (rarity) {
        PlantRarity.holographic => 300,
        PlantRarity.rare        => 120,
        PlantRarity.uncommon    => 50,
        PlantRarity.common      => 20,
      };
}
