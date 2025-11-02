import 'package:chatapp/models/MessageModel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

Widget buildMessageStatusIcon(MessageModel message, String receiverId) {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // Only show status for messages sent by me
  if (message.senderId != currentUserId) {
    return const SizedBox();
  }

  print('Message ${message.messageId}');

  // ✅ Just add `return` before StreamBuilder
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('messages')
        .where('chatId', isEqualTo: message.chatId) // chatId bo‘yicha filter
        .where('timestamp', isEqualTo: message.timestamp) // har bir xabar unikal
        .limit(1)
        .snapshots(),
    builder: (context, snap) {
      if (!snap.hasData || snap.data!.docs.isEmpty) {
        return const Icon(Icons.check, size: 16, color: Colors.white70);
      }

      final doc = snap.data!.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      final readBy = data['readBy'];
      bool isRead = false;
      if (readBy is String) {
        isRead = true;
      }

      debugPrint('💬 Message in chat ${message.chatId} → readBy: $readBy → isRead: $isRead');

      return Icon(
        isRead ? Icons.done_all : Icons.check,
        size: 16,
        color: isRead ? Colors.white : Colors.white70,
      );
    },
  );
}
