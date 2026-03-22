import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import '../models/game_score.dart';

abstract final class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  // ── Garden ────────────────────────────────────────────────────────────────

  static Future<void> saveGarden(String uid, Map<String, dynamic> data) async {
    await _db.collection('gardens').doc(uid).set({
      ...data,
      'lastSaved': FieldValue.serverTimestamp(),
    });
  }

  static Future<Map<String, dynamic>?> loadGarden(String uid) async {
    final doc = await _db.collection('gardens').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  // ── User profile ──────────────────────────────────────────────────────────

  static Future<AppUser?> loadUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromJson({'uid': uid, ...doc.data()!});
  }

  static Future<void> saveUserProfile(AppUser user) async {
    await _db.collection('users').doc(user.uid).set({
      'displayName': user.displayName,
      'photoUrl': user.photoUrl,
      'provider': user.provider,
      if (user.nickname != null) 'nickname': user.nickname,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── Nickname ───────────────────────────────────────────────────────────────

  /// 닉네임 중복 여부 확인. true = 사용 가능
  static Future<bool> isNicknameAvailable(String nickname) async {
    final snap = await _db
        .collection('users')
        .where('nickname', isEqualTo: nickname)
        .limit(1)
        .get();
    return snap.docs.isEmpty;
  }

  /// 닉네임 저장 (고유값으로 저장)
  static Future<void> setNickname(String uid, String nickname) async {
    await _db.collection('users').doc(uid).set(
      {'nickname': nickname, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  // ── Friends ───────────────────────────────────────────────────────────────

  /// 닉네임으로 유저 검색
  static Future<List<AppUser>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    final snap = await _db
        .collection('users')
        .where('nickname', isGreaterThanOrEqualTo: query)
        .where('nickname', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(10)
        .get();
    return snap.docs
        .map((d) => AppUser.fromJson({'uid': d.id, ...d.data()}))
        .toList();
  }

  static Future<void> addFriend(String uid, String friendUid) async {
    await _db.collection('users').doc(uid).set(
      {'friendIds': FieldValue.arrayUnion([friendUid])},
      SetOptions(merge: true),
    );
  }

  static Future<void> removeFriend(String uid, String friendUid) async {
    await _db.collection('users').doc(uid).set(
      {'friendIds': FieldValue.arrayRemove([friendUid])},
      SetOptions(merge: true),
    );
  }

  static Future<List<String>> getFriendIds(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return (doc.data()?['friendIds'] as List?)?.cast<String>() ?? [];
  }

  static Future<List<AppUser>> getFriends(String uid) async {
    final ids = await getFriendIds(uid);
    if (ids.isEmpty) return [];
    final docs = await Future.wait(
      ids.map((id) => _db.collection('users').doc(id).get()),
    );
    return docs
        .where((d) => d.exists)
        .map((d) => AppUser.fromJson({'uid': d.id, ...d.data()!}))
        .toList();
  }

  // ── Scores ────────────────────────────────────────────────────────────────

  static Future<void> submitScore(
    String uid,
    String displayName,
    String? photoUrl,
    String gameType,
    int score,
  ) async {
    final weekKey = currentWeekKey();
    final ref = _db.collection('scores').doc(uid);

    await _db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      final data = doc.exists ? doc.data()! : <String, dynamic>{};
      final storedWeek = (data['weekKey'] as num?)?.toInt() ?? 0;

      final Map<String, dynamic> scores = storedWeek == weekKey
          ? Map<String, dynamic>.from(data['scores'] as Map? ?? {})
          : {};

      final current = (scores[gameType] as num?)?.toInt() ?? 0;
      if (storedWeek == weekKey && score <= current) return;

      scores[gameType] = score;
      final total =
          scores.values.fold<int>(0, (a, b) => a + (b as num).toInt());

      tx.set(ref, {
        'uid': uid,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'weekKey': weekKey,
        'scores': scores,
        'total': total,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<List<GameScores>> getGlobalLeaderboard(
      {int limit = 50}) async {
    final snap = await _db
        .collection('scores')
        .where('weekKey', isEqualTo: currentWeekKey())
        .orderBy('total', descending: true)
        .limit(limit)
        .get();
    return snap.docs
        .map((d) => GameScores.fromJson({'uid': d.id, ...d.data()}))
        .toList();
  }

  static Future<List<GameScores>> getFriendsLeaderboard(String uid) async {
    final ids = await getFriendIds(uid);
    final allIds = <String>{...ids, uid};
    final weekKey = currentWeekKey();

    final docs = await Future.wait(
      allIds.map((id) => _db.collection('scores').doc(id).get()),
    );
    final list = docs
        .where((d) => d.exists && (d.data()?['weekKey'] as num?)?.toInt() == weekKey)
        .map((d) => GameScores.fromJson({'uid': d.id, ...d.data()!}))
        .toList();
    list.sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  // ── Weekly rewards ────────────────────────────────────────────────────────

  /// Returns reward info if eligible, otherwise null. Also marks as claimed.
  static Future<Map<String, dynamic>?> checkAndClaimWeeklyReward(
      String uid) async {
    final lastWeek = _lastWeekKey();
    final claimRef =
        _db.collection('weeklyRewards').doc('${lastWeek}_$uid');

    final claimed = await claimRef.get();
    if (claimed.exists) return null;

    final snap = await _db
        .collection('scores')
        .where('weekKey', isEqualTo: lastWeek)
        .orderBy('total', descending: true)
        .limit(10)
        .get();

    final rank = snap.docs.indexWhere((d) => d.id == uid) + 1;
    if (rank <= 0) return null;

    await claimRef.set({
      'uid': uid,
      'rank': rank,
      'claimedAt': FieldValue.serverTimestamp(),
    });

    final reward = _rankReward(rank);
    return {'rank': rank, ...reward};
  }

  static Map<String, int> _rankReward(int rank) {
    if (rank == 1) return {'coins': 1000, 'seeds': 3};
    if (rank == 2) return {'coins': 800, 'seeds': 2};
    if (rank == 3) return {'coins': 600, 'seeds': 2};
    if (rank <= 5) return {'coins': 400, 'seeds': 1};
    return {'coins': 200, 'seeds': 1};
  }

  // ── Week key helpers ──────────────────────────────────────────────────────

  static int currentWeekKey() => _weekKeyOf(DateTime.now());

  static int _lastWeekKey() =>
      _weekKeyOf(DateTime.now().subtract(const Duration(days: 7)));

  static int _weekKeyOf(DateTime d) {
    final startOfYear = DateTime(d.year, 1, 1);
    final dayOfYear = d.difference(startOfYear).inDays + 1;
    final weekOfYear =
        ((dayOfYear + startOfYear.weekday - 1) / 7).ceil();
    return d.year * 100 + weekOfYear;
  }
}
