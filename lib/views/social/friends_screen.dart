import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import 'leaderboard_screen.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _ctrl = TextEditingController();
  List<AppUser> _friends = [];
  List<AppUser> _searchResults = [];
  Set<String> _friendIds = {};
  bool _loadingFriends = true;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    final uid = ref.read(authProvider)?.uid;
    if (uid == null) {
      setState(() => _loadingFriends = false);
      return;
    }
    setState(() => _loadingFriends = true);
    final friends = await FirestoreService.getFriends(uid);
    if (!mounted) return;
    setState(() {
      _friends = friends;
      _friendIds = friends.map((f) => f.uid).toSet();
      _loadingFriends = false;
    });
  }

  Future<void> _search() async {
    final query = _ctrl.text.trim();
    if (query.isEmpty) return;
    setState(() => _searching = true);
    final results = await FirestoreService.searchUsers(query);
    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _searching = false;
    });
  }

  Future<void> _addFriend(AppUser friend) async {
    final uid = ref.read(authProvider)?.uid;
    if (uid == null) return;
    await FirestoreService.addFriend(uid, friend.uid);
    setState(() => _friendIds.add(friend.uid));
    _loadFriends();
  }

  Future<void> _removeFriend(String friendUid) async {
    final uid = ref.read(authProvider)?.uid;
    if (uid == null) return;
    await FirestoreService.removeFriend(uid, friendUid);
    setState(() {
      _friends.removeWhere((f) => f.uid == friendUid);
      _friendIds.remove(friendUid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2E1A),
        foregroundColor: Colors.white,
        title: const Text('👥 친구'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
            ),
            icon: const Icon(Icons.leaderboard_rounded, color: Colors.amber),
            label: const Text('랭킹', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
      body: user == null
          ? const Center(
              child: Text('로그인이 필요해요',
                  style: TextStyle(color: Colors.white54)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Search bar
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: '닉네임으로 친구 검색',
                        hintStyle:
                            const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF1A2E1A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(Icons.search,
                            color: Colors.white38),
                      ),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _search,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _searching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('검색'),
                  ),
                ]),
                if (_searchResults.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('검색 결과',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 8),
                  ..._searchResults
                      .where((u) => u.uid != user.uid)
                      .map((u) => _UserTile(
                            user: u,
                            isFriend: _friendIds.contains(u.uid),
                            onAdd: () => _addFriend(u),
                            onRemove: () => _removeFriend(u.uid),
                          )),
                ],
                const SizedBox(height: 20),
                Text(
                  '친구 ${_friends.length}명',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                if (_loadingFriends)
                  const Center(
                      child: CircularProgressIndicator(
                          color: Colors.greenAccent))
                else if (_friends.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      '아직 친구가 없어요 🌱\n위에서 검색해서 추가해보세요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38),
                    ),
                  )
                else
                  ..._friends.map((f) => _UserTile(
                        user: f,
                        isFriend: true,
                        onAdd: null,
                        onRemove: () => _removeFriend(f.uid),
                      )),
              ],
            ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final AppUser user;
  final bool isFriend;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;

  const _UserTile({
    required this.user,
    required this.isFriend,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.green[800],
          backgroundImage: user.photoUrl != null
              ? NetworkImage(user.photoUrl!)
              : null,
          child: user.photoUrl == null
              ? Text(
                  user.displayName.isNotEmpty ? user.displayName[0] : '?',
                  style: const TextStyle(color: Colors.white))
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(user.displayName,
              style: const TextStyle(color: Colors.white, fontSize: 15)),
        ),
        if (isFriend)
          TextButton(
            onPressed: onRemove,
            child: const Text('삭제',
                style: TextStyle(color: Colors.redAccent)),
          )
        else
          ElevatedButton(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('추가'),
          ),
      ]),
    );
  }
}
