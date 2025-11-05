// models/Usermodel.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String? photoUrl;
  final List<String> profileImages;
  final String uid;
  final String name;
  final String email;
  final bool isOnline;
  final DateTime lastSeen;

  UserModel({
    this.photoUrl,
    this.profileImages = const [],
    required this.uid,
    required this.name,
    required this.email,
    required this.isOnline,
    required this.lastSeen,
  });

  UserModel copyWith({
    String? photoUrl,
    List<String>? profileImages,
    String? uid,
    String? name,
    String? email,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return UserModel(
      photoUrl: photoUrl ?? this.photoUrl,
      profileImages: profileImages ?? this.profileImages,
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      photoUrl: map['photoUrl'],
      profileImages: map['profileImages'] != null
          ? List<String>.from(map['profileImages'])
          : [],
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen'] != null
          ? (map['lastSeen'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'photoUrl': photoUrl,
      'profileImages': profileImages,
      'uid': uid,
      'name': name,
      'email': email,
      'isOnline': isOnline,
      'lastSeen': lastSeen,
    };
  }
}