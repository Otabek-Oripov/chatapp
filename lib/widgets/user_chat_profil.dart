import 'package:chatapp/models/Usermodel.dart';
import 'package:chatapp/providers/user_status_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserChatProfil extends ConsumerWidget {
  final UserModel user;

  const UserChatProfil({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(userStatusProvider(user.uid));

    return statusAsync.when(
      data: (isOnline) => Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                backgroundImage:
                user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                child: user.photoUrl == null
                    ? Text(
                  user.name.isNotEmpty
                      ? user.name[0].toUpperCase()
                      : 'U',
                )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 2,
                child: CircleAvatar(
                  radius: 5,
                  backgroundColor: isOnline ? Colors.green : Colors.grey,
                ),
              ),
            ],
          ),
        SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                isOnline ? "Online" : "Offline",
                style: TextStyle(
                  fontSize: 13,
                  color: isOnline ? Colors.green : Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
      loading: () => Text(user.name),
      error: (_, __) => Text(user.name),
    );
  }
}
