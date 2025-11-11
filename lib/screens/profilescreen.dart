// screens/ProfileScreen.dart
import 'package:chatapp/function/snakbar.dart';
import 'package:chatapp/main.dart';
import 'package:chatapp/providers/profile_provider.dart';
import 'package:chatapp/providers/provide.dart';
import 'package:chatapp/providers/userListPProvider.dart';
import 'package:chatapp/screens/LoginScreen.dart';
import 'package:chatapp/services/auth.service.dart';
import 'package:chatapp/widgets/widgetImage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String? lastUserId;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    OnlineStatusService();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final notifier = ref.read(profileProvider.notifier);
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser?.uid != lastUserId) {
      lastUserId = currentUser?.uid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) notifier.refresh();
      });
    }

    if (profile.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return // lib/screens/profilescreen.dart
      Scaffold(
        backgroundColor: const Color(0xFFF9F9F9),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text("Profil", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(onPressed: () => notifier.refresh(), icon: const Icon(Icons.refresh, size: 28)),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // RASMLAR
              GestureDetector(
                onTap: () {
                  if (profile.profileImages.isNotEmpty) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => FullImageView(imageUrls: profile.profileImages, initialIndex: 0)));
                  }
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Hero(
                      tag: 'main_profile',
                      child: CircleAvatar(
                        radius: 80,
                        backgroundImage: profile.profileImages.isNotEmpty ? NetworkImage(profile.profileImages.first) : null,
                        child: profile.profileImages.isEmpty
                            ? const Icon(Icons.person, size: 80, color: Colors.grey)
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 10, right: 10,
                      child: GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                          if (file != null) await notifier.addProfileImage(File(file.path));
                        },
                        child: const CircleAvatar(radius: 20, backgroundColor: Color(0xFF6a11cb), child: Icon(Icons.camera_alt, color: Colors.white, size: 20)),
                      ),
                    ),
                    if (profile.profileImages.length > 1)
                      Positioned(
                        top: 10, right: 10,
                        child: CircleAvatar(radius: 18, backgroundColor: Colors.black54, child: Text("${profile.profileImages.length}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Text(profile.name ?? "Ism yo‘q", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              Text(profile.email ?? "", style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
              Text("A'zo: ${profile.createdAt != null ? DateFormat("dd MMM yyyy").format(profile.createdAt!) : 'Noma\'lum'}", style: TextStyle(color: Colors.grey.shade600)),

              const SizedBox(height: 40),

              // LOGOUT TUGMASI
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Chiqish"),
                        content: const Text("Hisobdan chiqmoqchimisiz?"),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Yo‘q")),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Ha", style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(authMethodProvider).signOut();
                      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserLoginScreen()));
                    }
                  },
                  child: const Text("CHIQISH", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
