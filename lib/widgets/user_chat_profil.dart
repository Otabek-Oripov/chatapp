import 'package:chatapp/models/Usermodel.dart';
import 'package:chatapp/providers/provide.dart';
import 'package:chatapp/providers/user_status_provider.dart';
import 'package:chatapp/screens/Profileinfo.dart';
import 'package:chatapp/widgets/dot_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserChatProfile extends ConsumerWidget {
  final UserModel user;
  final String chatId; // <-- bu joy qo‘shildi

  const UserChatProfile({
    super.key,
    required this.user,
    required this.chatId, // <-- bu ham qo‘shildi
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(userStatusProvider(user.uid));
    final typingStatus = ref.watch(typingProvider(chatId)); // <-- to‘g‘rilandi
    final isOtherUserTyping = typingStatus[user.uid] ?? false;

    return statusAsync.when(
      data: (isOnline) => Row(
        children: [
          Stack(
            children: [
              InkWell(
                onTap: (){
                  Navigator.push(context, MaterialPageRoute(builder: (context)=>ProfileInfo(info: user,)));
                },
                child: CircleAvatar(
                  backgroundImage: user.photoUrl != null
                      ? NetworkImage(user.photoUrl!)
                      : null,
                  child: user.photoUrl == null
                      ? Text(
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                        )
                      : null,
                ),
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: const TextStyle(fontSize: 16)),
                if (isOtherUserTyping)
                  const Row(
                    children: [
                      Text(
                        "Typing...",
                        style: TextStyle(color: Colors.blue, fontSize: 10),
                      ),
                      SizedBox(width: 4),
                      ThreeDots(),
                    ],
                  )
                else if (isOnline)
                  Text(
                    "Online",
                    style: TextStyle(fontSize: 12, color: Colors.green),
                  ),
              ],
            ),
          ),
        ],
      ),
      loading: () => Text(user.name),
      error: (_, __) => Text(user.name),
    );
  }
}
