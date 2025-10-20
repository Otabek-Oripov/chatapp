import 'package:chatapp/screens/HomeScreen.dart';
import 'package:chatapp/screens/Sign.Up_screen.dart';
import 'package:chatapp/secret/secret.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // 🔒 Kamera, mikrofon, bildirishnoma ruxsatlarini so‘rash
  await requestPermission();

  // 🔑 Foydalanuvchi ma'lumotlarini olish
  final user = FirebaseAuth.instance.currentUser;
  final String userId = user?.uid ?? "guest_000";
  final String userName = user?.displayName ?? "Guest";

  // 🔔 Zego Call xizmatini sozlash
  ZegoUIKitPrebuiltCallInvitationService().setNavigatorKey(navigatorKey);

  try {
    await ZegoUIKitPrebuiltCallInvitationService().init(
      appID: ZegoConfig.appId,
      appSign: ZegoConfig.appSign,
      userID: userId,
      userName: userName,
      plugins: [ZegoUIKitSignalingPlugin()],
    );
    print('✅ Zego Initialized Successfully');
  } catch (error) {
    print('❌ Zego initialization error: $error');
  }

  runApp(ProviderScope(child: MyApp(navigatorKey: navigatorKey)));
}

Future<void> requestPermission() async {
  await [
    Permission.camera,
    Permission.microphone,
    Permission.notification,
  ].request();
}

class MyApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const MyApp({super.key, required this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // 🔐 Agar foydalanuvchi login qilmagan bo‘lsa, SignUp ekraniga yuboramiz
      home: FirebaseAuth.instance.currentUser == null
          ? const SignupScreen()
          : const Homescreen(),
    );
  }
}
