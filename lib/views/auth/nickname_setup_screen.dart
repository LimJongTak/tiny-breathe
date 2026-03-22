import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../home_screen.dart';

class NicknameSetupScreen extends ConsumerStatefulWidget {
  const NicknameSetupScreen({super.key});

  @override
  ConsumerState<NicknameSetupScreen> createState() =>
      _NicknameSetupScreenState();
}

class _NicknameSetupScreenState extends ConsumerState<NicknameSetupScreen> {
  final _ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _checking = false;
  bool _saving = false;
  String? _feedback; // null = 미확인, '' = 사용 가능, non-empty = 오류 메시지
  bool _available = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String? _validateFormat(String? value) {
    if (value == null || value.trim().isEmpty) return '닉네임을 입력해주세요';
    final v = value.trim();
    if (v.length < 2) return '2자 이상 입력해주세요';
    if (v.length > 12) return '12자 이하로 입력해주세요';
    final regex = RegExp(r'^[가-힣a-zA-Z0-9_]+$');
    if (!regex.hasMatch(v)) return '한글, 영문, 숫자, _만 사용 가능해요';
    return null;
  }

  Future<void> _checkAvailability() async {
    if (_validateFormat(_ctrl.text) != null) {
      _formKey.currentState!.validate();
      return;
    }
    setState(() {
      _checking = true;
      _feedback = null;
      _available = false;
    });
    try {
      final ok =
          await FirestoreService.isNicknameAvailable(_ctrl.text.trim());
      if (!mounted) return;
      setState(() {
        _available = ok;
        _feedback = ok ? '' : '이미 사용 중인 닉네임이에요';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _feedback = '확인 중 오류가 발생했어요. 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _save() async {
    if (!_available) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(authProvider.notifier)
          .updateNickname(_ctrl.text.trim());
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장 중 오류가 발생했어요. 다시 시도해주세요')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B0D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🌱', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                '안녕하세요,\n${user?.displayName ?? ''}님!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '정원에서 사용할 닉네임을 설정해주세요.\n친구들이 이 닉네임으로 검색할 수 있어요.',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 40),
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _ctrl,
                  style: const TextStyle(color: Colors.white),
                  maxLength: 12,
                  decoration: InputDecoration(
                    counterStyle: const TextStyle(color: Colors.white38),
                    hintText: '닉네임 (2~12자)',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF1A2E1A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: Colors.greenAccent, width: 1.5),
                    ),
                  ),
                  validator: _validateFormat,
                  onChanged: (_) => setState(() {
                    _feedback = null;
                    _available = false;
                  }),
                ),
              ),
              const SizedBox(height: 8),
              // 중복 확인 피드백
              if (_feedback != null)
                Row(
                  children: [
                    Icon(
                      _available ? Icons.check_circle : Icons.cancel,
                      color: _available ? Colors.greenAccent : Colors.redAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _available ? '사용 가능한 닉네임이에요!' : _feedback!,
                      style: TextStyle(
                        color:
                            _available ? Colors.greenAccent : Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              // 중복 확인 버튼
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _checking ? null : _checkAvailability,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.greenAccent,
                    side: const BorderSide(color: Colors.greenAccent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.greenAccent, strokeWidth: 2),
                        )
                      : const Text('중복 확인'),
                ),
              ),
              const SizedBox(height: 12),
              // 완료 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _available && !_saving ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    disabledBackgroundColor: Colors.green[900],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          '정원 시작하기',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
