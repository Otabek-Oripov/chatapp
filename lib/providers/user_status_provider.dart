import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final userStatusProvider = StreamProvider.family<bool, String>((ref, uid) {
  return FirebaseFirestore.instance
      .collection("users")
      .doc(uid)
      .snapshots()
      .map((snapshot) {
    final data = snapshot.data();
    return data?['isOnline'] ?? false;
  });
});
