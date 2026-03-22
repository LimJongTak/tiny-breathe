import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/achievement.dart';
import '../viewmodels/garden_viewmodel.dart';

class AchievementScreen extends ConsumerWidget {
  const AchievementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gardenProvider);
    final achievements = state.achievements.isEmpty
        ? Achievement.catalog()
        : state.achievements;

    final unlocked = achievements.where((a) => a.unlocked).length;
    final total = achievements.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2E1A),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🏅 업적',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            Text('$unlocked / $total 달성',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 11)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Progress summary
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2E1A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('달성 현황',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                    Text('$unlocked / $total',
                        style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: total > 0 ? unlocked / total : 0,
                    minHeight: 10,
                    backgroundColor: Colors.white12,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
          ),

          // Achievement grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.3,
              ),
              itemCount: achievements.length,
              itemBuilder: (_, i) =>
                  _AchievementCard(achievement: achievements[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Achievement achievement;
  const _AchievementCard({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked
              ? Colors.amber.withValues(alpha: 0.6)
              : Colors.white12,
          width: unlocked ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Emoji with lock overlay
            Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  unlocked ? achievement.emoji : '🔒',
                  style: TextStyle(
                    fontSize: 32,
                    color: unlocked ? null : Colors.white38,
                  ),
                ),
                if (unlocked)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check,
                          color: Colors.black, size: 10),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              achievement.title,
              style: TextStyle(
                color: unlocked ? Colors.white : Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              achievement.description,
              style: TextStyle(
                color:
                    unlocked ? Colors.white54 : Colors.white24,
                fontSize: 9,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (unlocked && achievement.unlockedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatDate(achievement.unlockedAt!),
                style: const TextStyle(
                    color: Colors.amber, fontSize: 8),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
}
