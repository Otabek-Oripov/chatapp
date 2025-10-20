class MessagerequestModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String senderName;
  final String sendEmail;
  final String status;
  final DateTime createdAt;
  final String? photoUrl;

  MessagerequestModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.senderName,
    required this.sendEmail,
    required this.status,
    required this.createdAt,
    required this.photoUrl,
  });

  MessagerequestModel copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? senderName,
    String? sendEmail,
    String? status,
    DateTime? createdAt,
    String? photoUrl,
  }) {
    return MessagerequestModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      senderName: senderName ?? this.senderName,
      sendEmail: sendEmail ?? this.sendEmail,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  factory MessagerequestModel.fromMap(Map<String, dynamic> map) {
    return MessagerequestModel(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      senderName: map['senderName'] ?? '',
      sendEmail: map['sendEmail'] ?? '',
      status: map['status'] ?? '',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is DateTime
          ? map['createdAt']
          : DateTime.tryParse(map['createdAt'].toString()) ??
          DateTime.now())
          : DateTime.now(),
      photoUrl: map['photoUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'senderName': senderName,
      'sendEmail': sendEmail,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'photoUrl': photoUrl,
    };
  }
}
