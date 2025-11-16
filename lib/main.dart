// main.dart
import 'dart:async';

import 'package:bugsnag_flutter/bugsnag_flutter.dart';
import 'package:chatapp/screens/HomeScreen.dart';
import 'package:chatapp/screens/Sign.Up_screen.dart';
import 'package:chatapp/secret/secret.dart';
import 'package:chatapp/services/chatService.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:permission_handler/permission_handler.dart';

import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await bugsnag.start(apiKey: '2810e799cb2322b010c8189baf552854');

  runZonedGuarded(
        () async {
      await Firebase.initializeApp();

      await _requestPermissions();

      // faqat navigatorKey ni o‘rnatamiz
      ZegoUIKitPrebuiltCallInvitationService().setNavigatorKey(navigatorKey);

      runApp(
        const ProviderScope(
          child: MyRootApp(),
        ),
      );
    },
        (error, stackTrace) {
      bugsnag.notify(error, stackTrace);
    },
  );
}

// -------- PERMISSIONS --------
Future<void> _requestPermissions() async {
  final statuses = await [
    Permission.camera,
    Permission.microphone,
    Permission.notification,
  ].request();

  final denied =
  statuses.entries.where((e) => !e.value.isGranted).map((e) => e.key).toList();

  if (denied.isNotEmpty) {
    print("Ruxsat berilmadi: $denied");
  }
}

// -------- ONLINE STATUS SERVICE --------
class OnlineStatusService {
  static final _chatService = ChatService();
  static final _observer = _AppLifecycleObserver();

  static void initialize() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    WidgetsBinding.instance.addObserver(_observer);
    _setOnline(true);
  }

  static Future<void> _setOnline(bool online) async {
    try {
      await _chatService.updateUserOnlineStatus(online);
    } catch (e, s) {
      print("Online status error: $e");
      bugsnag.notify(e, s);
    }
  }

  static void dispose() {
    WidgetsBinding.instance.removeObserver(_observer);
    _setOnline(false);
  }
}

class _AppLifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      await OnlineStatusService._setOnline(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      await OnlineStatusService._setOnline(false);
    }
  }
}

// -------- ROOT APP --------
/// Bu widget Firebase auth o‘zgarishlarini tinglaydi va
/// har safar user login / logout bo‘lganda Zego’ni to‘g‘ri init/uninit qiladi.
class MyRootApp extends StatefulWidget {
  const MyRootApp({super.key});

  @override
  State<MyRootApp> createState() => _MyRootAppState();
}

class _MyRootAppState extends State<MyRootApp> with WidgetsBindingObserver {
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenAuthChanges();
  }

  void _listenAuthChanges() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen(
          (user) async {
        if (user != null) {
          // 🔥 USER LOGIN QILGANIDA ZEGO INIT
          try {
            await ZegoUIKitPrebuiltCallInvitationService().init(
              appID: ZegoConfig.appId,      // yangi/hozirgi project AppID
              appSign: ZegoConfig.appSign,  // yangi/hozirgi AppSign
              userID: user.uid,             // Zego userID = Firebase UID
              userName: user.displayName ??
                  (user.email ?? 'user_${user.uid.substring(0, 6)}'),
              plugins: [ZegoUIKitSignalingPlugin()],
            );
            print('Zego init bo‘ldi userID=${user.uid}');
          } catch (e, s) {
            print('Zego init error: $e');
            bugsnag.notify(e, s);
          }

          // online statusni ham faqat logged-in user uchun
          OnlineStatusService.initialize();
        } else {
          // USER LOGOUT – Zego’ni tozalaymiz
          try {
            await ZegoUIKitPrebuiltCallInvitationService().uninit();
            print('Zego uninit bo‘ldi (user null)');
          } catch (_) {}

          OnlineStatusService.dispose();
        }
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    OnlineStatusService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final user = snapshot.data;
          if (user == null) {
            return const SignupScreen();
          } else {
            return const Homescreen();
          }
        },
      ),
    );
  }
}
