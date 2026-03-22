import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import 'friend_garden_screen.dart';
import 'leaderboard_screen.dart';

// ── Relationship state from my perspective ────────────────────────────────────
enum _Rel { none, pendingSent, pendingReceived, friend }

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _ctrl = TextEditingController();

  // Loaded data
  List<AppUser> _friends = [];
  List<Map<String, dynamic>> _incoming = [];   // pending requests TO me
  List<Map<String, dynamic>> _sent = [];       // pending requests FROM me
  List<AppUser> _searchResults = [];

  bool _loadingFriends = true;
  bool _searching = false;
  bool _loadError = false;

  // uid → _Rel cache for quick lookup in search results
  final Map<String, _Rel> _relCache = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final uid = ref.read(authProvider)?.uid;
    if (uid == null) {
      setState(() { _loadingFriends = false; });
      return;
    }
    setState(() { _loadingFriends = true; _loadError = false; });
    try {
      final results = await Future.wait([
        FirestoreService.getFriends(uid),
        FirestoreService.getPendingIncomingRequests(uid),
        FirestoreService.getSentPendingRequests(uid),
      ]);

      final friends   = results[0] as List<AppUser>;
      final incoming  = results[1] as List<Map<String, dynamic>>;
      final sent      = results[2] as List<Map<String, dynamic>>;

      final cache = <String, _Rel>{};
      for (final f in friends)  { cache[f.uid] = _Rel.friend; }
      for (final r in incoming) { cache[r['fromUid'] as String] = _Rel.pendingReceived; }
      for (final r in sent)     { cache[r['toUid'] as String] = _Rel.pendingSent; }

      if (!mounted) return;
      setState(() {
        _friends   = friends;
        _incoming  = incoming;
        _sent      = sent;
        _relCache  ..clear() ..addAll(cache);
        _loadingFriends = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loadingFriends = false; _loadError = true; });
    }
  }

  Future<void> _search() async {
    final query = _ctrl.text.trim();
    if (query.isEmpty) return;
    setState(() { _searching = true; });
    try {
      final results = await FirestoreService.searchUsers(query);
      if (!mounted) return;
      setState(() { _searchResults = results; _searching = false; });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  // ── Friend request actions ─────────────────────────────────────────────────

  Future<void> _sendRequest(AppUser to) async {
    final me = ref.read(authProvider);
    if (me == null) return;
    await FirestoreService.sendFriendRequest(
      fromUid: me.uid,
      toUid: to.uid,
      fromNickname: me.nickname ?? me.displayName,
      fromDisplayName: me.displayName,
      fromPhotoUrl: me.photoUrl,
    );
    setState(() => _relCache[to.uid] = _Rel.pendingSent);
    _loadAll();
  }

  Future<void> _acceptRequest(Map<String, dynamic> req) async {
    final me = ref.read(authProvider);
    if (me == null) return;
    await FirestoreService.acceptFriendRequest(
      requestId: req['id'] as String,
      myUid: me.uid,
      friendUid: req['fromUid'] as String,
    );
    _loadAll();
  }

  Future<void> _rejectRequest(Map<String, dynamic> req) async {
    await FirestoreService.rejectFriendRequest(req['id'] as String);
    _loadAll();
  }

  Future<void> _cancelRequest(Map<String, dynamic> req) async {
    await FirestoreService.cancelFriendRequest(req['id'] as String);
    setState(() => _relCache[req['toUid'] as String] = _Rel.none);
    _loadAll();
  }

  Future<void> _removeFriend(AppUser friend) async {
    final uid = ref.read(authProvider)?.uid;
    if (uid == null) return;
    await FirestoreService.removeFriend(uid, friend.uid);
    setState(() {
      _friends.removeWhere((f) => f.uid == friend.uid);
      _relCache[friend.uid] = _Rel.none;
    });
  }

  void _visitGarden(AppUser friend) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FriendGardenScreen(friend: friend)),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  _Rel _relOf(String uid) => _relCache[uid] ?? _Rel.none;

  Map<String, dynamic>? _sentReqTo(String uid) =>
      _sent.where((r) => r['toUid'] == uid).firstOrNull;

  Map<String, dynamic>? _incomingReqFrom(String uid) =>
      _incoming.where((r) => r['fromUid'] == uid).firstOrNull;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authProvider);
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
      body: me == null
          ? const Center(
              child: Text('로그인이 필요해요',
                  style: TextStyle(color: Colors.white54)))
          : _loadingFriends
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.greenAccent))
              : _loadError
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_off_rounded,
                              color: Colors.white38, size: 48),
                          const SizedBox(height: 12),
                          const Text('불러오기 실패',
                              style: TextStyle(color: Colors.white54)),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _loadAll,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[700],
                                foregroundColor: Colors.white),
                            child: const Text('재시도'),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // ── Search ───────────────────────────────────────
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
                            onPressed: _searching ? null : _search,
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

                        // ── Search results ───────────────────────────────
                        if (_searchResults.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const _SectionHeader('검색 결과'),
                          ..._searchResults
                              .where((u) => u.uid != me.uid)
                              .map((u) {
                            final rel = _relOf(u.uid);
                            return _SearchResultTile(
                              user: u,
                              rel: rel,
                              onSendRequest: rel == _Rel.none
                                  ? () => _sendRequest(u)
                                  : null,
                              onVisit: rel == _Rel.friend
                                  ? () => _visitGarden(u)
                                  : null,
                              onCancel: rel == _Rel.pendingSent
                                  ? () {
                                      final req = _sentReqTo(u.uid);
                                      if (req != null) _cancelRequest(req);
                                    }
                                  : null,
                              onAccept: rel == _Rel.pendingReceived
                                  ? () {
                                      final req = _incomingReqFrom(u.uid);
                                      if (req != null) _acceptRequest(req);
                                    }
                                  : null,
                              onReject: rel == _Rel.pendingReceived
                                  ? () {
                                      final req = _incomingReqFrom(u.uid);
                                      if (req != null) _rejectRequest(req);
                                    }
                                  : null,
                            );
                          }),
                        ],

                        // ── Incoming requests ────────────────────────────
                        if (_incoming.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _SectionHeader('친구 요청 ${_incoming.length}건'),
                          ..._incoming.map((req) => _IncomingRequestTile(
                                req: req,
                                onAccept: () => _acceptRequest(req),
                                onReject: () => _rejectRequest(req),
                              )),
                        ],

                        // ── Sent (pending) requests ──────────────────────
                        if (_sent.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const _SectionHeader('보낸 요청'),
                          ..._sent.map((req) => _SentRequestTile(
                                req: req,
                                onCancel: () => _cancelRequest(req),
                              )),
                        ],

                        // ── Friends list ─────────────────────────────────
                        const SizedBox(height: 20),
                        _SectionHeader('친구 ${_friends.length}명'),
                        if (_friends.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              '아직 친구가 없어요 🌱\n위에서 검색해서 추가해보세요!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white38),
                            ),
                          )
                        else
                          ..._friends.map((f) => _FriendTile(
                                friend: f,
                                onVisit: () => _visitGarden(f),
                                onRemove: () => _removeFriend(f),
                              )),
                      ],
                    ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(text,
          style: const TextStyle(color: Colors.white54, fontSize: 12)),
    );
  }
}

