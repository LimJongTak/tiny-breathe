import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/auth_service.dart';
import '../home_screen.dart';
import 'nickname_setup_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _loading = false;

  Future<void> _signIn(Future<bool> Function() fn) async {
    setState(() => _loading = true);
    final ok = await fn();
    if (!mounted) return;
    setState(() => _loading = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인에 실패했습니다. 다시 시도해주세요.')),
      );
      return;
    }

    // 로그인 성공 → 닉네임 유무에 따라 분기
    final user = ref.read(authProvider);
    if (user == null) return;

    final next = user.hasNickname
        ? const HomeScreen()
        : const NicknameSetupScreen();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => next),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B0D),
      body: SafeArea(
        child: Center(
          child: _loading
              ? const CircularProgressIndicator(color: Colors.greenAccent)
              : Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🌱', style: TextStyle(fontSize: 72)),
                      const SizedBox(height: 20),
                      const Text(
                        'Tiny Breathe',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '로그인하면 다른 기기에서도\n이어서 플레이할 수 있어요!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                      const SizedBox(height: 48),
                      _LoginButton(
                        icon: Icons.g_mobiledata_rounded,
                        label: 'Google로 계속하기',
                        color: Colors.white,
                        textColor: Colors.black87,
                        onTap: () => _signIn(
                            () => ref.read(authProvider.notifier).signInWithGoogle()),
                      ),
                      const SizedBox(height: 14),
                      _LoginButton(
                        icon: Icons.chat_bubble_rounded,
                        label: '카카오로 계속하기',
                        color: const Color(0xFFFEE500),
                        textColor: Colors.black87,
                        onTap: () => _signIn(
                            () => ref.read(authProvider.notifier).signInWithKakao()),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, textColor;
  final VoidCallback onTap;

  const _LoginButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 24),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
