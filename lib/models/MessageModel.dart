// lib/models/MessageModel.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String messageId;
  final String senderId;
  final String message;
  final String type;
  final DateTime timestamp;
  final String? imageUrl;
  final String? audioUrl;
  final String? readBy;
  final String? callType;
  final String? callStatus;
  final String? chatId;

  MessageModel({
    required this.messageId,
    required this.senderId,
    required this.message,
    required this.type,
    required this.timestamp,
    this.imageUrl,
    this.audioUrl,
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
      timestamp:
      (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrl: data['imageUrl'],
      audioUrl: data['audioUrl'],
      readBy: data['readBy'],
      callType: data['callType'],
      callStatus: data['callStatus'],
      chatId: data['chatId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'message': message,
      'type': type,
      'timestamp': Timestamp.fromDate(timestamp),
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'readBy': readBy,
      'callType': callType,
      'callStatus': callStatus,
      'chatId': chatId,
    };
  }
}