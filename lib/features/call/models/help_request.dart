class HelpRequest {
  final String id;
  final String seekerId;
  final String seekerHandle;
  final String topic;
  final String mood;
  final String
  status; // 'open', 'pending', 'accepted', 'connected', 'ending', 'completed', 'cancelled'
  final DateTime timestamp;
  final String language;
  final String? listenerId;
  final String? listenerHandle;
  final int? rating; // 1-5 stars
  final int? tip; // Tip amount in rupees
  final DateTime? connectedAt;
  final bool isPaid; // Whether the listener has been paid for this session

  HelpRequest({
    required this.id,
    required this.seekerId,
    required this.seekerHandle,
    required this.topic,
    required this.mood,
    required this.status,
    required this.timestamp,
    this.language = 'English',
    this.listenerId,
    this.listenerHandle,
    this.rating,
    this.tip,
    this.connectedAt,
    this.isPaid = false,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'seekerId': seekerId,
      'seekerHandle': seekerHandle,
      'topic': topic,
      'mood': mood,
      'status': status,
      'timestamp': timestamp.toIso8601String(),
      'language': language,
      'listenerId': listenerId,
      'listenerHandle': listenerHandle,
      'rating': rating,
      'tip': tip,
      'connectedAt': connectedAt?.toIso8601String(),
      'isPaid': isPaid,
    };
  }

  // Create from Firestore Document
  factory HelpRequest.fromMap(Map<String, dynamic> map) {
    return HelpRequest(
      id: map['id'] ?? '',
      seekerId: map['seekerId'] ?? '',
      seekerHandle: map['seekerHandle'] ?? 'Anonymous',
      topic: map['topic'] ?? '',
      mood: map['mood'] ?? '',
      status: map['status'] ?? 'open',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      language: map['language'] ?? 'English',
      listenerId: map['listenerId'],
      listenerHandle: map['listenerHandle'],
      rating: map['rating'],
      tip: map['tip'],
      connectedAt: map['connectedAt'] != null
          ? DateTime.tryParse(map['connectedAt'])
          : null,
      isPaid: map['isPaid'] ?? false,
    );
  }
}
