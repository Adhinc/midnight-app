class UserModel {
  final String uid;
  final String? email;
  final String phone;
  final String handle;
  final String? bio; // Added bio
  final String? profilePicUrl; // Added profilePicUrl
  final String role; // 'seeker' or 'listener'
  final bool isOnline; // specific to listener
  final List<String> topics; // specific to listener
  final double rating;

  final String? fcmToken;
  final List<String> languages;
  final double heldBalance;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    this.email,
    required this.phone,
    required this.handle,
    this.bio,
    this.profilePicUrl,
    required this.role,
    this.isOnline = false,
    this.topics = const [],
    this.rating = 0.0,
    this.fcmToken,
    this.languages = const ['English'],
    this.heldBalance = 0.0,
    required this.createdAt,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'phone': phone,
      'handle': handle,
      'bio': bio,
      'profilePicUrl': profilePicUrl,
      'role': role,
      'isOnline': isOnline,
      'topics': topics,
      'rating': rating,
      'fcmToken': fcmToken,
      'languages': languages,
      'heldBalance': heldBalance,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create from Firestore Document
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'],
      phone: map['phone'] ?? '',
      handle: map['handle'] ?? '',
      bio: map['bio'],
      profilePicUrl: map['profilePicUrl'],
      role: map['role'] ?? 'seeker',
      isOnline: map['isOnline'] ?? false,
      topics: List<String>.from(map['topics'] ?? []),
      rating: (map['rating'] ?? 0.0).toDouble(),
      fcmToken: map['fcmToken'],
      languages: List<String>.from(map['languages'] ?? ['English']),
      heldBalance: (map['heldBalance'] ?? 0.0).toDouble(),
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
