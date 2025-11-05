// providers/profile_provider.dart
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
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) async {
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
        state = ProfileModel.fromMap(data).copyWith(isLoading: false);
      } else {
        state = ProfileModel(
          userId: currentUser.uid,
          email: currentUser.email,
          name: currentUser.displayName ?? "User",
          photoUrl: currentUser.photoURL,
          profileImages: currentUser.photoURL != null ? [currentUser.photoURL!] : [],
          isLoading: false,
        );
      }
    } catch (e) {
      print("Error loading profile: $e");
      state = state.copyWith(isLoading: false);
    }
  }

  // YANGI: Cheksiz rasm qo'shish
  Future<bool> addProfileImage(File file) async {
    try {
      state = state.copyWith(isUploading: true);

      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images/${FirebaseAuth.instance.currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      final uploadTask = await ref.putFile(file);
      final url = await uploadTask.ref.getDownloadURL();

      // YANGI RASM BIRINCHI BO‘LADI → ASOSIY BO‘LADI
      final updatedImages = [url, ...state.profileImages];

      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({
        'profileImages': updatedImages,
        'photoUrl': url, // yangi rasm asosiy
      });

      state = state.copyWith(
        profileImages: updatedImages,
        photoUrl: url,
        isUploading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isUploading: false);
      return false;
    }
  }
// providers/profile_provider.dart (qo‘shilgan funksiya)
  // providers/profile_provider.dart

  Future<bool> removeProfileImage(int index) async {
    try {
      state = state.copyWith(isUploading: true);

      final imageUrlToDelete = state.profileImages[index];
      final updatedImages = List<String>.from(state.profileImages)..removeAt(index);
      final newMainPhoto = updatedImages.isNotEmpty ? updatedImages.first : null;

      // 1. Storage'dan o‘chirish
      try {
        final ref = FirebaseStorage.instance.refFromURL(imageUrlToDelete);
        await ref.delete();
      } catch (e) {
        print("Storage'dan o‘chirishda xato: $e");
        // Agar o‘chirilmasa ham, davom etamiz (rasm yo‘q bo‘lishi mumkin)
      }

      // 2. Firestore'dan yangilash
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({
        'profileImages': updatedImages,
        'photoUrl': newMainPhoto,
      });

      // 3. State yangilash
      state = state.copyWith(
        profileImages: updatedImages,
        photoUrl: newMainPhoto,
        isUploading: false,
      );

      return true;
    } catch (e) {
      state = state.copyWith(isUploading: false);
      print("Rasm o‘chirishda xato: $e");
      return false;
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

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileModel>((ref) {
  return ProfileNotifier();
});