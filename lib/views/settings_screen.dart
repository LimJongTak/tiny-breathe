import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'auth/login_screen.dart';
import 'social/friends_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // ── 닉네임 변경 상태 ──────────────────────────────────────────────────────
  bool _editingNickname = false;
  final _nickCtrl = TextEditingController();
  bool _checking = false;
  bool _saving = false;
  bool _available = false;
  String? _feedback;

  @override
  void dispose() {
    _nickCtrl.dispose();
    super.dispose();
  }

  String? _validateFormat(String value) {
    final v = value.trim();
    if (v.length < 2) return '2자 이상 입력해주세요';
    if (v.length > 12) return '12자 이하로 입력해주세요';
    if (!RegExp(r'^[가-힣a-zA-Z0-9_]+$').hasMatch(v)) return '한글, 영문, 숫자, _만 사용 가능해요';
    return null;
  }

  Future<void> _checkNickname() async {
    final err = _validateFormat(_nickCtrl.text);
    if (err != null) {
      setState(() => _feedback = err);
      return;
    }
    setState(() {
      _checking = true;
      _feedback = null;
      _available = false;
    });
    try {
      final currentNick = ref.read(authProvider)?.nickname;
      final input = _nickCtrl.text.trim();
      // 현재 닉네임과 같으면 통과
      if (input == currentNick) {
        setState(() {
          _available = true;
          _feedback = '';
        });
        return;
      }
      final ok = await FirestoreService.isNicknameAvailable(input);
      if (!mounted) return;
      setState(() {
        _available = ok;
        _feedback = ok ? '' : '이미 사용 중인 닉네임이에요';
      });
    } catch (_) {
      if (mounted) setState(() => _feedback = '확인 중 오류가 발생했어요');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _saveNickname() async {
    if (!_available) return;
    setState(() => _saving = true);
    try {
      await ref.read(authProvider.notifier).updateNickname(_nickCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _editingNickname = false;
        _feedback = null;
        _available = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임이 변경되었어요!')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장 중 오류가 발생했어요')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── 로그아웃 ──────────────────────────────────────────────────────────────
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: '로그아웃',
        message: '로그아웃 하시겠어요?',
        confirmLabel: '로그아웃',
        confirmColor: Colors.redAccent,
      ),
    );
    if (confirm != true || !mounted) return;
    await ref.read(authProvider.notifier).signOut();
    if (!mounted) return;
    _goToLogin();
  }

  // ── 회원탈퇴 ──────────────────────────────────────────────────────────────
  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: '회원탈퇴',
        message: '탈퇴하면 정원, 식물, 랭킹 데이터가\n모두 삭제되며 복구할 수 없어요.\n\n정말 탈퇴하시겠어요?',
        confirmLabel: '탈퇴하기',
        confirmColor: Colors.red,
        isDangerous: true,
      ),
    );
    if (confirm != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.greenAccent),
      ),
    );

    try {
      await ref.read(authProvider.notifier).deleteAccount();
    } finally {
      if (mounted) Navigator.of(context).pop(); // dismiss loading
    }
    if (!mounted) return;
    _goToLogin();
  }

  void _goToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2E1A),
        foregroundColor: Colors.white,
        title: const Text('설정'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 프로필 카드 ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2E1A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.green[800],
                  backgroundImage: user.photoUrl != null
                      ? NetworkImage(user.photoUrl!)
                      : null,
                  child: user.photoUrl == null
                      ? Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0]
                              : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.displayName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        user.provider == 'kakao' ? '카카오 계정' : 'Google 계정',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12),
                      ),
                      if (user.nickname != null) ...[
                        const SizedBox(height: 4),
                        Text('@${user.nickname}',
                            style: const TextStyle(
                                color: Colors.greenAccent, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const _SectionLabel('소셜'),
          _SettingsTile(
            icon: Icons.people_rounded,
            label: '친구 / 랭킹',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FriendsScreen()),
            ),
          ),

          const SizedBox(height: 16),
          const _SectionLabel('계정'),

          // ── 닉네임 변경 ────────────────────────────────────────────────
          if (!_editingNickname)
            _SettingsTile(
              icon: Icons.badge_rounded,
              label: '닉네임 변경',
              subtitle: user.nickname != null ? '@${user.nickname}' : null,
              onTap: () {
                _nickCtrl.text = user.nickname ?? '';
                setState(() {
                  _editingNickname = true;
                  _feedback = null;
                  _available = false;
                });
              },
            )
          else
            _NicknameEditor(
              ctrl: _nickCtrl,
              checking: _checking,
              saving: _saving,
              available: _available,
              feedback: _feedback,
              onCheck: _checkNickname,
              onSave: _saveNickname,
              onCancel: () => setState(() => _editingNickname = false),
            ),

          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.logout_rounded,
            label: '로그아웃',
            iconColor: Colors.orangeAccent,
            labelColor: Colors.orangeAccent,
            onTap: _logout,
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.delete_forever_rounded,
            label: '회원탈퇴',
            iconColor: Colors.redAccent,
            labelColor: Colors.redAccent,
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }
}

// ── 닉네임 편집기 ─────────────────────────────────────────────────────────────

class _NicknameEditor extends StatelessWidget {
  final TextEditingController ctrl;
  final bool checking, saving, available;
  final String? feedback;
  final VoidCallback onCheck, onSave, onCancel;

  const _NicknameEditor({
    required this.ctrl,
    required this.checking,
    required this.saving,
    required this.available,
    required this.feedback,
    required this.onCheck,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: ctrl,
            style: const TextStyle(color: Colors.white),
            maxLength: 12,
            decoration: InputDecoration(
              counterStyle: const TextStyle(color: Colors.white38),
              hintText: '새 닉네임 (2~12자)',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF0D1B0D),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) {},
          ),
          if (feedback != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Icon(
                  available ? Icons.check_circle : Icons.cancel,
                  color: available ? Colors.greenAccent : Colors.redAccent,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  available ? '사용 가능한 닉네임이에요!' : feedback!,
                  style: TextStyle(
                    color: available ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 12,
                  ),
                ),
              ]),
            ),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: checking ? null : onCheck,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.greenAccent,
                  side: const BorderSide(color: Colors.greenAccent),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: checking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.greenAccent, strokeWidth: 2))
                    : const Text('중복 확인'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: available && !saving ? onSave : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('저장',
                        style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onCancel,
              child: const Text('취소',
                  style: TextStyle(color: Colors.white38)),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── 공통 위젯 ─────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text,
          style: const TextStyle(color: Colors.white38, fontSize: 12)),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color iconColor;
  final Color labelColor;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.iconColor = Colors.greenAccent,
    this.labelColor = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E1A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(label, style: TextStyle(color: labelColor)),
        subtitle: subtitle != null
            ? Text(subtitle!,
                style: const TextStyle(color: Colors.white38, fontSize: 12))
            : null,
        trailing:
            const Icon(Icons.chevron_right_rounded, color: Colors.white24),
        onTap: onTap,
      ),
    );
  }
}

// ── 확인 다이얼로그 ───────────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final String title, message, confirmLabel;
  final Color confirmColor;
  final bool isDangerous;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
    this.isDangerous = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A2E1A),
      title: Text(title,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)),
      content: Text(message,
          style: const TextStyle(color: Colors.white70, fontSize: 14)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child:
              const Text('취소', style: TextStyle(color: Colors.white38)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
