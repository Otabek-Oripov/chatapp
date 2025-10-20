import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String messageId;
  final String senderId;
  final String senderName;
  final String message;
  final DateTime? timestamp;
  final String type;
  final Map<String, DateTime> readBy;
  final String? imageUrl;
  final String? callType;
  final String? callStatus;

  MessageModel({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.type,
    required this.readBy,
    this.timestamp,
    this.imageUrl,
    this.callType,
    this.callStatus,

  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      messageId: map['messageId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      message: map['message'] ?? '',
      type: map['type'] ?? 'text',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate(),
      readBy: map['readBy'] != null
          ? Map<String, DateTime>.fromEntries(
        (map['readBy'] as Map).entries.map(
              (e) => MapEntry(e.key, (e.value as Timestamp).toDate()),
        ),
      )
          : {},
      imageUrl: map['imageUrl'],
      callType: map['callType'],
      callStatus: map['callStatus'],

    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'senderName': senderName,
      'message': message,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : null,
      'type': type,
      'readBy': readBy.map(
            (key, value) => MapEntry(key, Timestamp.fromDate(value)),
      ),
      'imageUrl': imageUrl,
      if(callType != null) 'callType':callType,
      if(callStatus != null) 'callStatus':callStatus,

    };
  }
}
