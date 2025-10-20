class ProfileModel {
  final String? photoUrl;
  final String? name;
  final String? email;
  final bool isLoading;
  final bool isUploading;
  final DateTime? createdAt;
  final String? userId;

  ProfileModel({
    this.photoUrl,
    this.name,
    this.email,
    this.isLoading = false,
    this.isUploading = false,
    this.createdAt,
    this.userId,
  });

  ProfileModel copyWith({
    String? photoUrl,
    String? name,
    String? email,
    DateTime? createdAt,
    bool? isLoading,
    bool? isUploading,
    String? userId,
  }) {
    return ProfileModel(
      photoUrl: photoUrl ?? this.photoUrl,
      name: name ?? this.name,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      isLoading: isLoading ?? this.isLoading,
      isUploading: isUploading ?? this.isUploading,
      userId: userId ?? this.userId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'photoUrl': photoUrl,
      'name': name,
      'email': email,
      'createdAt': createdAt?.toIso8601String(),
      'userId': userId,
    };
  }

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      photoUrl: map['photoUrl'],
      name: map['name'],
      email: map['email'],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'])
          : null,
      userId: map['userId'],
    );
  }
}
