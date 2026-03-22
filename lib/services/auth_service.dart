import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import 'firestore_service.dart';

class AuthNotifier extends StateNotifier<AppUser?> {
  AuthNotifier() : super(null) {
    _restore();
  }

  static const _kUserKey = 'cached_app_user';
  final _initCompleter = Completer<void>();

  /// 앱 시작 시 인증 복원이 완료될 때까지 기다리는 Future
  Future<void> get initFuture => _initCompleter.future;

  Future<void> _restore() async {
    try {
      // Google 사용자: Firebase Auth 확인
      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser != null) {
        // Firestore에서 닉네임 포함 전체 프로필 로드 시도
        try {
          final profile = await FirestoreService.loadUserProfile(fbUser.uid);
          if (profile != null) {
            state = profile;
            return;
          }
        } catch (_) {}
        state = AppUser(
          uid: fbUser.uid,
          displayName: fbUser.displayName ?? '사용자',
          photoUrl: fbUser.photoURL,
          provider: 'google',
        );
        return;
      }

      // Kakao 사용자: SharedPreferences 확인
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_kUserKey);
      if (cached != null) {
        try {
          final cachedUser = AppUser.fromJsonString(cached);
          // Firestore에서 최신 프로필(닉네임) 로드
          try {
            final profile =
                await FirestoreService.loadUserProfile(cachedUser.uid);
            if (profile != null) {
              state = profile;
              return;
            }
          } catch (_) {}
          state = cachedUser;
        } catch (_) {}
      }
    } finally {
      _initCompleter.complete();
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return false;
      final auth = await googleUser.authentication;
      final cred = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      final result = await FirebaseAuth.instance.signInWithCredential(cred);
      final fbUser = result.user!;

      // Firestore에서 기존 프로필(닉네임) 로드
      AppUser user;
      try {
        final profile = await FirestoreService.loadUserProfile(fbUser.uid);
        user = profile ??
            AppUser(
              uid: fbUser.uid,
              displayName: fbUser.displayName ?? googleUser.displayName ?? '사용자',
              photoUrl: fbUser.photoURL ?? googleUser.photoUrl,
              provider: 'google',
            );
      } catch (_) {
        user = AppUser(
          uid: fbUser.uid,
          displayName: fbUser.displayName ?? googleUser.displayName ?? '사용자',
          photoUrl: fbUser.photoURL ?? googleUser.photoUrl,
          provider: 'google',
        );
      }

      state = user;
      FirestoreService.saveUserProfile(user).catchError((e) {
        debugPrint('[Auth] Firestore saveUserProfile(google) failed: $e');
      });
      return true;
    } catch (e) {
      debugPrint('[Auth] signInWithGoogle error: $e');
      return false;
    }
  }

  Future<bool> signInWithKakao() async {
    try {
      if (await isKakaoTalkInstalled()) {
        await UserApi.instance.loginWithKakaoTalk();
      } else {
        await UserApi.instance.loginWithKakaoAccount();
      }
      final kakaoUser = await UserApi.instance.me();
      final kakaoUid = 'kakao_${kakaoUser.id}';

      // Firestore에서 기존 프로필(닉네임) 로드
      AppUser user;
      try {
        final profile = await FirestoreService.loadUserProfile(kakaoUid);
        user = profile ??
            AppUser(
              uid: kakaoUid,
              displayName:
                  kakaoUser.kakaoAccount?.profile?.nickname ?? '사용자',
              photoUrl:
                  kakaoUser.kakaoAccount?.profile?.profileImageUrl,
              provider: 'kakao',
            );
      } catch (_) {
        user = AppUser(
          uid: kakaoUid,
          displayName: kakaoUser.kakaoAccount?.profile?.nickname ?? '사용자',
          photoUrl: kakaoUser.kakaoAccount?.profile?.profileImageUrl,
          provider: 'kakao',
        );
      }

      state = user;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(_kUserKey, user.toJsonString());
      }).catchError((e) {
        debugPrint('[Auth] SharedPreferences save failed: $e');
      });
      FirestoreService.saveUserProfile(user).catchError((e) {
        debugPrint('[Auth] Firestore saveUserProfile(kakao) failed: $e');
      });
      return true;
    } catch (e) {
      debugPrint('[Auth] signInWithKakao error: $e');
      return false;
    }
  }

  /// 닉네임 저장 후 로컬 상태 업데이트
  Future<void> updateNickname(String nickname) async {
    final user = state;
    if (user == null) return;
    await FirestoreService.setNickname(user.uid, nickname);
    final updated = user.copyWith(nickname: nickname);
    state = updated;
    if (user.provider == 'kakao') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUserKey, updated.toJsonString());
    }
  }

  Future<void> signOut() async {
    final user = state;
    state = null;
    if (user?.provider == 'google') {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
    } else if (user?.provider == 'kakao') {
      try {
        await UserApi.instance.logout();
      } catch (_) {}
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kUserKey);
    }
  }

  /// 회원탈퇴: 모든 데이터 삭제 후 계정 제거
  Future<void> deleteAccount() async {
    final user = state;
    if (user == null) return;
    state = null;

    // Firestore 데이터 삭제
    try {
      await FirestoreService.deleteUserData(user.uid);
    } catch (e) {
      debugPrint('[Auth] deleteUserData failed: $e');
    }

    if (user.provider == 'google') {
      try {
        final fbUser = FirebaseAuth.instance.currentUser;
        await fbUser?.delete();
      } catch (e) {
        debugPrint('[Auth] Firebase user delete failed: $e');
      }
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
    } else if (user.provider == 'kakao') {
      try {
        await UserApi.instance.unlink(); // 카카오 연결 해제
      } catch (_) {}
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kUserKey);
    }
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AppUser?>((ref) => AuthNotifier());
