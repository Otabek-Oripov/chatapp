// lib/screens/chatListScreen.dart
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
import 'package:flutter_riverpod/legacy.dart';

// QIDIRUV PROVIDERI
final chatSearchQueryProvider = StateProvider<String>((ref) => '');

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

  // VAQT FORMATLASH
  String formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inDays > 0)
      return '${difference.inDays}d';
    else if (difference.inHours > 0)
      return '${difference.inHours}h';
    else if (difference.inMinutes > 0)
      return '${difference.inMinutes}m';
    else
      return "Now";
  }

  @override
  Widget build(BuildContext context) {
    final chatsAsync = ref.watch(chatsProvider);
    final pendingRequest = ref.watch(requestsProvider);
    final searchQuery = ref.watch(chatSearchQueryProvider).toLowerCase().trim();

    final requestCount = pendingRequest.when(
      data: (requests) => requests.length,
      error: (_, __) => 0,
      loading: () => 0,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Chatlar",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        actions: [
          if (requestCount > 0)
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RequestScreen()),
              ).then((_) => ref.invalidate(requestsProvider)),
              icon: Stack(
                children: [
                  const Icon(
                    Icons.notifications,
                    size: 28,
                    color: Colors.black87,
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        requestCount > 99 ? "99+" : "$requestCount",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: TextField(
                onChanged: (value) =>
                    ref.read(chatSearchQueryProvider.notifier).state = value,
                decoration: InputDecoration(
                  hintText: "Chatlarda qidiring...",
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            ref.read(chatSearchQueryProvider.notifier).state =
                                '';
                            FocusScope.of(context).unfocus();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),
        ),
      ),
      body: chatsAsync.when(
        data: (chatList) {
          if (chatList.isEmpty && searchQuery.isEmpty)
            return _buildEmptyState();

          return ListView.builder(
            itemCount: chatList.length,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemBuilder: (context, index) {
              final chat = chatList[index];
              final currentUserId = FirebaseAuth.instance.currentUser?.uid;

              return FutureBuilder<UserModel?>(
                future: _getOtherUser(chat.participants),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data == null)
                    return const SizedBox();
                  final user = snapshot.data!;

                  // QIDIRUV FILTRI
                  if (searchQuery.isNotEmpty &&
                      !user.name.toLowerCase().contains(searchQuery)) {
                    return const SizedBox();
                  }

                  final unreadCount = currentUserId != null
                      ? (chat.unreadCount[currentUserId] ?? 0)
                      : 0;
                  final messageTime = chat.lastMessageTime ?? DateTime.now();

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(14),
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundImage: user.photoUrl != null
                                ? NetworkImage(user.photoUrl!)
                                : null,
                            child: user.photoUrl == null
                                ? Text(
                              user.name.isNotEmpty
                                  ? user.name[0].toUpperCase()
                                  : "U",
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                                : null,
                            backgroundColor: user.photoUrl == null
                                ? const Color(0xFF6a11cb)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Consumer(
                              builder: (context, ref, _) {
                                final status = ref.watch(
                                  userStatusProvider(user.uid),
                                );
                                return status.when(
                                  data: (online) => Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: online
                                          ? Colors.green
                                          : Colors.grey,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  loading: () => const SizedBox(),
                                  error: (_, __) => const SizedBox(),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      title: Text(
                        user.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                        ),
                      ),
                      subtitle: Text(
                        chat.lastMessage.isEmpty
                            ? "Yangi chat"
                            : chat.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      trailing: unreadCount > 0
                          ? Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          unreadCount > 99 ? "99+" : "$unreadCount",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      )
                          : Text(
                        formatTime(messageTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      onTap: () async {
                        if (currentUserId != null && unreadCount > 0) {
                          await ref
                              .read(chatServiceProvider)
                              .markMessageAsRead(chat.chatId);
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              chatId: chat.chatId,
                              othersUser: user,
                            ),
                          ),
                        ).then((_) => ref.invalidate(chatsProvider));
                      },
                    ),
                  );
                },
              );
            },
          );
        },
        error: (_, __) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              const Text("Xatolik yuz berdi"),
              ElevatedButton(
                onPressed: () => ref.invalidate(chatsProvider),
                child: const Text("Qayta yuklash"),
              ),
            ],
          ),
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF6a11cb)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        Center(
          child: Column(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 90,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 24),
              const Text(
                "Hozircha chatlar yo‘q",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                "Foydalanuvchilarga boring va xabar yuboring!",
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
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
      debugPrint("Error: $e");
      return null;
    }
  }
}
