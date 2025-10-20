import 'dart:async';
import 'dart:io';
import 'package:chatapp/models/profile_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:image_picker/image_picker.dart';

class ProfileNotifier extends StateNotifier<ProfileModel> {
  StreamSubscription<User?>? _authSubscription;

  ProfileNotifier() : super(ProfileModel(isLoading: true)) {
    listenAuthChanges();
  }

  void listenAuthChanges() {
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((user) async {
          if (user != null) {
            await loadUserData(user);
          } else {
            state = ProfileModel(isLoading: false);
          }
        });
  }

  Future<void> loadUserData([User? user]) async {
    final currentUser = user ?? FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      state = ProfileModel(isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        state = ProfileModel(
          photoUrl: data['photoURL'],
          name: data['name'],
          email: data['email'],
          createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
          userId: currentUser.uid,
          isLoading: false,
        );
      } else {
        state = ProfileModel(
          userId: currentUser.uid,
          email: currentUser.email,
          name: currentUser.displayName,
          photoUrl: currentUser.photoURL,
          isLoading: false,
        );
      }
    } catch (e) {
      print("Error loading profile: $e");
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> updateProfilePicture() async {
    try {

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return false;

      state = state.copyWith(isUploading: true);

      final file = File(pickedFile.path);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final ref = FirebaseStorage.instance
          .ref()
          .child("profile_pictures/${user.uid}.jpg");
      await ref.putFile(file);
      final newUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .update({"photoUrl": newUrl});

      state = state.copyWith(photoUrl: newUrl, isUploading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isUploading: false);
      print("Error updating profile picture: $e");
      return false;
    }
  }

  Future<void> refresh() async {
    await loadUserData();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

final profileProvider =
StateNotifierProvider<ProfileNotifier, ProfileModel>((ref) {
  return ProfileNotifier();
});
