// screens/ProfileScreen.dart
import 'package:chatapp/function/snakbar.dart';
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          "Profile",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            onPressed: () => notifier.refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // === ASOSIY RASM (scroll uchun) ===
            // === ASOSIY RASM + CHEKSIZ QO‘SHISH + SCROLL KO‘RISH ===
            // === ASOSIY RASM + YANGI RASM ASOSIY BO‘LADI + O‘CHIRISH ===
            GestureDetector(
              onTap: () {
                if (profile.profileImages.isNotEmpty) {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => FullImageView(
                        imageUrls: profile.profileImages,
                        initialIndex: 0,
                        onDelete: (index) async {
                          // Storage + Firestore'dan o‘chirish
                          final success = await notifier.removeProfileImage(index);
                          return success; // Future<bool> qaytaradi
                        },
                      ),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      transitionDuration: const Duration(milliseconds: 300),
                    ),
                  );
                }
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Hero(
                    tag: 'main_profile_image',
                    child: CircleAvatar(
                      radius: 70,
                      backgroundImage: profile.profileImages.isNotEmpty
                          ? NetworkImage(profile.profileImages.first)
                          : null,
                      child: profile.profileImages.isEmpty
                          ? const Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                  ),

                  // YANGI RASM QO‘SHISH → BIRINCHI BO‘LIB, ASOSIY BO‘LADI
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final pickedFile = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 80,
                        );
                        if (pickedFile != null && mounted) {
                          final success = await notifier.addProfileImage(
                            File(pickedFile.path),
                          );
                          if (success) {
                            showAppSnackbar(
                              context: context,
                              type: SnackbarType.success,
                              description:
                                  "Yangi rasm qo‘shildi va asosiy qilindi!",
                            );
                          } else {
                            showAppSnackbar(
                              context: context,
                              type: SnackbarType.error,
                              description: "Xato yuz berdi",
                            );
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.black87,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_a_photo,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),

                  // YUKLANAYOTGAN
                  if (profile.isUploading)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black26,
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                    ),

                  // RASM SONI: faqat 0 yoki 2+ bo‘lsa ko‘rinsin
                  if (profile.profileImages.isEmpty ||
                      profile.profileImages.length > 1)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: profile.profileImages.isEmpty
                              ? Colors.grey.shade600
                              : Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "${profile.profileImages.length}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 15),
            Text(
              profile.name ?? "No Name",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              profile.email ?? "No Email",
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            Text(
              profile.createdAt != null
                  ? "Joined ${DateFormat("MMM d, y").format(profile.createdAt!)}"
                  : "Joined date not available",
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),

            const SizedBox(height: 30),

            const SizedBox(height: 10),

            // === LOGOUT ===
            MaterialButton(
              color: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              onPressed: () async {
                final shouldLogout = await showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Logout"),
                    content: const Text("Are you sure you want to logout?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text("Logout"),
                      ),
                    ],
                  ),
                );

                if (shouldLogout == true) {
                  final auth = ref.read(authMethodProvider);
                  await auth.signOut();

                  ref.invalidate(profileProvider);
                  ref.invalidate(userListProvider);
                  ref.invalidate(requestsProvider);
                  ref.invalidate(usersProvider);
                  ref.invalidate(filteresUsersProvider);
                  ref.invalidate(searchQueryProvider);
                  ref.invalidate(chatsProvider);

                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UserLoginScreen(),
                      ),
                    );
                  }
                }
              },
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.exit_to_app, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Log out',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
