import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String? photoUrl;
  final String uid;
  final String name;
  final String email;
  final bool isOnline;
  final DateTime lastSeen;

  UserModel({
    this.photoUrl,
    required this.uid,
    required this.name,
    required this.email,
    required this.isOnline,
    required this.lastSeen,
  });

  /// copyWith funksiyasi
  UserModel copyWith({
    String? photoUrl,
    String? uid,
    String? name,
    String? email,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return UserModel(
      photoUrl: photoUrl ?? this.photoUrl,
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  /// Firestore dan model yaratish
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      photoUrl: map['photoUrl'],
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen'] != null
          ? (map['lastSeen'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// Modelni Firestorega yozish uchun
  Map<String, dynamic> toMap() {
    return {
      'photoUrl': photoUrl,
      'uid': uid,
      'name': name,
      'email': email,
      'isOnline': isOnline,
      'lastSeen': lastSeen,
    };
  }
}
