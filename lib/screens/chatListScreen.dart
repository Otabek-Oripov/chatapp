import 'package:chatapp/main.dart';
import 'package:chatapp/models/Usermodel.dart';
import 'package:chatapp/providers/provide.dart';
import 'package:chatapp/providers/user_status_provider.dart';
import 'package:chatapp/screens/chat/chat_screen.dart';
import 'package:chatapp/screens/request_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Chatlistscreen extends ConsumerStatefulWidget {
  const Chatlistscreen({super.key});

  @override
  ConsumerState<Chatlistscreen> createState() => _ChatlistscreenState();
}

class _ChatlistscreenState extends ConsumerState<Chatlistscreen> {
  @override
  void initState() {
    super.initState();
    OnlineStatusService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(requestsProvider);
      ref.invalidate(chatsProvider);
    });
  }

  Future<void> _onRefresh() async {
    ref.invalidate(requestsProvider);
    ref.invalidate(chatsProvider);
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    final pendingRequest = ref.watch(requestsProvider);
    final chats = ref.watch(chatsProvider);

    final requestCount = pendingRequest.when(
      data: (requests) => requests.length,
      error: (_, __) => 0,
      loading: () => 0,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: false,
        automaticallyImplyLeading: false,
        title: const Text(
          'Chats',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (requestCount > 0)
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RequestScreen()),
              ),
              icon: Stack(
                children: [
                  const Icon(Icons.notifications),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$requestCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: chats.when(
          data: (chatList) {
            if (chatList.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 200),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          "No chats yet",
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Go to users tab to send message requests",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            // Agar chatlar mavjud bo‘lsa
            return ListView.builder(
              itemCount: chatList.length,
              itemBuilder: (context, index) {
                final chat = chatList[index];
                return FutureBuilder<UserModel?>(
                  future: _getOtherUser(chat.participants),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    final otherUser = snapshot.data!;
                    final currentUserId =
                        FirebaseAuth.instance.currentUser?.uid;

                    if (currentUserId == null) return const SizedBox();

                    final unreadCount = chat.unreadCount[currentUserId] ?? 0;

                    return ListTile(
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            backgroundImage: otherUser.photoUrl != null
                                ? NetworkImage(otherUser.photoUrl!)
                                : null,
                            child: otherUser.photoUrl == null
                                ? Text(
                              otherUser.name.isNotEmpty
                                  ? otherUser.name[0].toUpperCase()
                                  : 'U',
                            )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 2,
                            child: Consumer(
                              builder: (context, ref, _) {
                                final statusAsync = ref.watch(
                                  userStatusProvider(otherUser.uid),
                                );
                                return statusAsync.when(
                                  data: (isOnline) => CircleAvatar(
                                    radius: 5,
                                    backgroundColor: isOnline
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                                  error: (_, __) => const CircleAvatar(
                                    radius: 5,
                                    backgroundColor: Colors.grey,
                                  ),
                                  loading: () => const CircleAvatar(
                                    radius: 5,
                                    backgroundColor: Colors.grey,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      title: Text(
                        otherUser.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        chat.lastMessage.isNotEmpty
                            ? chat.lastMessage
                            : "You can now start to chat",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      //  O‘qilmagan xabarlar soni
                      trailing: unreadCount > 0
                          ? Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                          : const SizedBox.shrink(),

                        onTap: () {
                          ref.read(chatServiceProvider).markMessageAsRead(chat.chatId);

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                chatId: chat.chatId,
                                othersUser: otherUser,
                              ),
                            ),
                          ).then((_) {
                            ref.invalidate(chatsProvider); //
                          });
                        }

                    );
                  },
                );
              },
            );
          },
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 200),
              Center(
                child: Column(
                  children: [
                    Text("Error: $error"),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _onRefresh,
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Future<UserModel?> _getOtherUser(List<String> participants) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return null;

    final otherUserId = participants.firstWhere(
          (id) => id != currentUserId,
      orElse: () => '',
    );

    if (otherUserId.isEmpty) return null;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(otherUserId)
          .get();
      return doc.exists ? UserModel.fromMap(doc.data()!) : null;
    } catch (e) {
      debugPrint("Error getting other user: $e");
      return null;
    }
  }
}
