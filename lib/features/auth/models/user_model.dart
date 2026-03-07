class UserModel {
  final String uid;
  final String email;
  final String handle;
  final String role; // 'seeker' or 'listener'
  final bool isOnline; // specific to listener
  final List<String> topics; // specific to listener
  final double rating;

  final String? fcmToken;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.handle,
    required this.role,
    this.isOnline = false,
    this.topics = const [],
    this.rating = 0.0,
    this.fcmToken,
    required this.createdAt,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'handle': handle,
      'role': role,
      'isOnline': isOnline,
      'topics': topics,
      'rating': rating,
      'fcmToken': fcmToken,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create from Firestore Document
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      handle: map['handle'] ?? '',
      role: map['role'] ?? 'seeker',
      isOnline: map['isOnline'] ?? false,
      topics: List<String>.from(map['topics'] ?? []),
      rating: (map['rating'] ?? 0.0).toDouble(),
      fcmToken: map['fcmToken'],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
