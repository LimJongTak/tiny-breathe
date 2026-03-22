import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'services/notification_service.dart';
import 'views/splash_screen.dart';

// ⚠️  SETUP REQUIRED — see README comments below:
//
// 1. Firebase:
//    • Create project at console.firebase.google.com
//    • Enable Google sign-in provider
//    • Android: place google-services.json in android/app/
//    • iOS:     place GoogleService-Info.plist in ios/Runner/
//
// 2. Kakao:
//    • Create app at developers.kakao.com and get the Native App Key
//    • Android: add to android/app/src/main/res/values/strings.xml:
//        <string name="kakao_app_key">YOUR_NATIVE_APP_KEY</string>
//      and to AndroidManifest.xml (see Kakao SDK docs)
//    • iOS: add to Info.plist (see Kakao SDK docs)
//    • Replace 'YOUR_KAKAO_NATIVE_APP_KEY' below

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase
  await Firebase.initializeApp();

  // Kakao
  KakaoSdk.init(nativeAppKey: 'c66fb7976cdc1b2ed1cd47a545ef2aee');

  // Local notifications
  await NotificationService.init();

  runApp(const ProviderScope(child: PlantGameApp()));
}

class PlantGameApp extends StatelessWidget {
  const PlantGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '식물 키우기',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
