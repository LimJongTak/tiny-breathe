import 'dart:convert';

class AppUser {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final String provider; // 'google' | 'kakao'
  final String? nickname; // 고유 닉네임 (첫 로그인 시 설정)

  const AppUser({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    required this.provider,
    this.nickname,
  });

  bool get hasNickname => nickname != null && nickname!.isNotEmpty;

  AppUser copyWith({
    String? displayName,
    String? photoUrl,
    String? nickname,
  }) {
    return AppUser(
      uid: uid,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      provider: provider,
      nickname: nickname ?? this.nickname,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'provider': provider,
        'nickname': nickname,
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        uid: j['uid'] as String,
        displayName: j['displayName'] as String? ?? '사용자',
        photoUrl: j['photoUrl'] as String?,
        provider: j['provider'] as String? ?? 'google',
        nickname: j['nickname'] as String?,
      );

  String toJsonString() => jsonEncode(toJson());
  factory AppUser.fromJsonString(String s) =>
      AppUser.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
