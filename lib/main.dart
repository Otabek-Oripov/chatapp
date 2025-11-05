import 'dart:async';

import 'package:bugsnag_flutter/bugsnag_flutter.dart' show Bugsnag, bugsnag;
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await bugsnag.start(apiKey: '2810e799cb2322b010c8189baf552854');

  runZonedGuarded(
    () async {
      await Firebase.initializeApp();
      await requestPermission();

      final user = FirebaseAuth.instance.currentUser;
      final String userId = user?.uid ?? "guest_000";
      final String userName = user?.displayName ?? "Guest";

      ZegoUIKitPrebuiltCallInvitationService().setNavigatorKey(navigatorKey);

      try {
        await ZegoUIKitPrebuiltCallInvitationService().init(
          appID: ZegoConfig.appId,
          appSign: ZegoConfig.appSign,
          userID: userId,
          userName: userName,
          plugins: [ZegoUIKitSignalingPlugin()],
        );
        print('Zego Initialized Successfully');
      } catch (error, stackTrace) {
        print('Zego initialization error: $error');
        bugsnag.notify(error, stackTrace);
      }

      runApp(ProviderScope(child: MyApp(navigatorKey: navigatorKey)));
    },
    (error, stackTrace) {
      // This catches any unhandled async errors
      bugsnag.notify(error, stackTrace);
    },
  );
}

Future<void> requestPermission() async {
  await [
    Permission.camera,
    Permission.microphone,
    Permission.notification,
  ].request();
}

class MyApp extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const MyApp({super.key, required this.navigatorKey});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final ChatService _chatService = ChatService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // App ishga tushganda foydalanuvchini online qilish
    _chatService.updateUserOnlineStatus(true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App fon rejimiga o'tganda offline, ochilganda online bo‘ladi
    if (state == AppLifecycleState.resumed) {
      _chatService.updateUserOnlineStatus(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _chatService.updateUserOnlineStatus(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chatService.updateUserOnlineStatus(false);
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
      home: SignupScreen()
      // FirebaseAuth.instance.currentUser == null
      //     ? const SignupScreen()
      //     : const Homescreen(),
    );
  }
}
