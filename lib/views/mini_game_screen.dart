import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_level.dart';
import '../viewmodels/garden_viewmodel.dart';
import 'games/tap_game.dart';
import 'social/leaderboard_screen.dart';
import 'games/drop_game.dart';
import 'games/weed_game.dart';
import 'games/catch_game.dart';
import 'games/dodge_game.dart';

class MiniGameScreen extends ConsumerWidget {
  const MiniGameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gardenProvider);
    final tickets = state.gameTickets;

    void playGame(Widget Function(BuildContext) builder) {
      final ok = ref.read(gardenProvider.notifier).deductTicket();
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎮 게임 티켓이 없어요! 10분마다 1개씩 충전돼요.'),
            backgroundColor: Color(0xFF2E1A0A),
          ),
        );
        return;
      }
      Navigator.push(context, MaterialPageRoute(builder: builder));
    }

    final games = [
      _GameInfo(
        title: '🌱 땅파기',
        subtitle: '흙을 파서 씨앗을 발견해요',
        description: '잔디 버튼을 빠르게 탭해서 게이지를 채우세요!\n게이지 가득 = 씨앗 1개. 시간이 지날수록 어려워져요.',
        difficulty: '쉬움',
        diffColor: Colors.green,
        builder: (_) => const TapGame(),
      ),
      _GameInfo(
        title: '💧 물방울 잡기',
        subtitle: '떨어지는 물방울을 잡으세요',
        description: '20초 동안 하늘에서 떨어지는 물방울을 탭해서 잡으세요!\n후반부엔 속도가 매우 빨라져요.',
        difficulty: '보통',
        diffColor: Colors.blue,
        builder: (_) => const DropGame(),
      ),
      _GameInfo(
        title: '🌿 잡초뽑기',
        subtitle: '잡초만 골라서 뽑아요',
        description: '20초 동안 잡초(🌿)만 빠르게 탭해서 뽑으세요!\n꽃(🌸)을 실수로 뽑으면 점수가 깎여요.',
        difficulty: '어려움',
        diffColor: Colors.orange,
        builder: (_) => const WeedGame(),
      ),
      _GameInfo(
        title: '🦟 벌레 퇴치',
        subtitle: '날아다니는 벌레를 잡아요',
        description: '조이스틱으로 이동해서 날아다니는 벌레를 잡으세요!\n30초 동안 최대한 많이 잡아요.',
        difficulty: '보통',
        diffColor: Colors.lightGreen,
        builder: (_) => const CatchGame(),
      ),
      _GameInfo(
        title: '🐝 벌 피하기',
        subtitle: '날아오는 벌을 피하세요',
        description: '조이스틱으로 이동해서 벌을 피하세요!\n❤️ 3번 맞으면 게임오버. 30초 생존이 목표!',
        difficulty: '어려움',
        diffColor: Colors.amber,
        builder: (_) => const DodgeGame(),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2E1A),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🎮 씨앗 미니게임',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('보관함: ${state.totalSeeds}개',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_rounded, color: Colors.amber),
            tooltip: '랭킹',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _DailyBoxCard(),
          const SizedBox(height: 12),
          // Ticket display
          _TicketBar(tickets: tickets, regenIn: state.ticketRegenIn),
          const SizedBox(height: 16),
          const _SectionLabel('🎮 미니게임'),
          const SizedBox(height: 10),
          ...games.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _GameCard(
                  info: g,
                  hasTicket: tickets > 0,
                  onTap: () => playGame(g.builder),
                ),
              )),
        ],
      ),
    );
  }
}

class _GameInfo {
  final String title, subtitle, description, difficulty;
  final Color diffColor;
  final Widget Function(BuildContext) builder;

  const _GameInfo({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.difficulty,
    required this.diffColor,
    required this.builder,
  });
}

