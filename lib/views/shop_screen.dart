import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_level.dart';
import '../models/shop_item.dart';
import '../viewmodels/garden_viewmodel.dart';

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gardenProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1B0D),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A2E1A),
          foregroundColor: Colors.white,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🛒 상점',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Row(children: [
                const Text('🪙 ', style: TextStyle(fontSize: 13)),
                Text('${state.coins} 코인',
                    style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ]),
            ],
          ),
          bottom: const TabBar(
            indicatorColor: Colors.greenAccent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            tabs: [
              Tab(text: '🌱 씨앗'),
              Tab(text: '🔧 장비/소모품'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SeedTab(state: state, ref: ref),
            _EquipTab(state: state, ref: ref),
          ],
        ),
      ),
    );
  }
}

// ── Seeds tab ─────────────────────────────────────────────────────────────────

class _SeedTab extends StatelessWidget {
  final GardenState state;
  final WidgetRef ref;
  const _SeedTab({required this.state, required this.ref});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader('씨앗 구매'),
        const SizedBox(height: 8),
        ...GameLevels.seeds.map((seed) {
          final price = ShopCatalog.seedPrice(seed);
          final owned = state.seedInventory[seed.name] ?? 0;
          final canBuy = state.coins >= price;
          return _ItemCard(
            emoji: seed.emoji,
            name: seed.name,
            description: 'Lv.${seed.unlockLevel} 씨앗  •  보유: $owned개',
            price: price,
            canBuy: canBuy,
            onBuy: () {
              final seedItem = ShopItem(
                id: seed.name,
                name: seed.name,
                emoji: seed.emoji,
                description: '',
                price: price,
                type: ShopItemType.seed,
              );
              final ok = ref.read(gardenProvider.notifier).buyItem(seedItem);
              if (!ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('코인이 부족합니다!')));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${seed.emoji} ${seed.name} 씨앗 구매!')));
              }
            },
          );
        }),
      ],
    );
  }
}

// ── Equipment & Consumables tab ───────────────────────────────────────────────

class _EquipTab extends StatelessWidget {
  final GardenState state;
  final WidgetRef ref;
  const _EquipTab({required this.state, required this.ref});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader('장비 (영구)'),
        const SizedBox(height: 8),
        ...ShopCatalog.equipment.map((item) {
          final owned = state.ownedEquipment.contains(item.id);
          final canBuy = !owned && state.coins >= item.price;
          return _ItemCard(
            emoji: item.emoji,
            name: item.name,
            description: item.description,
            price: item.price,
            canBuy: canBuy,
            owned: owned,
            onBuy: () {
              if (owned) return;
              final ok = ref.read(gardenProvider.notifier).buyItem(item);
              if (!ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('코인이 부족합니다!')));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${item.emoji} ${item.name} 구매 완료!')));
              }
            },
          );
        }),
        const SizedBox(height: 20),
        const _SectionHeader('소모품'),
        const SizedBox(height: 8),
        ...ShopCatalog.consumables.map((item) {
          final count = state.consumables[item.id] ?? 0;
          final canBuy = state.coins >= item.price;
          return _ItemCard(
            emoji: item.emoji,
            name: item.name,
            description: '${item.description}\n보유: $count개',
            price: item.price,
            canBuy: canBuy,
            onBuy: () {
              final ok = ref.read(gardenProvider.notifier).buyItem(item);
              if (!ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('코인이 부족합니다!')));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${item.emoji} ${item.name} 구매!')));
              }
            },
          );
        }),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8));
  }
}

class _ItemCard extends StatelessWidget {
  final String emoji, name, description;
  final int price;
  final bool canBuy;
  final bool owned;
  final VoidCallback onBuy;

  const _ItemCard({
    required this.emoji,
    required this.name,
    required this.description,
    required this.price,
    required this.canBuy,
    required this.onBuy,
    this.owned = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: owned
                ? Colors.amber.withValues(alpha: 0.6)
                : Colors.white12),
      ),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 36)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                if (owned) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.6))),
                    child: const Text('보유중',
                        style: TextStyle(
                            color: Colors.amber,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ]),
              const SizedBox(height: 3),
              Text(description,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(children: [
              const Text('🪙', style: TextStyle(fontSize: 13)),
              Text(' $price',
                  style: TextStyle(
                      color: canBuy ? Colors.amber : Colors.white38,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 6),
            SizedBox(
              height: 32,
              child: ElevatedButton(
                onPressed: canBuy && !owned ? onBuy : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      owned ? Colors.grey[700] : Colors.green[700],
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.white12,
                  disabledForegroundColor: Colors.white24,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  owned ? '보유' : '구매',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ]),
    );
  }
}
