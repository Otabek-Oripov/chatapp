// lib/models/chatModel.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String chatId;
  final List<String> participants;
  final String lastMessage;
  final String? lastSenderId;          // nullable
  final DateTime lastMessageTime;
  final Map<String, int> unreadCount;
  final String? lastMessageId;         // nullable

  ChatModel({
    required this.chatId,
    required this.participants,
    required this.lastMessage,
    this.lastSenderId,
    required this.lastMessageTime,
    required this.unreadCount,
    this.lastMessageId,
  });

  factory ChatModel.fromMap(Map<String, dynamic> map, String id) {
    final timestamp = map['lastMessageTime'] as Timestamp?;
    final rawUnread = map['unreadCount'] as Map<String, dynamic>?;

    final Map<String, int> unreadCount = {};
    rawUnread?.forEach((key, value) {
      unreadCount[key] = (value is int) ? value : (value as num).toInt();
    });

    return ChatModel(
      chatId: id,
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage']?.toString() ?? '',
      lastSenderId: map['lastSenderId']?.toString(),
      lastMessageTime: timestamp?.toDate() ?? DateTime.now(),
      unreadCount: unreadCount,
      lastMessageId: map['lastMessageId']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'participants': participants,
      'lastMessage': lastMessage,
      'lastSenderId': lastSenderId,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'unreadCount': unreadCount,
      'lastMessageId': lastMessageId,
    };
  }
}