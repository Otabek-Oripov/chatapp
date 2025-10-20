import 'package:chatapp/function/snakbar.dart';
import 'package:chatapp/providers/profile_provider.dart';
import 'package:chatapp/providers/provide.dart';
import 'package:chatapp/providers/userListPProvider.dart';
import 'package:chatapp/screens/LoginScreen.dart';
import 'package:chatapp/services/auth.service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
            tooltip: "Refresh Profile",
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: profile.photoUrl != null
                        ? NetworkImage(profile.photoUrl!)
                        : null,
                    child: profile.photoUrl == null
                        ? const Icon(Icons.person, size: 40)
                        : null,
                  ),
                  Positioned(
                    bottom: 5,
                    right: 8,
                    child: GestureDetector(
                      onTap: () async {
                        final success = await notifier.updateProfilePicture();

                        if (success && context.mounted) {
                          showAppSnackbar(
                            context: context,
                            type: SnackbarType.success,
                            description: "Profile picture updated successfully",
                          );
                        } else if (context.mounted) {
                          showAppSnackbar(
                            context: context,
                            type: SnackbarType.error,
                            description: "Failed to update profile picture",
                          );
                        }

                      },
                      child: const CircleAvatar(
                        radius: 13,
                        backgroundColor: Colors.black,
                        child: Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                  if (profile.isUploading)
                    const Positioned.fill(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                profile.name ?? "No Name",
                style:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                profile.email ?? "No Email",
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
              Text(
                profile.createdAt != null
                    ? "Joined ${DateFormat("MMM d, y").format(
                    profile.createdAt!)}"
                    : "Joined date not available",
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 30),
              MaterialButton(
                color: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                onPressed: () async {
                  final shouldLogout = await showDialog(
                    context: context,
                    builder: (context) =>
                        AlertDialog(
                          title: Text("Logout"),
                          content: Text("Are you sure you want to logout?"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text("Logout"),
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
                          builder: (context) => const UserLoginScreen(),
                        ),
                      );
                    }
                  }
                },

                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.exit_to_app, color: Colors.white),
                      SizedBox(width: 5),
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
      ),
    );
  }
}
