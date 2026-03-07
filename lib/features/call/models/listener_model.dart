class ListenerProfile {
  final String id;
  final String name;
  final double rating; // 1.0 to 5.0
  final double acceptanceRate; // 0.0 to 1.0
  final int totalCalls;
  final bool isOnline;
  final List<String> topics;
  final String bio;

  ListenerProfile({
    required this.id,
    required this.name,
    required this.rating,
    required this.acceptanceRate,
    required this.totalCalls,
    required this.isOnline,
    required this.topics,
    required this.bio,
  });

  // For debugging
  @override
  String toString() {
    return 'ListenerProfile(name: $name, rating: $rating, acceptance: $acceptanceRate, calls: $totalCalls)';
  }
}
