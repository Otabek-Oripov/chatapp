import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/legacy.dart';

final appStateManagerProvider = ChangeNotifierProvider<AppStateManager>((ref) {
  return AppStateManager();
});

class AppStateManager extends ChangeNotifier with WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isInitalized = false;

  AppStateManager() {
    WidgetsBinding.instance.addObserver(this);
    initalizedUser();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addObserver(this);
    _setOnlineStatus(false);
  }

  @override
  void didChangeAppLifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _setOnlineStatus(true);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _setOnlineStatus(false);
        break;
      default:
        break;
    }
  }

  Future<void> initalizedUser() async {
    if (isInitalized) return;

    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final userDoc = _firestore.collection("users").doc(user.uid);
      final snapshot = await userDoc.get();
      if (!snapshot.exists) {
        await userDoc.set({
          'uid': user.uid,
          'name': user.displayName ?? '',
          'email': user.email ?? '',
          'photoURL': user.photoURL ?? '',
          'provider': _getProvider(user),
          'isOnline': true,
          'lastSeen': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await userDoc.update({
          'isOnline': true,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
      isInitalized = true;
      notifyListeners();
    } catch (e) {
      print("Error");
      isInitalized = true;
    }
  }

  Future<void> _setOnlineStatus(bool isOnline) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _firestore.collection("users").doc(user.uid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Errror uptading online $e');
    }
  }

  Future<void> updateOnlineStatus(bool isOnline) async {
    await _setOnlineStatus(isOnline);
  }

  String _getProvider(User user) {
    for (final info in user.providerData) {
      if (info.providerId == 'google.com') return 'Google';
      if (info.providerId == 'password') return 'email';
    }
    return 'email';
  }

  bool get _isInitalized => isInitalized;
}
