// main.dart (to‘liq almashtiring!)
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

      await _initZego(); // ESKI PROJECT BILAN INIT

      OnlineStatusService.initialize();

      runApp(
        ProviderScope(
          child: MyApp(navigatorKey: navigatorKey),
        ),
      );
    },
        (error, stackTrace) {
      bugsnag.notify(error, stackTrace);
    },
  );
}

// PERMISSIONS
Future<void> _requestPermissions() async {
  final statuses = await [Permission.camera, Permission.microphone, Permission.notification].request();
  final denied = statuses.entries.where((e) => !e.value.isGranted).map((e) => e.key).toList();
  if (denied.isNotEmpty) print("Ruxsat berilmadi: $denied");
}

// ZEGO INIT — ESKI PROJECT BILAN (CHAT UCHUN)
Future<void> _initZego() async {
  final user = FirebaseAuth.instance.currentUser;
  final userId = user?.uid ?? "guest_${DateTime.now().millisecondsSinceEpoch}";
  final userName = user?.displayName ?? "Guest";

  ZegoUIKitPrebuiltCallInvitationService().setNavigatorKey(navigatorKey);

  await ZegoUIKitPrebuiltCallInvitationService().init(
    appID: ZegoConfig.appId, // ESKI 1757546724
    appSign: ZegoConfig.appSign,
    userID: userId,
    userName: userName,
    plugins: [ZegoUIKitSignalingPlugin()],
  );
  print('Zego chat uchun init bo‘ldi: $userId');
}

// ONLINE STATUS (oldingidek)
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
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached || state == AppLifecycleState.inactive) {
      await OnlineStatusService._setOnline(false);
    }
  }
}

// MY APP (oldingidek)
class MyApp extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  const MyApp({super.key, required this.navigatorKey});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    OnlineStatusService.initialize();
  }

  @override
  void dispose() {
    OnlineStatusService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: widget.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: FirebaseAuth.instance.currentUser == null
          ? const SignupScreen()
          : const Homescreen(),
    );
  }
}