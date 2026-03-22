import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const _prefsKey = 'has_seen_onboarding';

  /// Returns true if the user has already completed onboarding.
  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? false;
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _currentPage = 0;

  static const _steps = [
    _Step(
      emoji: '🌿',
      title: '나만의 정원에 오신 걸\n환영해요!',
      body: '씨앗을 심고 물을 주며\n세상에 하나뿐인 정원을 키워보세요.',
      color: Color(0xFF2E7D32),
    ),
    _Step(
      emoji: '🌱',
      title: '씨앗을 심어보세요',
      body: '빈 화단을 탭하면 씨앗 보관함이 열려요.\n미니게임으로 씨앗을 얻을 수 있어요.',
      color: Color(0xFF1565C0),
    ),
    _Step(
      emoji: '💧',
      title: '매일 물을 주세요',
      body: '수분이 0%가 되면 식물이 시들어요.\n30분 이내에 물을 주면 살릴 수 있어요!',
      color: Color(0xFF00838F),
    ),
    _Step(
      emoji: '👥',
      title: '친구와 함께해요',
      body: '친구의 정원을 방문하고\n물 선물로 식물을 도와줄 수 있어요.',
      color: Color(0xFF6A1B9A),
    ),
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await OnboardingScreen.markSeen();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B0D),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: _steps.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => _StepPage(step: _steps[i]),
              ),
            ),

            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _steps.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
                  width: _currentPage == i ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? Colors.greenAccent
                        : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),

            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Row(children: [
                if (_currentPage > 0)
                  TextButton(
                    onPressed: () => _pageCtrl.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                    child: const Text('이전',
                        style: TextStyle(color: Colors.white38)),
                  )
                else
                  TextButton(
                    onPressed: _finish,
                    child: const Text('건너뛰기',
                        style: TextStyle(color: Colors.white38)),
                  ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _currentPage < _steps.length - 1
                      ? () => _pageCtrl.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          )
                      : _finish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    minimumSize: const Size(120, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    _currentPage < _steps.length - 1 ? '다음' : '시작하기!',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step {
  final String emoji, title, body;
  final Color color;
  const _Step({
    required this.emoji,
    required this.title,
    required this.body,
    required this.color,
  });
}

class _StepPage extends StatelessWidget {
  final _Step step;
  const _StepPage({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              color: step.color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(
                  color: step.color.withValues(alpha: 0.5), width: 2),
            ),
            child: Center(
              child: Text(step.emoji,
                  style: const TextStyle(fontSize: 64)),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            step.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            step.body,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 15,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
