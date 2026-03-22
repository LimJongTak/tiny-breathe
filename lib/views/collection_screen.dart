import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/game_level.dart';
import '../models/plant.dart';
import '../models/shop_item.dart';
import '../utils/plant_code.dart';
import '../viewmodels/garden_viewmodel.dart';
import '../widgets/plant_painter.dart';

enum _SortBy { name, rarity, date, stage }

class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  _SortBy _sortBy = _SortBy.date;

  static const Map<PlantRarity, int> _rarityOrder = {
    PlantRarity.holographic: 0,
    PlantRarity.rare:        1,
    PlantRarity.uncommon:    2,
    PlantRarity.common:      3,
  };

  static const Map<PlantRarity, Color> _rc = {
    PlantRarity.holographic: Color(0xFFAB47BC),
    PlantRarity.rare:        Color(0xFFFF7043),
    PlantRarity.uncommon:    Color(0xFF26A69A),
    PlantRarity.common:      Color(0xFF66BB6A),
  };
  static const Map<PlantRarity, String> _rl = {
    PlantRarity.holographic: '\u2728 \ud640\ub85c\uadf8\ub798\ud53d',
    PlantRarity.rare:        '\u2b50 \ud76c\uadc0\uc885',
    PlantRarity.uncommon:    '\uD83C\uDF3F \ube44\ubc94\uc885',
    PlantRarity.common:      '\uD83C\uDF31 \uc77c\ubc18\uc885',
  };

  List<Plant> _sorted(List<Plant> plants) {
    final list = [...plants];
    switch (_sortBy) {
      case _SortBy.name:
        list.sort((a, b) => a.species.compareTo(b.species));
      case _SortBy.rarity:
        list.sort((a, b) =>
            (_rarityOrder[a.rarity] ?? 9).compareTo(_rarityOrder[b.rarity] ?? 9));
      case _SortBy.date:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _SortBy.stage:
        list.sort((a, b) => b.growthStage.compareTo(a.growthStage));
    }
    return list;
  }

  // ── Import code ────────────────────────────────────────────────────────────

  void _confirmSell(Plant plant) {
    final price = ShopCatalog.sellPrice(plant.rarity);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2E1A),
        title: Text('${plant.species} 판매',
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('이 식물을 판매하시겠어요?',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('🪙', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 6),
              Text('$price 코인 획득',
                  style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ]),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[700],
                foregroundColor: Colors.white),
            onPressed: () {
              final earned = ref
                  .read(gardenProvider.notifier)
                  .sellPlantFromCollection(plant.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('🪙 $earned 코인 획득!')));
            },
            child: const Text('판매'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2E1A),
        title: const Text('\uD83E\uDDEC \uc528\uc557 \ucf54\ub4dc \uac00\uc838\uc624\uae30',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                '\uce5c\uad6c\uc5d0\uac8c \ubc1b\uc740 \uc218\ud0dd \ucf54\ub4dc\ub97c \uc785\ub825\ud558\uc138\uc694.\n\ub3c4\uac10\uc5d0 \ucd94\uac00\ub429\ub2c8\ub2e4.',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'ex) 5bWlub...',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700], foregroundColor: Colors.white),
            onPressed: () {
              final plant = PlantCode.decode(ctrl.text);
              if (plant == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('\uc720\ud6a8\ud558\uc9c0 \uc54a\uc740 \ucf54\ub4dc\uc785\ub2c8\ub2e4.')));
                return;
              }
              final notifier = ref.read(gardenProvider.notifier);
              notifier.importToCollection(plant);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${plant.species} \ub3c4\uac10\uc5d0 \ucd94\uac00!')));
            },
            child: const Text('\ucd94\uac00'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gardenProvider);
    final plants = _sorted(state.collection);
    final collectedSpecies =
        state.collection.map((p) => p.species).toSet().length;
    final totalSpecies = GameLevels.seeds.length;
    final completionPct = (collectedSpecies / totalSpecies * 100).round();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B0D),
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        tooltip: '\ucf54\ub4dc \uac00\uc838\uc624\uae30',
        onPressed: _showImportDialog,
        child: const Icon(Icons.qr_code_scanner_rounded),
      ),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2E1A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('식물 도감',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Row(children: [
              Text('$collectedSpecies / $totalSpecies종  ($completionPct%)',
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: collectedSpecies / totalSpecies,
                    minHeight: 5,
                    backgroundColor: Colors.white12,
                    color: Colors.greenAccent,
                  ),
                ),
              ),
            ]),
          ],
        ),
        actions: [
          ..._rarityOrder.entries.map((e) {
            final count = plants.where((p) => p.rarity == e.key).length;
            if (count == 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: _rc[e.key]!.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _rc[e.key]!.withValues(alpha: 0.6))),
                child: Text('$count',
                    style: TextStyle(color: _rc[e.key], fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            );
          }),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF1A2E1A),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                const Text('\uc815\ub82c: ',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                ..._SortBy.values.map((s) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(_sortLabel(s)),
                        selected: _sortBy == s,
                        onSelected: (_) => setState(() => _sortBy = s),
                        selectedColor: Colors.green[700],
                        backgroundColor: Colors.white10,
                        labelStyle: TextStyle(
                            color: _sortBy == s ? Colors.white : Colors.white54,
                            fontSize: 11),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                    )),
              ],
            ),
          ),
          Expanded(
            child: plants.isEmpty
                ? const _EmptyCollection()
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.70,
                    ),
                    itemCount: plants.length,
                    itemBuilder: (_, i) => _CollectionCard(
                      plant: plants[i],
                      rarityColors: _rc,
                      rarityLabels: _rl,
                      onCodeTap: () => _showCodeDialog(context, plants[i]),
                      onSell: () => _confirmSell(plants[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showCodeDialog(BuildContext context, Plant plant) {
    final code = PlantCode.encode(plant);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2E1A),
        title: Text('${plant.species} \ucf54\ub4dc',
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('\uce5c\uad6c\uc5d0\uac8c \ucf54\ub4dc\ub97c \uacf5\uc720\ud558\uba74\n\uc0c1\ub300\ubc29 \ub3c4\uac10\uc5d0 \ucd94\uac00\ud560 \uc218 \uc788\uc5b4\uc694!',
                style: TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            SelectableText(
              code,
              style: const TextStyle(
                  color: Colors.greenAccent,
                  fontFamily: 'monospace',
                  fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('\ub2eb\uae30', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700], foregroundColor: Colors.white),
            icon: const Icon(Icons.copy, size: 14),
            label: const Text('\ubcf5\uc0ac'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('\ucf54\ub4dc \ubcf5\uc0ac\ub428!')));
            },
          ),
        ],
      ),
    );
  }

  String _sortLabel(_SortBy s) => switch (s) {
        _SortBy.name   => '\uc774\ub984\uc21c',
        _SortBy.rarity => '\ud76c\uadc0\ub3c4\uc21c',
        _SortBy.date   => '\ub0a0\uc9dc\uc21c',
        _SortBy.stage  => '\ub2e8\uacc4\uc21c',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyCollection extends StatelessWidget {
  const _EmptyCollection();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('\uD83C\uDF31', style: TextStyle(fontSize: 60)),
          SizedBox(height: 16),
          Text('\uc544\uc9c1 \uc218\ud655\ud55c \uc2dd\ubb3c\uc774 \uc5c6\uc2b5\ub2c8\ub2e4',
              style: TextStyle(color: Colors.white54, fontSize: 16)),
          SizedBox(height: 8),
          Text('\ub9cc\uac1c(4\ub2e8\uacc4)\uc5d0 \ub3c4\ub2ec\ud55c \uc2dd\ubb3c\uc744 \uc218\ud655\ud558\uba74\n\ub3c4\uac10\uc5d0 \ucd94\uac00\ub429\ub2c8\ub2e4.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Collection card
// ─────────────────────────────────────────────────────────────────────────────

class _CollectionCard extends StatelessWidget {
  final Plant plant;
  final Map<PlantRarity, Color> rarityColors;
  final Map<PlantRarity, String> rarityLabels;
  final VoidCallback onCodeTap;
  final VoidCallback onSell;

  const _CollectionCard({
    required this.plant,
    required this.rarityColors,
    required this.rarityLabels,
    required this.onCodeTap,
    required this.onSell,
  });

  @override
  Widget build(BuildContext context) {
    final rc = rarityColors[plant.rarity]!;
    final date = DateFormat('MM.dd').format(plant.createdAt);
    final isHolo = plant.rarity == PlantRarity.holographic;

    return GestureDetector(
      onLongPress: onCodeTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isHolo
                ? [
                    const Color(0xFF4A148C),
                    const Color(0xFF1A237E),
                    const Color(0xFF006064),
                  ]
                : [
                    plant.color.withLightness(0.22).toColor(),
                    const Color(0xFF1A2E1A),
                  ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isHolo ? Colors.purple.shade300 : rc.withValues(alpha: 0.5),
              width: isHolo ? 2 : 1.2),
          boxShadow: isHolo
              ? [
                  BoxShadow(
                      color: Colors.purple.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2)
                ]
              : null,
        ),
        child: Column(
          children: [
            // Plant visual
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: ClipRect(
                child: CustomPaint(
                  painter: PlantPainter(plant: plant, animValue: 0.25),
                  size: Size.infinite,
                ),
              ),
              ),
            ),

            // Info footer
            Container(
              padding: const EdgeInsets.fromLTRB(6, 5, 6, 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(15)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (plant.isHybrid)
                        const Text('\uD83E\uDDEC ',
                            style: TextStyle(fontSize: 9)),
                      Flexible(
                        child: Text(plant.species,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(rarityLabels[plant.rarity]!.split(' ').last,
                          style: TextStyle(
                              color: rc,
                              fontSize: 9,
                              fontWeight: FontWeight.w600)),
                      Text(date,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 9)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('길게 누르면 코드 확인',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.20), fontSize: 8)),
                  const SizedBox(height: 6),
                  // Sell button
                  SizedBox(
                    width: double.infinity,
                    height: 24,
                    child: ElevatedButton(
                      onPressed: onSell,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.amber.withValues(alpha: 0.25),
                        foregroundColor: Colors.amber,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        side: BorderSide(
                            color: Colors.amber.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '🪙 ${ShopCatalog.sellPrice(plant.rarity)}',
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
