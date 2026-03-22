import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/game_score.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() =>
      _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<GameScores>? _globalList;
  List<GameScores>? _friendsList;
  bool _loadingGlobal = true;
  bool _loadingFriends = true;
  String _selectedGame = 'total';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadGlobal();
    _loadFriends();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadGlobal() async {
    setState(() => _loadingGlobal = true);
    try {
      final list = await FirestoreService.getGlobalLeaderboard();
      if (!mounted) return;
      setState(() {
        _globalList = list;
        _loadingGlobal = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingGlobal = false);
    }
  }

  Future<void> _loadFriends() async {
    final uid = ref.read(authProvider)?.uid;
    if (uid == null) {
      setState(() => _loadingFriends = false);
      return;
    }
    setState(() => _loadingFriends = true);
    try {
      final list = await FirestoreService.getFriendsLeaderboard(uid);
      if (!mounted) return;
      setState(() {
        _friendsList = list;
        _loadingFriends = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingFriends = false);
    }
  }

  int _getScore(GameScores gs) =>
      _selectedGame == 'total' ? gs.total : (gs.scores[_selectedGame] ?? 0);

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(authProvider)?.uid;
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2E1A),
        foregroundColor: Colors.white,
        title: const Text('🏆 주간 랭킹'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.greenAccent,
          labelColor: Colors.greenAccent,
          unselectedLabelColor: Colors.white54,
          tabs: const [Tab(text: '전체 랭킹'), Tab(text: '친구 랭킹')],
        ),
      ),
      body: Column(
        children: [
          // Game filter chips
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                _Chip(
                  label: '종합',
                  selected: _selectedGame == 'total',
                  onTap: () => setState(() => _selectedGame = 'total'),
                ),
                const SizedBox(width: 6),
                for (final e in GameScores.gameNames.entries) ...[
                  _Chip(
                    label: e.value,
                    selected: _selectedGame == e.key,
                    onTap: () => setState(() => _selectedGame = e.key),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _LeaderboardList(
                  loading: _loadingGlobal,
                  list: _globalList,
                  myUid: myUid,
                  getScore: _getScore,
                  onRefresh: _loadGlobal,
                ),
                _LeaderboardList(
                  loading: _loadingFriends,
                  list: _friendsList,
                  myUid: myUid,
                  getScore: _getScore,
                  onRefresh: _loadFriends,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? Colors.greenAccent.withValues(alpha: 0.2)
              : const Color(0xFF1A2E1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? Colors.greenAccent : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.greenAccent : Colors.white54,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  final bool loading;
  final List<GameScores>? list;
  final String? myUid;
  final int Function(GameScores) getScore;
  final VoidCallback onRefresh;

  const _LeaderboardList({
    required this.loading,
    required this.list,
    required this.myUid,
    required this.getScore,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.greenAccent));
    }
    if (list == null || list!.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('아직 기록이 없어요 🌱',
              style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRefresh,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white),
            child: const Text('새로고침'),
          ),
        ]),
      );
    }

    final sorted = [...list!]..sort((a, b) => getScore(b).compareTo(getScore(a)));

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: Colors.greenAccent,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sorted.length,
        itemBuilder: (_, i) {
          final gs = sorted[i];
          final rank = i + 1;
          final score = getScore(gs);
          final isMe = gs.uid == myUid;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe
                  ? Colors.green.withValues(alpha: 0.15)
                  : const Color(0xFF1A2E1A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: isMe
                      ? Colors.greenAccent.withValues(alpha: 0.4)
                      : Colors.white12),
            ),
            child: Row(children: [
              SizedBox(
                width: 36,
                child: Text(
                  rank == 1
                      ? '🥇'
                      : rank == 2
                          ? '🥈'
                          : rank == 3
                              ? '🥉'
                              : '$rank',
                  style: TextStyle(
                    color: rank <= 3 ? Colors.white : Colors.white54,
                    fontSize: rank <= 3 ? 22 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.green[800],
                backgroundImage: gs.photoUrl != null
                    ? NetworkImage(gs.photoUrl!)
                    : null,
                child: gs.photoUrl == null
                    ? Text(
                        gs.displayName.isNotEmpty
                            ? gs.displayName[0]
                            : '?',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  gs.displayName + (isMe ? ' (나)' : ''),
                  style: TextStyle(
                    color: isMe ? Colors.greenAccent : Colors.white,
                    fontSize: 14,
                    fontWeight:
                        isMe ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              Text(
                '$score',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}
