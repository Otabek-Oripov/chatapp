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

// YANGI PROVIDER — QIDIRUV UCHUN
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
  String formateMessageTime(DateTime? time) {
    time ??= DateTime.now();
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

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
    final searchQuery = ref.watch(chatSearchQueryProvider);
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
                    ref.read(chatSearchQueryProvider.notifier).state = value
                        .toLowerCase(),
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
          // QIDIRUV FUNKSIYASI
          final filteredChats = chatList.where((chat) {
            if (searchQuery.isEmpty) return true;
            final participantId = chat.participants.firstWhere(
              (id) => id != FirebaseAuth.instance.currentUser?.uid,
              orElse: () => '',
            );
            if (participantId.isEmpty) return false;

            // Foydalanuvchi nomini olish
            final userDoc = FirebaseFirestore.instance
                .collection('users')
                .doc(participantId);
            // Bu yerda real-time emas, lekin tezlik uchun cache qilamiz
            // Yoki oldindan yuklangan user ma'lumotlaridan foydalanamiz
            return true; // Keyinroq to‘liq qilamiz
          }).toList();

          // HOZIRCHA — oddiy filtr (keyinroq to‘liq qilamiz)
          if (chatList.isEmpty) return _buildEmptyState();

          return ListView.builder(
            itemCount: chatList.length,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemBuilder: (context, index) {
              final chat = chatList[index];
              return FutureBuilder<UserModel?>(
                future: _getOtherUser(chat.participants),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data == null)
                    return const SizedBox();
                  final user = snapshot.data!;

                  // QIDIRUV — ISH BO‘YICHA FILTR
                  if (searchQuery.isNotEmpty &&
                      !user.name.toLowerCase().contains(searchQuery)) {
                    return const SizedBox();
                  }

                  final unread =
                      chat.unreadCount[FirebaseAuth
                          .instance
                          .currentUser
                          ?.uid] ??
                      0;
                  DateTime messageTime = DateTime.now();
                  if (chat.lastMessageTime is Timestamp) {
                    messageTime = (chat.lastMessageTime as Timestamp).toDate();
                  } else if (chat.lastMessageTime is DateTime) {
                    messageTime = chat.lastMessageTime;
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),

                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(10),
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
                                      fontSize: 20,
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
                          fontSize: 15,
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
                          fontSize: 12,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (unread > 0)
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: const BoxDecoration(
                                color: Color(0xFF6a11cb),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                unread > 99 ? "99+" : "$unread",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            formatTime(messageTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        ref
                            .read(chatServiceProvider)
                            .markMessageAsRead(chat.chatId);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              chatId: chat.chatId,
                              othersUser: user,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
        error: (_, __) => const Center(child: Text("Xatolik")),
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF6a11cb)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() => ListView(
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
              "Chatlar yo‘q",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              "Yangi suhbat boshlang!",
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    ],
  );

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
      return null;
    }
  }
}
