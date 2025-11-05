// models/profile_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileModel {
  final String? photoUrl;
  final String? name;
  final String? email;
  final bool isLoading;
  final bool isUploading;
  final DateTime? createdAt;
  final String? userId;
  final List<String> profileImages; // YANGI

  ProfileModel({
    this.photoUrl,
    this.name,
    this.email,
    this.isLoading = false,
    this.isUploading = false,
    this.createdAt,
    this.userId,
    this.profileImages = const [],
  });

  ProfileModel copyWith({
    String? photoUrl,
    String? name,
    String? email,
    DateTime? createdAt,
    bool? isLoading,
    bool? isUploading,
    String? userId,
    List<String>? profileImages,
  }) {
    return ProfileModel(
      photoUrl: photoUrl ?? this.photoUrl,
      name: name ?? this.name,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      isLoading: isLoading ?? this.isLoading,
      isUploading: isUploading ?? this.isUploading,
      userId: userId ?? this.userId,
      profileImages: profileImages ?? this.profileImages,
    );
  }

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      photoUrl: map['photoUrl'] ?? map['photoURL'],
      name: map['name'],
      email: map['email'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt']))
          : null,
      userId: map['userId'] ?? map['uid'],
      profileImages: map['profileImages'] != null
          ? List<String>.from(map['profileImages'])
          : [],
    );
  }
}