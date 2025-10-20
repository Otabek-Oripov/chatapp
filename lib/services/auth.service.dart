import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
class AuthMethod {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Future<String> signUpUser({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      if (email.isEmpty || password.isEmpty || name.isEmpty) {
        return "Please enter all fields";
      }
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Update user profile
      await cred.user!.updateDisplayName(name);
      // FIXED: Store user data with cons istent field names
      await _firestore.collection("users").doc(cred.user!.uid).set({
        "uid": cred.user!.uid,
        "name": name,
        "email": email,
        "photoURL": null,
        "isOnline": false, // Set to true when user signs up
        "provider": "email",
        'lastSeen': FieldValue.serverTimestamp(),
        "createdAt": FieldValue.serverTimestamp(),
      });
      return "success";
    } catch (e) {
      return e.toString();
    }
  }
  // Login with online status update
  Future<String> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        return "Please enter all fields";
      }
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      // Update online status after login
      if (_auth.currentUser != null) {
        await _firestore.collection('users').doc(_auth.currentUser!.uid).update(
          {'isOnline': true, 'lastSeen': FieldValue.serverTimestamp()},
        );
      }
      return "success";
    } catch (e) {
      return e.toString();
    }
   }
  //Logout with online status update
  Future<void> signOut() async {
    if (_auth.currentUser != null) {
      // Set offline before signing out
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
    await _auth.signOut();
  }
}
final authMethodProvider = Provider<AuthMethod>((ref) {
  return AuthMethod();
});