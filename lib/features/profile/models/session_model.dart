class SessionModel {
  final String id;
  final String partnerId;
  final String partnerName;
  final DateTime date;
  final Duration duration;
  final double rating;
  final double amount; // Cost for Seeker, Earnings for Listener
  final bool isListenerSession; // true if the current user was acting as a listener

  SessionModel({
    required this.id,
    required this.partnerId,
    required this.partnerName,
    required this.date,
    required this.duration,
    required this.rating,
    required this.amount,
    required this.isListenerSession,
  });
}