// ── Base tile decoration ───────────────────────────────────────────────────────

class _TileShell extends StatelessWidget {
  final Widget child;
  const _TileShell({required this.child});

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
      child: child,
    );
  }
}

// ── Avatar helper ──────────────────────────────────────────────────────────────

class _UserAvatar extends StatelessWidget {
  final AppUser user;
  const _UserAvatar({required this.user});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.green[800],
      backgroundImage:
          user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
      child: user.photoUrl == null
          ? Text(
              user.displayName.isNotEmpty ? user.displayName[0] : '?',
              style: const TextStyle(color: Colors.white))
          : null,
    );
  }
}

// ── Friend tile ────────────────────────────────────────────────────────────────

class _FriendTile extends StatelessWidget {
  final AppUser friend;
  final VoidCallback onVisit;
  final VoidCallback onRemove;

  const _FriendTile({
    required this.friend,
    required this.onVisit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return _TileShell(
      child: Row(children: [
        _UserAvatar(user: friend),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(friend.nickname != null
                      ? '@${friend.nickname}'
                      : friend.displayName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              if (friend.nickname != null)
                Text(friend.displayName,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: onVisit,
          icon: const Icon(Icons.park_rounded, size: 14),
          label: const Text('정원 방문', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[800],
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(width: 6),
        TextButton(
          onPressed: onRemove,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          ),
          child: const Text('삭제',
              style: TextStyle(color: Colors.redAccent, fontSize: 12)),
        ),
      ]),
    );
  }
}

// ── Incoming request tile ─────────────────────────────────────────────────────

class _IncomingRequestTile extends StatelessWidget {
  final Map<String, dynamic> req;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _IncomingRequestTile({
    required this.req,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final nick = req['fromNickname'] as String?;
    final name = req['fromDisplayName'] as String? ?? '';
    final photo = req['fromPhotoUrl'] as String?;
    final display = nick != null ? '@$nick' : name;

    return _TileShell(
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.green[800],
          backgroundImage: photo != null ? NetworkImage(photo) : null,
          child: photo == null
              ? Text(name.isNotEmpty ? name[0] : '?',
                  style: const TextStyle(color: Colors.white))
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(display,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const Text('친구 요청을 보냈어요',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: onAccept,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[700],
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('수락', style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(width: 6),
        OutlinedButton(
          onPressed: onReject,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('거절', style: TextStyle(fontSize: 12)),
        ),
      ]),
    );
  }
}

// ── Sent request tile ──────────────────────────────────────────────────────────

class _SentRequestTile extends StatelessWidget {
  final Map<String, dynamic> req;
  final VoidCallback onCancel;

  const _SentRequestTile({required this.req, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final nick = req['toNickname'] as String?;
    final name = req['toDisplayName'] as String? ?? (req['toUid'] as String);
    final display = nick != null ? '@$nick' : name;

    return _TileShell(
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.blueGrey[700],
          child: Text(display.isNotEmpty ? display[0] : '?',
              style: const TextStyle(color: Colors.white)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(display,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const Text('요청 대기 중...',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ),
        TextButton(
          onPressed: onCancel,
          child: const Text('취소',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
        ),
      ]),
    );
  }
}

// ── Search result tile ─────────────────────────────────────────────────────────

class _SearchResultTile extends StatelessWidget {
  final AppUser user;
  final _Rel rel;
  final VoidCallback? onSendRequest;
  final VoidCallback? onVisit;
  final VoidCallback? onCancel;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const _SearchResultTile({
    required this.user,
    required this.rel,
    this.onSendRequest,
    this.onVisit,
    this.onCancel,
    this.onAccept,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return _TileShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _UserAvatar(user: user),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.nickname != null
                        ? '@${user.nickname}'
                        : user.displayName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                  if (user.nickname != null)
                    Text(user.displayName,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            _RelBadge(rel: rel),
          ]),
          const SizedBox(height: 8),
          _RelActions(
            rel: rel,
            onSendRequest: onSendRequest,
            onVisit: onVisit,
            onCancel: onCancel,
            onAccept: onAccept,
            onReject: onReject,
          ),
        ],
      ),
    );
  }
}

class _RelBadge extends StatelessWidget {
  final _Rel rel;
  const _RelBadge({required this.rel});

  @override
  Widget build(BuildContext context) {
    return switch (rel) {
      _Rel.friend => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.greenAccent),
          ),
          child: const Text('친구',
              style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
        ),
      _Rel.pendingSent => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange),
          ),
          child: const Text('대기 중',
              style: TextStyle(color: Colors.orange, fontSize: 11)),
        ),
      _Rel.pendingReceived => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.lightBlue),
          ),
          child: const Text('요청 받음',
              style: TextStyle(color: Colors.lightBlue, fontSize: 11)),
        ),
      _Rel.none => const SizedBox.shrink(),
    };
  }
}

class _RelActions extends StatelessWidget {
  final _Rel rel;
  final VoidCallback? onSendRequest;
  final VoidCallback? onVisit;
  final VoidCallback? onCancel;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const _RelActions({
    required this.rel,
    this.onSendRequest,
    this.onVisit,
    this.onCancel,
    this.onAccept,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return switch (rel) {
      _Rel.none => SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onSendRequest,
            icon: const Icon(Icons.person_add_rounded, size: 16),
            label: const Text('친구 요청'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      _Rel.pendingSent => SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white38,
              side: const BorderSide(color: Colors.white24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('요청 취소'),
          ),
        ),
      _Rel.pendingReceived => Row(children: [
          Expanded(
            child: ElevatedButton(
              onPressed: onAccept,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('수락'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: onReject,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('거절'),
            ),
          ),
        ]),
      _Rel.friend => Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onVisit,
              icon: const Icon(Icons.park_rounded, size: 14),
              label: const Text('정원 방문'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[800],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ]),
    };
  }
}
