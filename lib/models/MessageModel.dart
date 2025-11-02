import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String messageId;
  final String senderId;
  final String message;
  final String type; // text, image, call, system
  final DateTime timestamp;
  final String? imageUrl;
  final String? readBy;
  final String? callType; // "audio" yoki "video"
  final String? callStatus; // "missed", "answered", "rejected"
  final String? chatId; // chat ID uchun qo‘shimcha (agar kerak bo‘lsa)

  MessageModel({
    required this.messageId,
    required this.senderId,
    required this.message,
    required this.type,
    required this.timestamp,
    this.imageUrl,
    this.readBy,
    this.callType,
    this.callStatus,
     this.chatId,
  });

  factory MessageModel.fromMap(Map<String, dynamic> data, String messageId) {
    return MessageModel(
      messageId: messageId,
      senderId: data['senderId'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? 'text',
      timestamp: data['timestamp'] is Timestamp
          ? (data['timestamp'] as Timestamp).toDate()
          : Timestamp.now().toDate(),
      imageUrl: data['imageUrl'],
      readBy: data['readBy'],
      callType: data['callType'],       // 🔹 qo‘shildi
      callStatus: data['callStatus'],   // 🔹 qo‘shildi
      chatId: data['chatId'],           // 🔹 ixtiyoriy
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'message': message,
      'type': type,
      'timestamp': Timestamp.fromDate(timestamp),
      'imageUrl': imageUrl,
      'readBy': readBy,
      'callType': callType,      // 🔹 qo‘shildi
      'callStatus': callStatus,  // 🔹 qo‘shildi
      'chatId': chatId,          // 🔹 ixtiyoriy
    };
  }
}
