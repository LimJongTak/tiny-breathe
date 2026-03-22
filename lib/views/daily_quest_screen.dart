import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/daily_quest.dart';
import '../services/auth_service.dart';
import '../viewmodels/garden_viewmodel.dart';

class DailyQuestScreen extends ConsumerWidget {
  const DailyQuestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gardenProvider);
    final quests = state.dailyQuests.isEmpty
        ? DailyQuest.defaults()
        : state.dailyQuests;

    final completed = quests.where((q) => q.completed).length;
    final total = quests.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2E1A),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📋 일일 퀘스트',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('$completed / $total 완료',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 11)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Overall progress bar
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2E1A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('오늘의 퀘스트',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                    Text('$completed / $total',
                        style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: total > 0 ? completed / total : 0,
                    minHeight: 10,
                    backgroundColor: Colors.white12,
                    color: Colors.greenAccent,
                  ),
                ),
                if (completed == total && total > 0) ...[
                  const SizedBox(height: 10),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🎉 모든 퀘스트 완료!',
                          style: TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Quest list
          Expanded(
            child: ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16),
              itemCount: quests.length,
              itemBuilder: (_, i) => _QuestCard(
                quest: quests[i],
                onClaim: () => _claimReward(context, ref, quests[i].id),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _claimReward(
      BuildContext context, WidgetRef ref, String questId) {
    final result =
        ref.read(gardenProvider.notifier).claimQuestReward(questId);
    if (result == null) return;

    final uid = ref.read(authProvider)?.uid;
    if (uid != null) ref.read(gardenProvider.notifier).saveToCloud(uid);

    final coins = result['coins']!;
    final seeds = result['seeds']!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🎁 보상 수령! 🪙 $coins코인${seeds > 0 ? ' + 🌱 씨앗 ${seeds}개' : ''}',
        ),
        backgroundColor: const Color(0xFF2E4028),
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  final DailyQuest quest;
  final VoidCallback onClaim;

  const _QuestCard({required this.quest, required this.onClaim});

  @override
  Widget build(BuildContext context) {
    final done = quest.completed;
    final claimed = quest.claimed;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: claimed
              ? Colors.white12
              : done
                  ? Colors.greenAccent.withValues(alpha: 0.5)
                  : Colors.white12,
          width: done && !claimed ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(quest.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quest.title,
                      style: TextStyle(
                        color:
                            claimed ? Colors.white38 : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        decoration: claimed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      quest.description,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Reward
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (quest.rewardCoins > 0)
                    Text('🪙 ${quest.rewardCoins}',
                        style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  if (quest.rewardSeeds > 0)
                    Text('🌱 ×${quest.rewardSeeds}',
                        style: const TextStyle(
                            color: Colors.greenAccent, fontSize: 12)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress bar + action
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: quest.fraction,
                      minHeight: 6,
                      backgroundColor: Colors.white12,
                      color: claimed
                          ? Colors.white24
                          : done
                              ? Colors.greenAccent
                              : Colors.lightBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${quest.progress.clamp(0, quest.target)} / ${quest.target}',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (claimed)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('완료',
                    style: TextStyle(
                        color: Colors.white38, fontSize: 12)),
              )
            else if (done)
              ElevatedButton(
                onPressed: onClaim,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('수령!',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Text('진행 중',
                    style: TextStyle(
                        color: Colors.white54, fontSize: 12)),
              ),
          ]),
        ],
      ),
    );
  }
}
