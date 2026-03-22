# 🌱 Tiny Breathe

Flutter로 제작한 식물 키우기 모바일 게임입니다. 미니게임으로 씨앗을 모으고, 화단에 식물을 심어 성장시키고, 교배를 통해 희귀 식물을 만들어보세요.

---

## 주요 기능

### 🌿 식물 키우기
- 화단에 씨앗을 심고 물을 주며 성장 단계(씨앗 → 만개) 진행
- 현재 날씨(지오로케이션 기반)가 식물 상태에 영향
- 나비 애니메이션 등 생동감 있는 화단 연출

### 🧬 교배 시스템
- 두 식물을 교배해 새로운 하이브리드 종 생성
- HSL 색상 유전 알고리즘으로 부모 색을 혼합한 색상 생성
- 희귀도 확률: Common(55%) / Uncommon(25%) / Rare(15%) / Holographic(5%)

### 🎮 씨앗 미니게임 (5종)
| 게임 | 설명 | 난이도 |
|------|------|--------|
| 🌱 땅파기 | 버튼을 빠르게 탭해 게이지를 채우면 씨앗 획득 | 쉬움 |
| 💧 물방울 잡기 | 20초 동안 떨어지는 물방울 탭 | 보통 |
| 🌿 잡초뽑기 | 꽃은 살리고 잡초만 골라 탭 | 어려움 |
| 🦟 벌레 퇴치 | 조이스틱으로 이동해 벌레 잡기 | 보통 |
| 🐝 벌 피하기 | 조이스틱으로 이동해 30초 생존 | 어려움 |

- 게임 티켓 시스템: 10분마다 1개 충전
- 글로벌 리더보드 (Firestore 기반)

### 🛒 상점
- **장비**: 황금 물뿌리개, 자동 분무기 등 영구 업그레이드
- **소모품**: 영양제, 성장촉진제
- **씨앗**: 레벨에 따라 잠금 해제되는 다양한 씨앗 구매

### 📦 컬렉션 & 소셜
- 수확한 식물 컬렉션 보관
- 친구 추가 및 친구의 정원 방문
- 식물/정원 이미지 공유

### 🔐 로그인
- Google 로그인 (Firebase Auth)
- 카카오 로그인
- 다기기 데이터 동기화 (Firestore)

---

## 기술 스택

| 분류 | 사용 기술 |
|------|-----------|
| Framework | Flutter 3.x (Dart) |
| 상태 관리 | Riverpod |
| 인증 | Firebase Auth, Google Sign-In, Kakao SDK |
| DB/동기화 | Cloud Firestore |
| 분석 | Firebase Analytics |
| 위치 | Geolocator |
| 날씨 | Weather API (HTTP) |
| 애니메이션 | Rive, CustomPainter |
| 공유 | share_plus |

---

## 프로젝트 구조

```
lib/
├── main.dart
├── models/          # 데이터 모델 (Plant, Garden, User 등)
├── views/           # 화면 (Home, Garden, Shop, MiniGame 등)
│   ├── auth/        # 로그인 화면
│   ├── games/       # 미니게임 5종
│   └── social/      # 친구, 리더보드
├── viewmodels/      # Riverpod StateNotifier
├── services/        # Firebase, Auth, Weather, Sync
├── widgets/         # 재사용 위젯 (PlantPainter, InteractivePlant 등)
├── effects/         # 나비 애니메이션 등 시각 효과
└── utils/           # 공유, 식물 코드 등 유틸리티
```

---

## 시작하기

### 사전 준비

1. **Firebase 설정**
   - [Firebase Console](https://console.firebase.google.com)에서 프로젝트 생성
   - Google 로그인 활성화 (Authentication → Sign-in method)
   - `google-services.json` → `android/app/` 에 배치

2. **카카오 설정**
   - [Kakao Developers](https://developers.kakao.com)에서 앱 생성
   - Android 플랫폼 등록 및 키 해시 추가
   - `android/app/src/main/res/values/strings.xml`에 앱 키 입력

### 실행

```bash
flutter pub get
flutter run
```

---

## 스크린샷

> 추후 추가 예정

---

## 라이선스

MIT
