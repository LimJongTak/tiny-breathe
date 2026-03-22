import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/daily_quest.dart';

import '../../models/user_profile.dart';
import '../../models/plant.dart';
import '../../models/garden_plot.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../viewmodels/garden_viewmodel.dart';
import '../../widgets/plant_painter.dart';
import 'guestbook_screen.dart';

class FriendGardenScreen extends ConsumerStatefulWidget {
  final AppUser friend;
  const FriendGardenScreen({super.key, required this.friend});

  @override
  ConsumerState<FriendGardenScreen> createState() =>
      _FriendGardenScreenState();
}

class _FriendGardenScreenState extends ConsumerState<FriendGardenScreen> {
  List<GardenPlot> _plots = [];
  bool _loading = true;
  bool _error = false;
  bool _giftedToday = false;
  bool _gifting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = false; });
    try {
      final myUid = ref.read(authProvider)?.uid ?? '';
      final data = await FirestoreService.loadGarden(widget.friend.uid);
      final gifted = await FirestoreService.hasGiftedToday(myUid, widget.friend.uid);
      if (!mounted) return;
      final parsed = data != null ? GardenState.fromCloud(data) : null;
      setState(() {
        _plots = parsed?.plots ?? [];
        _giftedToday = gifted;
        _loading = false;
      });
      // Quest: visit friend garden
      ref.read(gardenProvider.notifier)
          .progressQuest(QuestType.visitFriend);
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  Future<void> _sendWaterGift() async {
    final me = ref.read(authProvider);
    if (me == null) return;
    setState(() => _gifting = true);
    try {
      await FirestoreService.sendWaterGift(
        fromUid: me.uid,
        fromNickname: me.nickname ?? me.displayName,
        toUid: widget.friend.uid,
      );
      if (!mounted) return;
      setState(() { _giftedToday = true; _gifting = false; });
      ref.read(gardenProvider.notifier).unlockWaterGiftAchievement();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            '💧 ${widget.friend.nickname ?? widget.friend.displayName}님의 식물에 물을 선물했어요!')),
      );
    } catch (_) {
      if (mounted) setState(() => _gifting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final friend = widget.friend;
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2E1A),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${friend.nickname ?? friend.displayName}의 정원',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(friend.displayName,
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded,
                color: Colors.white70),
            tooltip: '방명록',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GuestbookScreen(
                  owner: friend,
                  isOwner: false,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _gifting
                ? const SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.lightBlue, strokeWidth: 2))
                : ElevatedButton.icon(
                    onPressed: _giftedToday ? null : _sendWaterGift,
                    icon: const Icon(Icons.water_drop_rounded, size: 16),
                    label: Text(_giftedToday ? '오늘 선물함' : '물 선물'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _giftedToday ? Colors.grey[700] : Colors.lightBlue[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.greenAccent))
          : _error
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          color: Colors.white38, size: 48),
                      const SizedBox(height: 12),
                      const Text('정원을 불러올 수 없어요',
                          style: TextStyle(color: Colors.white54)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _load,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white),
                        child: const Text('재시도'),
                      ),
                    ],
                  ),
                )
              : _plots.isEmpty
                  ? const Center(
                      child: Text('아직 정원이 없어요 🌱',
                          style: TextStyle(color: Colors.white38)))
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.70,
                      ),
                      itemCount: _plots.length,
                      itemBuilder: (_, i) =>
                          _ReadOnlyPlotCard(plot: _plots[i]),
                    ),
    );
  }
}

// ── Read-only plot card ────────────────────────────────────────────────────

class _ReadOnlyPlotCard extends StatelessWidget {
  final GardenPlot plot;
  const _ReadOnlyPlotCard({required this.plot});

  static const _stageLabels = ['씨앗', '새싹', '모종', '청년', '만개 🌸'];
  static const Map<PlantRarity, Color> _rc = {
    PlantRarity.holographic: Color(0xFFCE93D8),
    PlantRarity.rare:        Color(0xFFFFAB91),
    PlantRarity.uncommon:    Color(0xFF80CBC4),
    PlantRarity.common:      Color(0xFFA5D6A7),
  };

  @override
  Widget build(BuildContext context) {
    final plant = plot.plant;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6D4C41), Color(0xFF4E342E)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3E2723), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          children: [
            if (plant != null && plant.droughtSince != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 3),
                color: Colors.red.withValues(alpha: 0.80),
                child: const Text('🥀 시들어요',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
              )
            else if (plant != null && plant.growthStage == 4)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 3),
                color: Colors.amber.withValues(alpha: 0.85),
                child: const Text('✨ 만개',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black87, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            Expanded(
              flex: 5,
              child: plant != null
                  ? CustomPaint(
                      painter: PlantPainter(plant: plant, animValue: 0.0),
                      size: Size.infinite)
                  : const Center(
                      child: Icon(Icons.grass_rounded,
                          color: Colors.white12, size: 36)),
            ),
            if (plant != null)
              Container(
                padding: const EdgeInsets.fromLTRB(8, 5, 8, 7),
                color: Colors.black.withValues(alpha: 0.45),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plant.displayName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Row(children: [
                      Text(_stageLabels[plant.growthStage],
                          style: TextStyle(
                              color: _rc[plant.rarity],
                              fontSize: 9)),
                      const Spacer(),
                      Icon(Icons.water_drop,
                          color: plant.hydration > 50
                              ? Colors.lightBlue
                              : plant.hydration > 25
                                  ? Colors.orange
                                  : Colors.red,
                          size: 9),
                      const SizedBox(width: 2),
                      Text('${plant.hydration.toInt()}%',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 9)),
                    ]),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