class _GameCard extends StatelessWidget {
  final _GameInfo info;
  final bool hasTicket;
  final VoidCallback onTap;
  const _GameCard({required this.info, required this.hasTicket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: hasTicket ? 1.0 : 0.55,
        child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2E1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Text(info.title.split(' ').first,
                style: const TextStyle(fontSize: 40)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(info.title.split(' ').skip(1).join(' '),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(info.subtitle,
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text(info.description,
                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: info.diffColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: info.diffColor),
                      ),
                      child: Text(info.difficulty,
                          style: TextStyle(
                              color: info.diffColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    const Text('🌱 씨앗 최대 3개 획득',
                        style: TextStyle(color: Colors.white38, fontSize: 10)),
                  ]),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white24, size: 16),
          ],
        ),
      ),
    ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ticket bar
// ─────────────────────────────────────────────────────────────────────────────

class _TicketBar extends StatefulWidget {
  final int tickets;
  final Duration regenIn;
  const _TicketBar({required this.tickets, required this.regenIn});

  @override
  State<_TicketBar> createState() => _TicketBarState();
}

class _TicketBarState extends State<_TicketBar> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _fmtRegen(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (m > 0) return '$m분 ${s.toString().padLeft(2, '0')}초';
    return '$s초';
  }

  @override
  Widget build(BuildContext context) {
    const max = GardenState.maxGameTickets;
    final isFull = widget.tickets >= max;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          // Ticket icons
          Row(
            children: List.generate(max, (i) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                i < widget.tickets ? '🎮' : '⬜',
                style: const TextStyle(fontSize: 20),
              ),
            )),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '게임 티켓  ${widget.tickets} / $max',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
                if (!isFull) ...[
                  const SizedBox(height: 2),
                  Text(
                    '다음 충전까지: ${_fmtRegen(widget.regenIn)}',
                    style: const TextStyle(color: Colors.amber, fontSize: 11),
                  ),
                ] else
                  const Text(
                    '충전 완료!',
                    style: TextStyle(color: Colors.greenAccent, fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Daily box card  (3-hour cooldown)
// ─────────────────────────────────────────────────────────────────────────────

class _DailyBoxCard extends ConsumerStatefulWidget {
  const _DailyBoxCard();

  @override
  ConsumerState<_DailyBoxCard> createState() => _DailyBoxCardState();
}

class _DailyBoxCardState extends ConsumerState<_DailyBoxCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Rebuild every second so countdown stays live
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '$h시간 ${m.toString().padLeft(2, '0')}분 ${s.toString().padLeft(2, '0')}초';
    if (m > 0) return '$m분 ${s.toString().padLeft(2, '0')}초';
    return '$s초';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gardenProvider);
    final canClaim = state.canClaimBox;
    final remaining = state.nextBoxIn;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: canClaim
              ? [const Color(0xFF1B4020), const Color(0xFF0D3030)]
              : [const Color(0xFF1A1A1A), const Color(0xFF141414)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: canClaim
              ? Colors.greenAccent.withValues(alpha: 0.5)
              : Colors.white12,
        ),
      ),
      child: Row(children: [
        Text(
          canClaim ? '🎁' : '📦',
          style: const TextStyle(fontSize: 44),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('무료 씨앗 상자',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              if (canClaim)
                const Text('지금 받을 수 있어요! 🌱',
                    style: TextStyle(color: Colors.greenAccent, fontSize: 12))
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('다음 받기까지',
                        style: TextStyle(color: Colors.white38, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      _fmt(remaining),
                      style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 15,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              const SizedBox(height: 6),
              const Text('랜덤 씨앗 1~2개  •  3시간마다 1회',
                  style: TextStyle(color: Colors.white24, fontSize: 10)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: canClaim
              ? () {
                  final seeds =
                      ref.read(gardenProvider.notifier).claimDailyBox();
                  if (seeds == null) return;
                  _showBoxResult(context, seeds);
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[700],
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.white10,
            disabledForegroundColor: Colors.white24,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(
            canClaim ? '열기!' : '대기중',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
      ]),
    );
  }

  void _showBoxResult(BuildContext context, Map<String, int> seeds) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2E1A),
        title: const Text('🎁 상자 오픈!',
            style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 20,
                fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('획득한 씨앗:',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 12),
            ...seeds.entries.map((e) {
              final info =
                  GameLevels.seeds.where((s) => s.name == e.key).firstOrNull;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('${info?.emoji ?? "🌱"} ${e.key}  x${e.value}',
                    style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              );
            }),
            const SizedBox(height: 8),
            const Text('3시간 후에 다시 받을 수 있어요!',
                style: TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

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
