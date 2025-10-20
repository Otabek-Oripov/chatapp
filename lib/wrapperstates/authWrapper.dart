import 'dart:async';

import 'package:chatapp/screens/HomeScreen.dart';
import 'package:chatapp/wrapperstates/appstatemanager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Authwrapper extends ConsumerStatefulWidget {
  const Authwrapper({super.key});

  @override
  ConsumerState<Authwrapper> createState() => _AuthwrapperState();
}

class _AuthwrapperState extends ConsumerState<Authwrapper> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeSession();
  }

  Future<void> _initializeSession() async {
    try {
      final appManager = ref.read(appStateManagerProvider);
      await Future.any([
        appManager.initalizedUser(),
        Future.delayed(const Duration(seconds: 10),
                () => throw TimeoutException('session init timeout')),
      ]);

      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Error initializing session: $e');
      if (mounted) setState(() => _isInitialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Setting up your account...")
            ],
          ),
        ),
      );
    }
    return const Homescreen();
  }
}

