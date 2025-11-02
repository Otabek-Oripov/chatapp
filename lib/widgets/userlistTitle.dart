import 'package:chatapp/function/snakbar.dart';
import 'package:chatapp/models/Usermodel.dart';
import 'package:chatapp/models/userlistnodel.dart';
import 'package:chatapp/providers/userListPProvider.dart';
import 'package:chatapp/providers/user_status_provider.dart';
import 'package:chatapp/screens/chat/chat_screen.dart'
    show Chatlistscreen, ChatScreen;
import 'package:chatapp/services/chatId.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Userlisttitle extends ConsumerWidget {
  final UserModel user;

  const Userlisttitle({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(userListProvider(user));
    final notifier = ref.read(userListProvider(user).notifier);
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: user.photoUrl != null
            ? NetworkImage(user.photoUrl!)
            : null,
        child: user.photoUrl == null
            ? Text(user.name.isNotEmpty ? user.name[0].toLowerCase() : 'U')
            : null,
      ),
      title: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Consumer(
        builder: (context, ref, _) {
          final statusAsync = ref.watch(userStatusProvider(user.uid));
          return statusAsync.when(
            data: (isOnline) => Text(
              isOnline ? 'Online' : 'Offline',
              style: TextStyle(color: isOnline ? Colors.green : Colors.grey),
            ),
            error: (_, __) => Text(user.email),
            loading: () => Text(user.email),
          );
        },
      ),

      trailing: _buildTralingWidget(context, ref, state, notifier),
    );
  }

  Widget _buildTralingWidget(
    BuildContext context,
    WidgetRef ref,
    UserListTileState state,
    UserListNotifier notifier,
  ) {
    if (state.isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (state.isFriend) {
      return MaterialButton(
        onPressed: () => _navigateToChat(context),
        color: Colors.green,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: buttonName(Icons.chat, 'Chat'),
      );
    }
    if (state.requestStatus == 'pending') {
      if (state.isRequestSender) {
        return ElevatedButton(
          onPressed: null,
          child: SizedBox(
            height: 32,
            width: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pending_actions, color: Colors.black, size: 20),
                SizedBox(width: 5),
                Text(
                  'Pending',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        return MaterialButton(
          color: Colors.orange,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          onPressed: () async {
            final result = await notifier.acceptRequest();
            if (result == 'success' && context.mounted) {
              showAppSnackbar(
                context: context,
                type: SnackbarType.success,
                description: 'Request accepted',
              );
            } else {
              if (context.mounted) {
                showAppSnackbar(
                  context: context,
                  type: SnackbarType.error,
                  description: 'Failed: $result',
                );
              }
            }
          },
          child: buttonName(Icons.done, 'Accepted'),
        );
      }
    }else{
      return MaterialButton(
        color: Colors.blueAccent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onPressed: () async {
          final result = await notifier.sendRequest();
          if (result == 'success' && context.mounted) {
            showAppSnackbar(
              context: context,
              type: SnackbarType.success,
              description: 'Request send successfully!',
            );
          } else {
            if (context.mounted) {
              showAppSnackbar(
                context: context,
                type: SnackbarType.error,
                description: 'Failed: $result',
              );
            }
          }
        },
        child: buttonName(Icons.person, 'Add friend'),
      );
    }
    }


  SizedBox buttonName(IconData icon, String name) {
    return SizedBox(
      width: 100,
      height: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          SizedBox(width: 5),
          Text(
            name,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToChat(BuildContext context) async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final chatId = generateChatID(currentUserId, user.uid);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(chatId: chatId, othersUser: user),
      ),
    );
  }
}
