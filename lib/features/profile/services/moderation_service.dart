import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ModerationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Report a User
  Future<void> reportUser({
    required String reportedUid,
    required String reason,
    String? additionalDetails,
    String? requestId, // Optional: The specific call session they were in
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception("Not logged in");

    try {
      await _firestore.collection('reports').add({
        'reportedByUid': currentUser.uid,
        'reportedUid': reportedUid,
        'reason': reason,
        'details': additionalDetails ?? '',
        'requestId': requestId,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending', // Admins can review pending reports
      });
    } catch (e) {
      throw Exception("Failed to report user.");
    }
  }

  // Block a User
  Future<void> blockUser({required String blockedUid}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception("Not logged in");

    try {
      // Add to a global 'blocks' collection
      final blockRef = _firestore.collection('blocks').doc();
      await blockRef.set({
        'blockedByUid': currentUser.uid,
        'blockedUid': blockedUid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Also maintain an array on the user's profile for quick local filtering
      await _firestore.collection('users').doc(currentUser.uid).update({
        'blockedUsers': FieldValue.arrayUnion([blockedUid]),
      });

    } catch (e) {
      throw Exception("Failed to block user.");
    }
  }
}
